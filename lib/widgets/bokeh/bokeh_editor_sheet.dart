// 📄 lib/widgets/bokeh/bokeh_editor_sheet.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'sub/bokeh_models.dart';
import 'sub/bokeh_preview_painter.dart';
import 'sub/bokeh_panel.dart';

class BokehEditorSheet extends StatefulWidget {
  const BokehEditorSheet({super.key, required this.imageBytes});
  final Uint8List imageBytes;

  @override
  State<BokehEditorSheet> createState() => _BokehEditorSheetState();
}

class _BokehEditorSheetState extends State<BokehEditorSheet> {
  ui.Image? _orig;
  ui.Image? _blurred;
  Rect _fitRect = Rect.zero;

  // 参数
  BokehMode _mode = BokehMode.ellipse;
  double _blurSigma = 14;   // 模糊强度（松手才重建）
  double _feather = 12;     // 边缘羽化（屏幕像素）
  bool _rebuilding = false; // 正在重建模糊底图
  bool _exporting = false;  // 正在导出

  // 椭圆：可空 + 懒初始化（避免 LateInitializationError）
  EllipseParams? _ellipse;
  late EllipseParams _ellipseStart;
  Offset _scaleStartFocal = Offset.zero;

  // 套索路径（屏幕坐标）
  final List<Offset> _lasso = [];
  bool _lassoClosed = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final img = await decodeImageFromList(widget.imageBytes);
    if (!mounted) return;
    setState(() => _orig = img);
    await _rebuildBlur();
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

  // 仅在滑条松手时重建模糊底图，避免卡顿
  Future<void> _rebuildBlur() async {
    if (_orig == null) return;
    setState(() => _rebuilding = true);

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final paint = Paint()
      ..imageFilter = ui.ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma);
    final full = Offset.zero &
    Size(_orig!.width.toDouble(), _orig!.height.toDouble());

    c.saveLayer(full, paint);
    c.drawImage(_orig!, Offset.zero, Paint());
    c.restore();

    final pic = rec.endRecording();
    final img = await pic.toImage(_orig!.width, _orig!.height);
    if (!mounted) return;
    setState(() {
      _blurred = img;
      _rebuilding = false;
    });
  }

  // —— 导出：原图 + (模糊 ∩ mask)，mask 白=模糊、黑=清晰 —— //
  Future<void> _export() async {
    if (_orig == null) return Navigator.pop(context, widget.imageBytes);
    if (_blurred == null) await _rebuildBlur();

    setState(() => _exporting = true);

    final mask = await _buildMaskImage(Size(
      _orig!.width.toDouble(),
      _orig!.height.toDouble(),
    ));

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final full = Offset.zero &
    Size(_orig!.width.toDouble(), _orig!.height.toDouble());

    // 底：原图
    c.drawImage(_orig!, Offset.zero, Paint());

    // 顶：模糊 ∩ mask（保留白处的模糊）
    c.saveLayer(full, Paint());                              // A
    c.drawImage(_blurred!, Offset.zero, Paint());
    c.saveLayer(full, Paint()..blendMode = BlendMode.dstIn); // B
    c.drawImage(mask, Offset.zero, Paint());
    c.restore();                                             // end B
    c.restore();                                             // end A

    final pic = rec.endRecording();
    final out = await pic.toImage(_orig!.width, _orig!.height);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);

    if (!mounted) return;
    setState(() => _exporting = false);
    Navigator.pop(context, data!.buffer.asUint8List());
  }

  Future<ui.Image> _buildMaskImage(Size size) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final full = Offset.zero & size;

    // 外部区域 path（原图分辨率坐标）
    final outside = Path()..fillType = PathFillType.evenOdd..addRect(full);

    // 内部(清晰)形状 path
    Path inner;
    if (_mode == BokehMode.ellipse) {
      final e = _ellipse!;
      final sx = size.width / _fitRect.width;
      final sy = size.height / _fitRect.height;
      final center = Offset(
        (e.center.dx - _fitRect.left) * sx,
        (e.center.dy - _fitRect.top) * sy,
      );
      final oval = Path()
        ..addOval(Rect.fromCenter(
          center: Offset.zero, width: e.rx * 2 * sx, height: e.ry * 2 * sy,
        ));
      final m = Matrix4.identity()..translate(center.dx, center.dy)..rotateZ(e.angle);
      inner = oval.transform(m.storage);
    } else {
      final sx = size.width / _fitRect.width;
      final sy = size.height / _fitRect.height;
      final p = Path();
      for (int i = 0; i < _lasso.length; i++) {
        final a = _lasso[i];
        final b = Offset((a.dx - _fitRect.left) * sx, (a.dy - _fitRect.top) * sy);
        if (i == 0) p.moveTo(b.dx, b.dy); else p.lineTo(b.dx, b.dy);
      }
      p.close();
      inner = p;
    }
    outside.addPath(inner, Offset.zero);

    // Feather 换算到原图像素
    final featherPx = _feather * _screenToImageScale(size);

    // 先画“羽化外侧白”
    if (featherPx > 0) {
      c.drawPath(
        outside,
        Paint()
          ..isAntiAlias = true
          ..color = Colors.white
          ..style = PaintingStyle.fill
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, featherPx),
      );
    }
    // 再画“实心外侧白”
    c.drawPath(
      outside,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    // 最后内部 clear（α=0）
    c.drawPath(inner, Paint()..blendMode = BlendMode.clear);

    final pic = rec.endRecording();
    return pic.toImage(size.width.toInt(), size.height.toInt());
  }

  double _screenToImageScale(Size imageSize) {
    final sx = imageSize.width / _fitRect.width;
    final sy = imageSize.height / _fitRect.height;
    return (sx + sy) * 0.5; // 近似把屏幕像素的羽化换算到原图像素
  }

  // —— 椭圆手势（实时 setState） —— //
  void _onScaleStart(ScaleStartDetails d) {
    _ellipseStart = _ellipse!.copy();
    _scaleStartFocal = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final df = d.focalPoint - _scaleStartFocal;
    setState(() {
      _ellipse!.center = _ellipseStart.center + df; // 拖动
      _ellipse!.rx =
          (_ellipseStart.rx * d.horizontalScale).clamp(8, _fitRect.width);
      _ellipse!.ry =
          (_ellipseStart.ry * d.verticalScale).clamp(8, _fitRect.height);
      _ellipse!.angle = _ellipseStart.angle + d.rotation; // 旋转
      _clampEllipse();
    });
  }

  void _clampEllipse() {
    if (_ellipse == null) return;
    final e = _ellipse!;
    final cx = e.center.dx.clamp(_fitRect.left, _fitRect.right);
    final cy = e.center.dy.clamp(_fitRect.top, _fitRect.bottom);
    e.center = Offset(cx, cy);
    e.rx = e.rx.clamp(8, _fitRect.width);
    e.ry = e.ry.clamp(8, _fitRect.height);
  }

  // —— 套索手势（实时预览：未闭合也按闭合显示“内清晰、外模糊”） —— //
  void _lassoStart(Offset p) {
    if (_lassoClosed) {
      _lasso.clear();
      _lassoClosed = false;
    }
    if (!_fitRect.contains(p)) return;
    setState(() => _lasso.add(p));
  }

  void _lassoMove(Offset p) {
    if (!_fitRect.contains(p)) return;
    if (_lasso.isEmpty || (p - _lasso.last).distance > 2) {
      setState(() => _lasso.add(p));
    }
  }

  void _lassoEnd() {}
  void _lassoClose() {
    if (_lasso.length >= 3) setState(() => _lassoClosed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('背景虚化'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_mode == BokehMode.lasso)
            TextButton(
              onPressed: _lassoClose,
              child: const Text('闭合', style: TextStyle(color: Colors.white)),
            ),
          TextButton(
            onPressed: _exporting ? null : _export,
            child: const Text('完成', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: (_orig == null || _blurred == null)
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (_, c) {
          final imgSize =
          Size(_orig!.width.toDouble(), _orig!.height.toDouble());
          _fitRect = _containRect(
              imgSize, Size(c.maxWidth, c.maxHeight - 120));

          // 懒初始化，使用前确保有值
          _ellipse ??= EllipseParams(
            center: _fitRect.center,
            rx: _fitRect.width * 0.28,
            ry: _fitRect.height * 0.22,
            angle: 0,
          );
          final ellipse = _ellipse!;

          return Stack(
            children: [
              // 预览（区域内清晰、区域外虚化）
              Positioned.fill(
                child: CustomPaint(
                  painter: BokehPreviewPainter(
                    orig: _orig!,
                    blurred: _blurred!,
                    fitRect: _fitRect,
                    mode: _mode,
                    ellipse: ellipse,
                    lassoPoints: _lasso,
                    lassoClosed: _lassoClosed,
                    feather: _feather,
                  ),
                ),
              ),

              // 手势层
              Positioned.fill(
                child: (_mode == BokehMode.ellipse)
                    ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                )
                    : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) => _lassoStart(d.localPosition),
                  onPanUpdate: (d) => _lassoMove(d.localPosition),
                  onPanEnd: (_) => _lassoEnd(),
                  onDoubleTap: _lassoClose,
                ),
              ),

              // 底部控制面板
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BokehPanel(
                  mode: _mode,
                  onModeChange: (m) {
                    setState(() {
                      _mode = m;
                      if (m == BokehMode.lasso) {
                        _lassoClosed = false;
                      }
                    });
                  },
                  blurSigma: _blurSigma,
                  onBlurChanged: (v) => setState(() => _blurSigma = v),
                  onBlurChangeEnd: (_) => _rebuildBlur(), // 松手再重建底图
                  feather: _feather,
                  onFeatherChange: (v) => setState(() => _feather = v),
                  onClearLasso: () => setState(() {
                    _lasso.clear();
                    _lassoClosed = false;
                  }),
                  rebuilding: _rebuilding,
                ),
              ),

              if (_exporting)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
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
