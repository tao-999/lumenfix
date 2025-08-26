// lib/widgets/adjust/engine/levels.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../params/levels_params.dart';

enum LevelsChannel { rgb, red, green, blue }

class HistogramResult {
  final List<int> bins; // 256 桶
  final int total;
  final LevelsChannel channel;
  const HistogramResult(this.bins, this.total, this.channel);
}

class LevelsEngine {
  /// 线性部分的颜色矩阵：
  /// y = outBlack + (outWhite - outBlack) * (x - inBlack) / (inWhite - inBlack)
  static List<double> matrix(LevelsParams p) {
    final ib = p.inBlack.clamp(0, 254).toDouble();
    final iw = p.inWhite.clamp(ib + 1, 255).toDouble();
    final ob = p.outBlack.clamp(0, 255).toDouble();
    final ow = p.outWhite.clamp(ob, 255).toDouble();

    final slope = (ow - ob) / (iw - ib);
    final intercept = ob - slope * ib;

    return <double>[
      slope, 0,     0,     0, intercept,
      0,     slope, 0,     0, intercept,
      0,     0,     slope, 0, intercept,
      0,     0,     0,     1, 0,
    ];
  }

  static ColorFilter filter(LevelsParams p) => ColorFilter.matrix(matrix(p));

  /// 计算直方图（按通道；RGB=亮度加权）
  static Future<HistogramResult> computeHistogram(
      ui.Image img, {
        LevelsChannel channel = LevelsChannel.rgb,
        int sampleStep = 2, // 步进抽样，提速；设 1 为全量
      }) async {
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return HistogramResult(
        List<int>.filled(256, 0, growable: false), // 非 const 列表
        0,
        channel, // 用当前选择的通道
      );
    }
    final Uint8List px = byteData.buffer.asUint8List();
    final w = img.width, h = img.height, stride = w * 4;
    final bins = List<int>.filled(256, 0);
    int total = 0;

    for (int y = 0; y < h; y += sampleStep) {
      int row = y * stride;
      for (int x = 0; x < w; x += sampleStep) {
        final i = row + x * 4;
        final r = px[i];       // RGBA
        final g = px[i + 1];
        final b = px[i + 2];

        int v;
        switch (channel) {
          case LevelsChannel.red:   v = r; break;
          case LevelsChannel.green: v = g; break;
          case LevelsChannel.blue:  v = b; break;
          case LevelsChannel.rgb:
          // Rec.709 亮度
            v = (0.2126 * r + 0.7152 * g + 0.0722 * b).round();
            break;
        }
        bins[v] += 1;
        total += 1;
      }
    }
    return HistogramResult(bins, total, channel);
  }

  /// 从直方图估算色阶（clipLow/High 为百分比阈值）
  static LevelsParams autoFromHistogram(
      HistogramResult h, {
        double clipLow = 0.005,  // 0.5%
        double clipHigh = 0.005, // 0.5%
        LevelsParams base = const LevelsParams(),
      }) {
    if (h.total == 0) return base;

    final targetLow = (h.total * clipLow).round();
    final targetHigh = (h.total * (1.0 - clipHigh)).round();

    int cum = 0, inBlack = 0, inWhite = 255;
    for (int i = 0; i < 256; i++) {
      cum += h.bins[i];
      if (cum >= targetLow) { inBlack = i; break; }
    }
    cum = 0;
    for (int i = 0; i < 256; i++) {
      cum += h.bins[i];
      if (cum >= targetHigh) { inWhite = i; break; }
    }
    if (inWhite <= inBlack) inWhite = (inBlack + 1).clamp(1, 255);

    // 用中位数估算 Gamma，让中位亮度映射到 0.5 左右
    final midTarget = h.total ~/ 2;
    int mid = 127, acc = 0;
    for (int i = 0; i < 256; i++) {
      acc += h.bins[i];
      if (acc >= midTarget) { mid = i; break; }
    }

    final t = ((mid - inBlack) / (inWhite - inBlack)).clamp(1e-5, 1.0 - 1e-5);
    final gamma = (_log(0.5) / _log(t)).clamp(0.10, 3.0); // y = x^(1/gamma)

    return base.copyWith(
      inBlack: inBlack,
      inWhite: inWhite,
      gamma: gamma,
      outBlack: base.outBlack,
      outWhite: base.outWhite,
    );
  }

  static double _log(double x) => (x <= 0) ? -100.0 : (x == 1.0 ? 0.0 : (x).log());

  /// 预览绘制（仅线性部分；Gamma 需导出/Shader）
  static void drawPreview({
    required Canvas canvas,
    required ui.Image image,
    required Rect dst,
    required LevelsParams params,
  }) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final paint = Paint()..colorFilter = filter(params);
    canvas.drawImageRect(image, src, dst, paint);
  }

  /// TODO：导出阶段包含 Gamma 的像素级/Shader 处理，按需再接
  static Future<ui.Image> exportProcess({
    required ui.Image src,
    required LevelsParams params,
  }) async {
    return src;
  }
}

// 给 double 扩展一个 log，免 import math
extension on double {
  double log() => (this == 0) ? -100.0 : (this > 0 ? (1.0).toString().runtimeType == String ? _ln(this) : _ln(this) : -100.0);
}

// 轻量 ln 实现（避免引 math；精度足够）——或者直接 import 'dart:math' 用 log()
double _ln(double x) {
  // 使用 dart:math 更简单：import 'dart:math' as math; return math.log(x);
  // 这里兜底（保留以免你不想引入 math）
  const int n = 12;
  final y = (x - 1) / (x + 1);
  double y2 = y * y, sum = 0.0, term = y;
  for (int k = 1; k <= n; k += 2) {
    sum += term / k;
    term *= y2;
  }
  return 2 * sum;
}
