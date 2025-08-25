// lib/widgets/doodle/doodle_editor_sheet.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../services/doodle_service.dart';
import 'sub/stroke.dart';
import 'sub/doodle_painter.dart';
import 'sub/brush_panel.dart';
import 'sub/path_utils.dart';

class DoodleEditorSheet extends StatefulWidget {
  const DoodleEditorSheet({
    super.key,
    required this.imageBytes,
    this.initialBrush = DoodleBrushType.pen,
  });

  final Uint8List imageBytes;
  final DoodleBrushType initialBrush;

  @override
  State<DoodleEditorSheet> createState() => _DoodleEditorSheetState();
}

class _DoodleEditorSheetState extends State<DoodleEditorSheet> {
  // 背景图（UI Image，用于导出合成）
  ui.Image? _bg;
  // 画布映射区域（原图以 contain 显示在此 Rect）
  Rect _fitRect = Rect.zero;

  // 状态
  final List<DoodleStroke> _strokes = [];
  final List<DoodleStroke> _redo = [];
  DoodleStroke? _active;

  // 笔刷设置
  DoodleBrushType _brush = DoodleBrushType.pen;
  Color _color = Colors.white;
  double _size = 8;

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _brush = widget.initialBrush;
    _decodeBg();
  }

  Future<void> _decodeBg() async {
    final img = await decodeImageFromList(widget.imageBytes);
    if (!mounted) return;
    setState(() => _bg = img);
  }

  Rect _containRect(Size content, Size box) {
    final sx = box.width / content.width;
    final sy = box.height / content.height;
    final s = sx < sy ? sx : sy;
    final w = content.width * s;
    final h = content.height * s;
    final dx = (box.width - w) / 2;
    final dy = (box.height - h) / 2;
    return Rect.fromLTWH(dx, dy, w, h);
  }

  Offset _clampInFit(Offset p) => Offset(
    p.dx.clamp(_fitRect.left, _fitRect.right),
    p.dy.clamp(_fitRect.top, _fitRect.bottom),
  );

  // ===== 手势 =====
  void _start(Offset local) {
    final p = _clampInFit(local);
    _redo.clear();
    _active = DoodleStroke(
      brush: _brush,
      color: _color,
      size: _size,
    )..points.add(p);
    setState(() => _strokes.add(_active!));
  }

  void _move(Offset local) {
    if (_active == null) return;
    final p = _clampInFit(local);
    setState(() => _active!.points.add(p));
  }

  void _end() {
    if (_active == null) return;
    // 平滑一下路径，减少锯齿
    _active!.smoothedPath = buildSmoothPath(_active!.points);
    _active = null;
  }

  // ===== 编辑动作 =====
  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redo.add(_strokes.removeLast()));
  }

  void _redoAct() {
    if (_redo.isEmpty) return;
    setState(() => _strokes.add(_redo.removeLast()));
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _redo.clear();
    });
  }

  // ===== 导出：重放路径到原图尺寸并合成 =====
  Future<void> _export() async {
    if (_bg == null) {
      Navigator.of(context).pop(widget.imageBytes);
      return;
    }
    setState(() => _exporting = true);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 背景
    final w = _bg!.width.toDouble();
    final h = _bg!.height.toDouble();
    canvas.drawImage(_bg!, Offset.zero, Paint());

    // 把涂鸦重放到原图坐标
    final sx = _bg!.width / _fitRect.width;
    final sy = _bg!.height / _fitRect.height;

    for (final s in _strokes) {
      final paint = buildPaintForStroke(s);
      // 缩放 stroke 宽度
      paint.strokeWidth = s.size * ((sx + sy) * 0.5);

      // 将 path 映射到原图坐标
      final Path path = (s.smoothedPath ?? buildSmoothPath(s.points)).transform(
        Matrix4.translationValues(-_fitRect.left, -_fitRect.top, 0)
            .scaled(sx, sy)
            .storage,
      );
      canvas.drawPath(path, paint);
    }

    // 出图
    final pic = recorder.endRecording();
    final uiImage = await pic.toImage(_bg!.width, _bg!.height);
    final png = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    setState(() => _exporting = false);
    Navigator.of(context).pop(png!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('涂鸦'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: '撤销',
            onPressed: _strokes.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: '重做',
            onPressed: _redo.isEmpty ? null : _redoAct,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: _strokes.isEmpty ? null : _clear,
            icon: const Icon(Icons.clear_all),
          ),
          TextButton(
            onPressed: _exporting ? null : _export,
            child: const Text('完成', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _bg == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (_, c) {
          _fitRect = _containRect(
            Size(_bg!.width.toDouble(), _bg!.height.toDouble()),
            Size(c.maxWidth, c.maxHeight),
          );
          return Stack(
            children: [
              // 背景图
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Image.memory(widget.imageBytes),
                ),
              ),
              // 涂鸦层
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) => _start(d.localPosition),
                  onPanUpdate: (d) => _move(d.localPosition),
                  onPanEnd: (_) => _end(),
                  onPanCancel: _end,
                  child: CustomPaint(
                    painter: DoodlePainter(
                      strokes: _strokes,
                      fitRect: _fitRect,
                    ),
                  ),
                ),
              ),
              // 面板（颜色/笔刷/大小）—— 滑动只改 UI，不打断
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: BrushPanel(
                  brush: _brush,
                  color: _color,
                  size: _size,
                  onBrushChange: (b) => setState(() => _brush = b),
                  onColorChange: (c) => setState(() => _color = c),
                  onSizeChange: (s) => setState(() => _size = s),
                ),
              ),
              if (_exporting)
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
