import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../params/replace_color_params.dart';

class ReplaceColorEngine {
  /// 在 RGBA8888 上就地替换颜色
  static void applyToRgbaInPlace(
      Uint8List bytes, int w, int h, ReplaceColorParams p) {
    if (p.isNeutral) return;

    // 目标（取样）转 HSV 0..1
    final thsv = _rgbToHsv(p.sampleColor.red, p.sampleColor.green, p.sampleColor.blue);
    final tol  = (p.tolerance.clamp(0, 100)) / 100.0;

    // 预备 HSL 偏移
    final hueOff = p.hueShift / 360.0;            // 环形偏移
    final satOff = p.satShift / 100.0;
    final ligOff = p.lightShift / 100.0;

    for (int i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];

      // 当前像素 HSV
      final hsv = _rgbToHsv(r, g, b);

      // 基于 HSV 的距离（强调色相，辅以饱和度/明度）
      final dh = _hueDist(hsv[0], thsv[0]); // 0..0.5
      final ds = (hsv[1] - thsv[1]).abs();  // 0..1
      final dv = (hsv[2] - thsv[2]).abs();  // 0..1

      // 权重组合（H 0.7 / S 0.2 / V 0.1）
      final dist = 0.7 * (dh * 2.0) + 0.2 * ds + 0.1 * dv; // 0..1 近似

      // 软选择：容差越大选择越宽。m=1 表示完全命中
      double m = (tol - dist) / math.max(tol, 1e-6);
      if (m <= 0) continue;
      m = m.clamp(0.0, 1.0);

      // HSL 偏移（对命中像素），再与原像素按 m 做线性混合
      final hsl = _rgbToHsl(r, g, b);
      double nh = (hsl[0] + hueOff) % 1.0; if (nh < 0) nh += 1.0;
      final ns = (hsl[1] + satOff).clamp(0.0, 1.0);
      final nl = (hsl[2] + ligOff).clamp(0.0, 1.0);

      final nrgb = _hslToRgb(nh, ns, nl);

      bytes[i]     = _lerpByte(r, nrgb[0], m);
      bytes[i + 1] = _lerpByte(g, nrgb[1], m);
      bytes[i + 2] = _lerpByte(b, nrgb[2], m);
      // A 不变
    }
  }

  static int _lerpByte(int a, int b, double t) =>
      (a + (b - a) * t).round().clamp(0, 255);

  // ===== 工具：RGB ↔ HSV/HSL =====
  static List<double> _rgbToHsv(int r, int g, int b) {
    final rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
    final maxv = math.max(rf, math.max(gf, bf));
    final minv = math.min(rf, math.min(gf, bf));
    final delta = maxv - minv;

    double h = 0, s = 0, v = maxv;
    if (delta > 1e-6) {
      s = delta / maxv;
      if (maxv == rf) {
        h = ((gf - bf) / delta) % 6;
      } else if (maxv == gf) {
        h = (bf - rf) / delta + 2;
      } else {
        h = (rf - gf) / delta + 4;
      }
      h /= 6.0;
      if (h < 0) h += 1.0;
    } else {
      h = 0; s = 0;
    }
    return [h, s, v];
  }

  static List<double> _rgbToHsl(int r, int g, int b) {
    final rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
    final maxv = math.max(rf, math.max(gf, bf));
    final minv = math.min(rf, math.min(gf, bf));
    final l = (maxv + minv) / 2.0;

    double h = 0, s = 0;
    if (maxv != minv) {
      final d = maxv - minv;
      s = l > 0.5 ? d / (2.0 - maxv - minv) : d / (maxv + minv);
      if (maxv == rf) {
        h = (gf - bf) / d + (gf < bf ? 6 : 0);
      } else if (maxv == gf) {
        h = (bf - rf) / d + 2;
      } else {
        h = (rf - gf) / d + 4;
      }
      h /= 6.0;
    }
    return [h, s, l];
  }

  static List<int> _hslToRgb(double h, double s, double l) {
    int c(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1/6) return ((p + (q - p) * 6 * t) * 255 + 0.5).floor();
      if (t < 1/2) return (q * 255 + 0.5).floor();
      if (t < 2/3) return ((p + (q - p) * (2/3 - t) * 6) * 255 + 0.5).floor();
      return (p * 255 + 0.5).floor();
    }
    if (s == 0) {
      final v = (l * 255 + 0.5).floor();
      return [v, v, v];
    }
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    final r = c(p, q, h + 1/3);
    final g = c(p, q, h);
    final b = c(p, q, h - 1/3);
    return [r.clamp(0,255), g.clamp(0,255), b.clamp(0,255)];
  }

  static double _hueDist(double a, double b) {
    final d = (a - b).abs();
    return math.min(d, 1.0 - d); // 0..0.5
  }
}
