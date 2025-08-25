import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'bokeh_models.dart';

class BokehPreviewPainter extends CustomPainter {
  BokehPreviewPainter({
    required this.orig,
    required this.blurred,
    required this.fitRect,
    required this.mode,
    required this.ellipse,
    required this.lassoPoints,
    required this.lassoClosed,
    required this.feather,
  });

  final ui.Image orig;
  final ui.Image blurred;
  final Rect fitRect;
  final BokehMode mode;
  final EllipseParams ellipse;
  final List<Offset> lassoPoints;
  final bool lassoClosed;
  final double feather;

  @override
  void paint(Canvas canvas, Size size) {
    if (fitRect.isEmpty) return;

    // 底：原图
    _drawImageRect(canvas, orig, fitRect);

    final full = Offset.zero & size;

    // 顶：模糊图 ∩ mask（白=保留模糊，黑/透明=不模糊）
    canvas.saveLayer(full, Paint());                         // A
    _drawImageRect(canvas, blurred, fitRect);
    canvas.saveLayer(full, Paint()..blendMode = BlendMode.dstIn); // B
    canvas.drawPicture(_buildMaskPicture(size));             // 只在遮罩白处保留模糊
    canvas.restore();                                        // end B
    canvas.restore();                                        // end A

    // 可选：辅助线
    final bp = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    if (mode == BokehMode.ellipse) {
      canvas.save();
      canvas.translate(ellipse.center.dx, ellipse.center.dy);
      canvas.rotate(ellipse.angle);
      final r = Rect.fromCenter(
        center: Offset.zero, width: ellipse.rx * 2, height: ellipse.ry * 2,
      );
      canvas.drawOval(r, bp);
      canvas.restore();
    } else if (lassoPoints.isNotEmpty) {
      final p = Path()..addPolygon(lassoPoints, lassoClosed);
      canvas.drawPath(p, bp);
    }
  }

  void _drawImageRect(Canvas canvas, ui.Image img, Rect dst) {
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(img, src, dst, Paint());
  }

  ui.Picture _buildMaskPicture(Size size) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final full = Offset.zero & size;

    // 外部区域 path：even-odd = [全屏矩形 + 内部形状]
    final outside = Path()..fillType = PathFillType.evenOdd..addRect(full);

    // 内部(清晰)形状 path
    Path inner;
    if (mode == BokehMode.ellipse) {
      final oval = Path()
        ..addOval(Rect.fromCenter(
          center: Offset.zero, width: ellipse.rx * 2, height: ellipse.ry * 2,
        ));
      final m = Matrix4.identity()
        ..translate(ellipse.center.dx, ellipse.center.dy)
        ..rotateZ(ellipse.angle);
      inner = oval.transform(m.storage);
    } else {
      inner = Path()..addPolygon(lassoPoints, true); // 预览强制闭合
    }
    outside.addPath(inner, Offset.zero);

    // 先画“羽化版外侧白”，产生边界过渡
    if (feather > 0) {
      c.drawPath(
        outside,
        Paint()
          ..isAntiAlias = true
          ..color = Colors.white
          ..style = PaintingStyle.fill
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, feather),
      );
    }
    // 再画“实心外侧白”，确保外部 α=1
    c.drawPath(
      outside,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    // 最后用 clear 把内部区域挖空（α=0），确保内部永远不模糊
    c.drawPath(inner, Paint()..blendMode = BlendMode.clear);

    return rec.endRecording();
  }

  @override
  bool shouldRepaint(covariant BokehPreviewPainter old) =>
      old.orig != orig ||
          old.blurred != blurred ||
          old.fitRect != fitRect ||
          old.mode != mode ||
          old.ellipse.center != ellipse.center ||
          old.ellipse.rx != ellipse.rx ||
          old.ellipse.ry != ellipse.ry ||
          old.ellipse.angle != ellipse.angle ||
          old.lassoPoints != lassoPoints ||
          old.lassoClosed != lassoClosed ||
          old.feather != feather;
}
