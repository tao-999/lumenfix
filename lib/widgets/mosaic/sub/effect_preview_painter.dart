import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'stroke.dart';

class EffectPreviewPainter extends CustomPainter {
  final ui.Image effect;
  final Rect fitRect;
  final List<StrokePath> strokes;

  EffectPreviewPainter({
    required this.effect,
    required this.fitRect,
    required this.strokes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fitRect.isEmpty) return;

    final src = Rect.fromLTWH(
      0, 0, effect.width.toDouble(), effect.height.toDouble(),
    );

    for (final s in strokes) {
      if (s.points.length < 2) continue;

      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (int i = 1; i < s.points.length; i++) {
        final v = s.points[i];
        path.lineTo(v.dx, v.dy);
      }

      canvas.saveLayer(Offset.zero & size, Paint());
      final strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s.strokeWidth;
      canvas.drawPath(path, strokePaint);

      final paint = Paint()..blendMode = BlendMode.srcIn;
      canvas.drawImageRect(effect, src, fitRect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant EffectPreviewPainter old) =>
      old.effect != effect || old.fitRect != fitRect || old.strokes != strokes;
}
