// lib/widgets/adjust/engine/gradient_map_engine.dart
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../params/gradient_map_params.dart';

class GradientMapEngine {
  static void applyToRgbaInPlace(
      Uint8List rgba,
      int width,
      int height,
      GradientMapParams p,
      ) {
    if (p.isNeutral) return;

    // 1) 预构建 256 项查表
    final lut = _buildGradientLut(p);

    // 2) 逐像素：按亮度映射颜色，再按 strength 混合
    final n = width * height;
    final s = p.strength.clamp(0.0, 1.0);
    for (int i = 0, pi = 0; i < n; i++, pi += 4) {
      final r = rgba[pi] / 255.0;
      final g = rgba[pi + 1] / 255.0;
      final b = rgba[pi + 2] / 255.0;

      // sRGB 亮度（近似 Rec.709）
      final l = (0.2126 * r + 0.7152 * g + 0.0722 * b)
          .clamp(0.0, 1.0);

      // 抖动：蓝噪声近似（hash）
      double idx = l * 255.0;
      if (p.dither) {
        final j = (i * 1103515245 + 12345) & 0x7fffffff;
        final noise = ((j % 1024) / 1023.0 - 0.5) * (1.0); // ~±0.5
        idx = (idx + noise).clamp(0.0, 255.0);
      }

      final c = lut[idx.round()];

      // 混合
      rgba[pi]     = (_mix(r, c[0], s) * 255.0).round().clamp(0, 255);
      rgba[pi + 1] = (_mix(g, c[1], s) * 255.0).round().clamp(0, 255);
      rgba[pi + 2] = (_mix(b, c[2], s) * 255.0).round().clamp(0, 255);
    }
  }

  static double _mix(double a, double b, double t) => a + (b - a) * t;

  static List<List<double>> _buildGradientLut(GradientMapParams p) {
    // 复制 + 排序 + 反向
    List<GradientStop> stops = List.of(p.stops);
    stops.sort((a, b) => a.pos.compareTo(b.pos));
    if (p.reverse) {
      stops = stops
          .map((e) => e.copyWith(pos: 1.0 - e.pos))
          .toList()
        ..sort((a, b) => a.pos.compareTo(b.pos));
    }
    // 安全端点
    if (stops.first.pos > 0.0) {
      stops = [GradientStop(pos: 0, color: stops.first.color), ...stops];
    }
    if (stops.last.pos < 1.0) {
      stops = [...stops, GradientStop(pos: 1, color: stops.last.color)];
    }

    // 生成 256 LUT
    final lut = List<List<double>>.generate(256, (_) => [0, 0, 0]);
    int si = 0;
    for (int i = 0; i < 256; i++) {
      final t = i / 255.0;

      while (si < stops.length - 2 && t > stops[si + 1].pos) si++;
      final a = stops[si];
      final b = stops[si + 1];
      final span = (b.pos - a.pos).clamp(1e-6, 1.0);
      final u = ((t - a.pos) / span).clamp(0.0, 1.0);

      // Classic: 在 sRGB 直接插值；Perceptual：在近似伽马空间插值
      Color ca = a.color, cb = b.color;
      double lerp(double x, double y) => x + (y - x) * u;

      double rr, gg, bb;
      if (p.method == GradientMethod.perceptual) {
        // 简化：以 gamma=2.2 执行线性空间插值
        double toLin(int v) => math.pow(v / 255.0, 2.2).toDouble();
        double toSrgb(double v) => math.pow(v, 1 / 2.2).toDouble();

        final r1 = toLin(ca.red),   r2 = toLin(cb.red);
        final g1 = toLin(ca.green), g2 = toLin(cb.green);
        final b1 = toLin(ca.blue),  b2 = toLin(cb.blue);

        rr = toSrgb(lerp(r1, r2));
        gg = toSrgb(lerp(g1, g2));
        bb = toSrgb(lerp(b1, b2));
      } else {
        rr = lerp(ca.red / 255.0,  cb.red  / 255.0);
        gg = lerp(ca.green / 255.0,cb.green/ 255.0);
        bb = lerp(ca.blue / 255.0, cb.blue / 255.0);
      }
      lut[i][0] = rr;
      lut[i][1] = gg;
      lut[i][2] = bb;
    }
    return lut;
  }
}
