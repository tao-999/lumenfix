import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 统一的效果句柄：id + render(rgba,w,h) -> Uint8List
class EffectHandle {
  final String id;
  final Future<Uint8List> Function(Uint8List rgba, int w, int h) render;
  const EffectHandle(this.id, this.render);
}

/// 正方形缩略图 + 中心裁剪 + ✅右下角勾勾
Widget tileShell({
  required ui.Image? img,
  required bool selected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img == null)
              const Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              FittedBox(
                fit: BoxFit.cover,
                child: RawImage(image: img),
              ),
            if (selected)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 通用网格（缓存 RGBA，不缓存 ui.Image）
class PanelGrid<T> extends StatefulWidget {
  const PanelGrid({
    super.key,
    required this.img,
    required this.items,
    required this.idOf,
    required this.renderRgba,
    required this.onPick,
    this.selectedId,
  });

  final ui.Image img;
  final List<T> items;
  final String Function(T) idOf;
  final Future<Uint8List> Function(Uint8List, int, int, T) renderRgba;
  final void Function(T item) onPick;
  final String? selectedId;

  @override
  State<PanelGrid<T>> createState() => _PanelGridState<T>();
}

class _PanelGridState<T> extends State<PanelGrid<T>> {
  Uint8List? _baseRgba; int _bw = 0, _bh = 0;
  final Map<String, Uint8List> _rgbaCache = LinkedHashMap();
  final Queue<Future<void> Function()> _jobs = Queue();
  int _running = 0;
  static const _kMaxConcurrent = 3;

  @override
  void initState() { super.initState(); _prepareBase(); }

  @override
  void didUpdateWidget(covariant PanelGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.img != widget.img) {
      _rgbaCache.clear();
      _prepareBase();
    }
  }

  Future<void> _prepareBase() async {
    final src = widget.img;
    const maxSide = 220.0; // 缩略图基底更小，加载更快
    final scale = (src.width > src.height) ? maxSide / src.width : maxSide / src.height;
    final w = (src.width * scale).clamp(1.0, maxSide).round();
    final h = (src.height * scale).clamp(1.0, maxSide).round();

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.low,
    );
    final img = await rec.endRecording().toImage(w, h);
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    _baseRgba = bd!.buffer.asUint8List();
    _bw = w; _bh = h;
    if (mounted) setState(() {});
  }

  void _schedule(Future<void> Function() job) {
    _jobs.add(job); _tryNext();
  }
  void _tryNext() {
    if (_running >= _kMaxConcurrent || _jobs.isEmpty) return;
    final j = _jobs.removeFirst(); _running++;
    j().whenComplete(() { _running--; if (mounted) _tryNext(); });
  }

  @override
  Widget build(BuildContext context) {
    if (_baseRgba == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.0,
      ),
      itemCount: widget.items.length,
      itemBuilder: (_, i) {
        final item = widget.items[i];
        final id = widget.idOf(item);
        return _ThumbTile<T>(
          id: id,
          selected: id == widget.selectedId,
          baseRgba: _baseRgba!, w: _bw, h: _bh,
          cache: _rgbaCache,
          schedule: _schedule,
          renderRgba: (rgba, w, h) => widget.renderRgba(rgba, w, h, item),
          onTap: () => widget.onPick(item),
        );
      },
    );
  }
}

class _ThumbTile<T> extends StatefulWidget {
  const _ThumbTile({
    required this.id,
    required this.selected,
    required this.baseRgba,
    required this.w, required this.h,
    required this.cache,
    required this.schedule,
    required this.renderRgba,
    required this.onTap,
  });
  final String id;
  final bool selected;
  final Uint8List baseRgba;
  final int w, h;
  final Map<String, Uint8List> cache;
  final void Function(Future<void> Function() job) schedule;
  final Future<Uint8List> Function(Uint8List, int, int) renderRgba;
  final VoidCallback onTap;

  @override
  State<_ThumbTile<T>> createState() => _ThumbTileState<T>();
}

class _ThumbTileState<T> extends State<_ThumbTile<T>> {
  ui.Image? _img; bool _started = false;

  @override
  void initState() { super.initState(); _ensure(); }
  @override
  void didUpdateWidget(covariant _ThumbTile<T> old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) { _disposeImage(); _started = false; _ensure(); }
  }
  @override
  void dispose() { _disposeImage(); super.dispose(); }

  void _disposeImage() {
    final old = _img; _img = null;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { try { old.dispose(); } catch(_){}} );
    }
  }

  void _ensure() {
    if (_started) return; _started = true;
    final cached = widget.cache[widget.id];
    if (cached != null) { _decodeAndSet(cached); return; }
    widget.schedule(() async {
      final rgba = await widget.renderRgba(widget.baseRgba, widget.w, widget.h);
      if (!mounted) return;
      widget.cache[widget.id] = rgba;
      _decodeAndSet(rgba);
    });
  }

  void _decodeAndSet(Uint8List rgba) {
    ui.decodeImageFromPixels(rgba, widget.w, widget.h, ui.PixelFormat.rgba8888, (img) {
      if (!mounted) { img.dispose(); return; }
      _disposeImage();
      setState(() => _img = img);
    });
  }

  @override
  Widget build(BuildContext context) {
    return tileShell(img: _img, selected: widget.selected, onTap: widget.onTap);
  }
}
