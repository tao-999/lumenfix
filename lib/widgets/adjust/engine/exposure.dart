// lib/widgets/adjust/engine/exposure.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../params/exposure_params.dart';

class ExposureEngine {
  /// 预览颜色矩阵：只处理 EV（乘 2^EV）和 Offset（加偏置）
  static List<double> previewMatrix(ExposureParams p) {
    final s = math.pow(2.0, p.ev).toDouble(); // scale
    final add = (p.offset * 255.0);           // bias in 8-bit
    return <double>[
      s, 0, 0, 0, add,
      0, s, 0, 0, add,
      0, 0, s, 0, add,
      0, 0, 0, 1, 0,
    ];
  }

  static ColorFilter previewFilter(ExposureParams p)
  => ColorFilter.matrix(previewMatrix(p));

  /// 组合两个 4x5 矩阵（先 A 后 B，得到 B∘A）
  static List<double> combine(List<double> a, List<double> b) {
    List<List<double>> mA = List.generate(4, (i) => List.generate(4, (j) => a[i*5 + j]));
    List<double> cA = List.generate(4, (i) => a[i*5 + 4]);

    List<List<double>> mB = List.generate(4, (i) => List.generate(4, (j) => b[i*5 + j]));
    List<double> cB = List.generate(4, (i) => b[i*5 + 4]);

    final m = List.generate(4, (_) => List.filled(4, 0.0));
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        double s = 0.0;
        for (int k = 0; k < 4; k++) {
          s += mB[i][k] * mA[k][j];
        }
        m[i][j] = s;
      }
    }
    final c = List.filled(4, 0.0);
    for (int i = 0; i < 4; i++) {
      double s = 0.0;
      for (int k = 0; k < 4; k++) {
        s += mB[i][k] * cA[k];
      }
      c[i] = s + cB[i];
    }

    return <double>[
      m[0][0], m[0][1], m[0][2], m[0][3], c[0],
      m[1][0], m[1][1], m[1][2], m[1][3], c[1],
      m[2][0], m[2][1], m[2][2], m[2][3], c[2],
      m[3][0], m[3][1], m[3][2], m[3][3], c[3],
    ];
  }

  /// 预览绘制（只做 EV+Offset；Gamma 需导出时再处理）
  static void drawPreview({
    required Canvas canvas,
    required ui.Image image,
    required Rect dst,
    ExposureParams p = const ExposureParams(),
  }) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final paint = Paint()..colorFilter = previewFilter(p);
    canvas.drawImageRect(image, src, dst, paint);
  }

  /// 导出阶段（包含 gamma）的占位：需要像素级处理或 shader
  static Future<ui.Image> exportProcess({
    required ui.Image src,
    required ExposureParams p,
  }) async {
    // TODO: 如需导出包含 gamma，请在导出链路实现逐像素 gamma 或 runtime shader。
    return src;
  }
}
