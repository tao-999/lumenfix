import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../services/doodle_service.dart';
import 'stroke.dart';
import 'path_utils.dart';

class DoodlePainter extends CustomPainter {
  DoodlePainter({
    required this.strokes,
    required this.fitRect,
  });

  final List<DoodleStroke> strokes;
  final Rect fitRect;

  @override
  void paint(Canvas canvas, Size size) {
    if (fitRect.isEmpty) return;

    canvas.save();
    // 仅在 fitRect 范围内绘制涂鸦
    canvas.clipRect(fitRect);

    for (final s in strokes) {
      if (s.points.length < 2) continue;

      final path = s.smoothedPath ?? buildSmoothPath(s.points);
      final paint = buildPaintForStroke(s);
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DoodlePainter oldDelegate) =>
      oldDelegate.strokes != strokes || oldDelegate.fitRect != fitRect;
}

/// 构造不同比较风格的 Paint（仅用于屏幕展示，导出时会重新设置 strokeWidth）
Paint buildPaintForStroke(DoodleStroke s) {
  final p = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = s.size;

  switch (s.brush) {
    case DoodleBrushType.pen:
      p.color = s.color;
      p.blendMode = BlendMode.srcOver;
      break;
    case DoodleBrushType.marker:
      p.color = s.color.withOpacity(0.9);
      p.strokeMiterLimit = 2;
      p.blendMode = BlendMode.srcOver;
      break;
    case DoodleBrushType.highlighter:
      p.color = s.color.withOpacity(0.35);
      p.blendMode = BlendMode.multiply; // 高亮和底图相乘更自然
      break;
    case DoodleBrushType.neon:
    // 先画外发光（大笔宽+模糊），再画本体
    // 注意：屏幕显示阶段只画一次；导出时也用同策略
      p.color = s.color.withOpacity(0.85);
      p.maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
      break;
    case DoodleBrushType.eraser:
      p.color = Colors.transparent;
      p.blendMode = BlendMode.clear; // 清除上一次内容
      break;
  }
  return p;
}
