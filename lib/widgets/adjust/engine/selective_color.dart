import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../params/selective_color_params.dart';

class SelectiveColorEngine {
  static Future<ui.Image> applyToImage(ui.Image src, SelectiveColorParams p) async {
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = bd!.buffer.asUint8List();
    applyToRgbaInPlace(bytes, src.width, src.height, p);
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, src.width, src.height, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  /// PS-like 可选颜色（单目标版）：
  /// - 目标 Reds/Yellows/... 用色相窗口；Whites/Neutrals/Blacks 用亮度窗口
  /// - 绝对：固定比例直接加减 RGB
  /// - 相对：按当前量/黑量比例加减（更温和）
  static void applyToRgbaInPlace(Uint8List data, int w, int h, SelectiveColorParams p) {
    if (p.isNeutral) return;

    // —— 标定强度（更接近 PS 手感）——
    const double ABS_SCALE = 0.22;   // 100% ≈ 改动 22% 通道
    const double REL_SCALE = 0.35;   // 相对模式整体系数
    const double HUE_WIDTH = 55.0;   // 目标色相半宽（度），稍宽一些更容易命中

    final double c = (p.cyan    / 100.0);   // -1..1 (加青=减红)
    final double m = (p.magenta / 100.0);   // (加品红=减绿)
    final double y = (p.yellow  / 100.0);   // (加黄=减蓝)
    final double k = (p.black   / 100.0);   // (加黑=减RGB)

    double hueWeight(double hueDeg, double centerDeg) {
      final d = _angDistDeg(hueDeg, centerDeg);
      if (d >= HUE_WIDTH) return 0.0;
      final x = d / HUE_WIDTH; // 0..1
      return 0.5 * (math.cos(math.pi * x) + 1.0); // 余弦窗
    }

    double wWhite(double l) { // L 越高越大
      final t = ((l - 0.6) / 0.4).clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }
    double wBlack(double l) { // L 越低越大
      final t = (l / 0.35).clamp(0.0, 1.0);
      final s = t * t * (3 - 2 * t);
      return 1.0 - s;
    }
    double wNeutral(double l) { // 中间调最大
      final tri = (1.0 - (2.0 * (l - 0.5)).abs()).clamp(0.0, 1.0);
      return tri * tri * (3 - 2 * tri);
    }

    double center(SelectiveColorTarget t) {
      switch (t) {
        case SelectiveColorTarget.reds:     return 0.0;
        case SelectiveColorTarget.yellows:  return 60.0;
        case SelectiveColorTarget.greens:   return 120.0;
        case SelectiveColorTarget.cyans:    return 180.0;
        case SelectiveColorTarget.blues:    return 240.0;
        case SelectiveColorTarget.magentas: return 300.0;
        default: return 0.0;
      }
    }

    for (int i = 0, pi = 0; i < w * h; i++, pi += 4) {
      double r = data[pi] / 255.0;
      double g = data[pi + 1] / 255.0;
      double b = data[pi + 2] / 255.0;

      // RGB -> HSL（只需 H/L）
      final hsl = _rgbToHsl(r, g, b);
      final hueDeg = hsl[0] * 360.0;
      final l = hsl[2];

      // 计算目标权重
      double wgt = 0.0;
      switch (p.target) {
        case SelectiveColorTarget.whites:   wgt = wWhite(l);   break;
        case SelectiveColorTarget.neutrals: wgt = wNeutral(l); break;
        case SelectiveColorTarget.blacks:   wgt = wBlack(l);   break;
        default: wgt = hueWeight(hueDeg, center(p.target));
      }
      if (wgt <= 0.0) continue;

      if (p.absolute) {
        // 绝对：直接固定比例改变通道
        r = _sat(r + (-c - k) * ABS_SCALE * wgt);
        g = _sat(g + (-m - k) * ABS_SCALE * wgt);
        b = _sat(b + (-y - k) * ABS_SCALE * wgt);
      } else {
        // 相对：跟随当前量（黑量与最大值反比）
        final maxi = math.max(r, math.max(g, b));
        final kRel = (1.0 - maxi);
        r = _sat(r + ((-c) * r + (-k) * kRel) * REL_SCALE * wgt);
        g = _sat(g + ((-m) * g + (-k) * kRel) * REL_SCALE * wgt);
        b = _sat(b + ((-y) * b + (-k) * kRel) * REL_SCALE * wgt);
      }

      data[pi]     = (r * 255.0).round().clamp(0, 255);
      data[pi + 1] = (g * 255.0).round().clamp(0, 255);
      data[pi + 2] = (b * 255.0).round().clamp(0, 255);
    }
  }

  /* ===== utils ===== */

  static List<double> _rgbToHsl(double r, double g, double b) {
    final maxc = math.max(r, math.max(g, b));
    final minc = math.min(r, math.min(g, b));
    final l = (maxc + minc) * 0.5;
    double h, s;
    if (maxc == minc) {
      h = 0.0; s = 0.0;
    } else {
      final d = maxc - minc;
      s = l > 0.5 ? d / (2.0 - maxc - minc) : d / (maxc + minc);
      if (maxc == r) {
        h = ((g - b) / d + (g < b ? 6.0 : 0.0)) / 6.0;
      } else if (maxc == g) {
        h = ((b - r) / d + 2.0) / 6.0;
      } else {
        h = ((r - g) / d + 4.0) / 6.0;
      }
    }
    return <double>[h, s, l];
  }

  static double _angDistDeg(double a, double b) {
    double d = (a - b).abs() % 360.0;
    if (d > 180.0) d = 360.0 - d;
    return d;
  }

  static double _sat(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
}
