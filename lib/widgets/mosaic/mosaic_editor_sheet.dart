// lib/widgets/mosaic/mosaic_editor_sheet.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show Image, PictureRecorder, ImageByteFormat;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'mosaic_types.dart';
import 'sub/brush_panel.dart';
import 'sub/effect_preview_painter.dart';
import 'sub/stroke.dart';
import 'sub/mosaic_isolates.dart';

class MosaicEditorSheet extends StatefulWidget {
  const MosaicEditorSheet({
    super.key,
    required this.image,
    this.initialBrush = MosaicBrushType.pixel,
  });

  final Uint8List image;
  final MosaicBrushType initialBrush;

  @override
  State<MosaicEditorSheet> createState() => _MosaicEditorSheetState();
}

class _MosaicEditorSheetState extends State<MosaicEditorSheet> {
  late final img.Image _srcIm;
  late final int _imgW, _imgH;

  Rect _fitRect = Rect.zero;

  MosaicBrushType _brush = MosaicBrushType.pixel;
  int _strength = 18;

  ui.Image? _effectUi;        // 预览效果图（可为降采样）
  Uint8List? _effectBytes;    // 预览字节缓存
  bool _buildingEffect = false;

  final List<StrokePath> _strokes = [];
  StrokePath? _active;
  bool _exporting = false;

  // 防抖：滑杆松手后延迟重建
  Timer? _rebuildDebounce;

  @override
  void initState() {
    super.initState();
    _brush = widget.initialBrush;
    _srcIm = img.decodeImage(widget.image)!;
    _imgW = _srcIm.width;
    _imgH = _srcIm.height;
    _rebuildEffect(initial: true);
  }

  @override
  void dispose() {
    _rebuildDebounce?.cancel();
    super.dispose();
  }

  // —— 布局映射 —— //
  Rect _containRect(Size content, Size box) {
    final s = (box.width / content.width < box.height / content.height)
        ? (box.width / content.width)
        : (box.height / content.height);
    final w = content.width * s, h = content.height * s;
    final dx = (box.width - w) / 2, dy = (box.height - h) / 2;
    return Rect.fromLTWH(dx, dy, w, h);
  }

  Offset _clampInFit(Offset p) => Offset(
    p.dx.clamp(_fitRect.left, _fitRect.right),
    p.dy.clamp(_fitRect.top, _fitRect.bottom),
  );

  // —— 预计算整图效果（预览用：降采样 + 后台计算） —— //
  Future<void> _rebuildEffect({bool initial = false}) async {
    // 初次构建时可以遮罩；后续更新不遮罩（不打断交互）
    if (initial) setState(() => _buildingEffect = true);

    final bytes = await compute(buildEffectIsolate, EffectArgs(
      srcBytes: widget.image,
      brush: _brush,
      strength: _strength,
      previewMaxSide: 1024,   // ✅ 降采样，重建更快
    ));

    final uiImg = await decodeImageFromList(bytes);
    if (!mounted) return;
    setState(() {
      _effectUi = uiImg;
      _effectBytes = bytes;
      _buildingEffect = false;  // 后续重建也只是悄悄替换，不遮挡
    });
  }

  void _scheduleRebuildEffect() {
    _rebuildDebounce?.cancel();
    _rebuildDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _rebuildEffect(); // 不展示 loading；保留旧预览，完成后无缝替换
    });
  }

  // —— 导出：生成全分辨率 mask，把效果贴回原图 —— //
  Future<void> _applyAndPop() async {
    if (_strokes.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(widget.image);
      });
      return;
    }
    setState(() => _exporting = true);

    final maskRgba = await _buildMaskRgbaBytes();

    final out = await compute(applyEffectIsolate, ApplyArgs(
      srcBytes: widget.image,
      effectBytes: _effectBytes, // 预览图分辨率可能较低；apply 会按 brush 再走一次全尺寸补算
      brush: _brush,
      strength: _strength,
      maskRgba: maskRgba,
    ));

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(out);
    });
  }

  // 与原图同尺寸的 RGBA mask
  Future<Uint8List> _buildMaskRgbaBytes() async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _imgW.toDouble(), _imgH.toDouble()),
      Paint()..color = Colors.transparent,
    );

    final sx = _imgW / _fitRect.width;
    final sy = _imgH / _fitRect.height;

    for (final s in _strokes) {
      if (s.points.length < 2) continue;
      final p = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s.strokeWidth * ((sx + sy) * 0.5);

      final path = Path()
        ..moveTo(
          (s.points.first.dx - _fitRect.left) * sx,
          (s.points.first.dy - _fitRect.top) * sy,
        );
      for (int i = 1; i < s.points.length; i++) {
        final v = s.points[i];
        path.lineTo(
          (v.dx - _fitRect.left) * sx,
          (v.dy - _fitRect.top) * sy,
        );
      }
      canvas.drawPath(path, p);
    }

    final pic = rec.endRecording();
    final maskImage = await pic.toImage(_imgW, _imgH);
    final bd = await maskImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Uint8List.view(bd!.buffer);
  }

  // —— 手势 —— //
  void _startStroke(Offset p) {
    final pt = _clampInFit(p);
    _active = StrokePath(_brushStrokeWidth(_brush), [pt]);
    setState(() => _strokes.add(_active!));
  }

  void _extendStroke(Offset p) {
    if (_active == null) return;
    setState(() => _active!.points.add(_clampInFit(p)));
  }

  void _endStroke() => _active = null;

  double _brushStrokeWidth(MosaicBrushType b) => switch (b) {
    MosaicBrushType.pixel => 26,
    MosaicBrushType.blur => 24,
    MosaicBrushType.hex => 30,
    MosaicBrushType.glass => 28,
    MosaicBrushType.bars => 26,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('马赛克'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: '撤销',
            onPressed: _strokes.isEmpty ? null : () => setState(() => _strokes.removeLast()),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: _strokes.isEmpty ? null : () => setState(() => _strokes.clear()),
            icon: const Icon(Icons.clear_all),
          ),
          TextButton(
            onPressed: _exporting ? null : _applyAndPop,
            child: const Text('完成', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          _fitRect = _containRect(
            Size(_imgW.toDouble(), _imgH.toDouble()),
            Size(c.maxWidth, c.maxHeight),
          );
          return Stack(
            children: [
              // 原图
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Image.memory(widget.image),
                ),
              ),
              // 实时预览：保留旧效果，后台换新
              if (_effectUi != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: EffectPreviewPainter(
                      effect: _effectUi!,
                      fitRect: _fitRect,
                      strokes: _strokes,
                    ),
                  ),
                ),
              // 涂抹层
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) => _startStroke(d.localPosition),
                  onPanUpdate: (d) => _extendStroke(d.localPosition),
                  onPanEnd: (_) => _endStroke(),
                  onPanCancel: _endStroke,
                ),
              ),
              // 笔刷/强度面板（滑动仅更新UI，松手再重建）
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: BrushPanel(
                  selected: _brush,
                  strength: _strength,
                  busy: _exporting, // ✅ 不再因为重建预览而禁用面板
                  onSelect: (b) {
                    if (_brush == b) return;
                    setState(() => _brush = b);
                    _scheduleRebuildEffect(); // 切笔刷也防抖一下
                  },
                  onStrengthChange: (v) {
                    setState(() => _strength = v); // 只更新UI，不算效果
                  },
                  onStrengthCommit: (v) {
                    setState(() => _strength = v);
                    _scheduleRebuildEffect();      // 松手后再重建
                  },
                ),
              ),

              // 只在“初次没有预览”或“导出时”遮罩
              if ((_buildingEffect && _effectUi == null) || _exporting)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x55000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
