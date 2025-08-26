// lib/widgets/adjust/engine/brightness_contrast.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../params/brightness_contrast_params.dart';

/// 亮度/对比度引擎：生成 ColorFilter 矩阵，或直接 draw。
class BrightnessContrastEngine {
  /// brightness: -100..100, contrast: -100..100
  static List<double> matrix(double brightness, double contrast) {
    final c = 1.0 + (contrast / 100.0);     // [0, 2]
    final b = (brightness / 100.0) * 255.0; // [-255, 255]
    // 围绕 127.5 做对比度缩放：offset = (1 - c) * 127.5 + b
    final t = (1.0 - c) * 127.5 + b;

    return <double>[
      c, 0, 0, 0, t, // R
      0, c, 0, 0, t, // G
      0, 0, c, 0, t, // B
      0, 0, 0, 1, 0, // A
    ];
  }

  static ColorFilter filter(BrightnessContrast bc) =>
      ColorFilter.matrix(matrix(bc.brightness, bc.contrast));

  /// 直接绘制到画布（包含 contain 的常用画法）
  static void draw({
    required Canvas canvas,
    required ui.Image image,
    required Rect dst,
    BrightnessContrast bc = const BrightnessContrast(),
  }) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final paint = Paint()..colorFilter = filter(bc);
    canvas.drawImageRect(image, src, dst, paint);
  }
}
