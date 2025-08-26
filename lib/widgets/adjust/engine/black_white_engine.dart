import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../params/black_white_params.dart';

class BlackWhiteEngine {
  static Future<ui.Image> applyToImage(ui.Image src, BlackWhiteParams p) async {
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = bd!.buffer.asUint8List();
    applyToRgbaInPlace(bytes, src.width, src.height, p);
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, src.width, src.height, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  /// 算法说明：
  /// 1) 先算像素的亮度 Y（0.299/0.587/0.114）
  /// 2) 用色相 H 计算落在 Reds/Yellows/... 六个扇区的余弦权重
  /// 3) 对应权重把“亮度缩放系数”插值：scale = sum(w * (slider/128)) / sum(w)
  /// 4) 灰度 = Y * scale；写入 R=G=B
  /// 5) 若着色：把灰度作为 L，用着色色相/饱和生成颜色，再按强度与灰度混合
  static void applyToRgbaInPlace(Uint8List data, int w, int h, BlackWhiteParams p) {
    if (!p.enabled) return;

    // 扇区中心（度）
    const centers = <double>[0, 60, 120, 180, 240, 300];
    const hueHalfWidth = 60.0; // 半宽，两个相邻扇区会平滑过渡

    // 六色缩放（128 为中性 1.0）
    final scales = <double>[
      p.reds / 128.0,
      p.yellows / 128.0,
      p.greens / 128.0,
      p.cyans / 128.0,
      p.blues / 128.0,
      p.magentas / 128.0,
    ];

    // tint 准备：转 HSL，用灰度替换 L
    final tintHueSat = _rgbToHsl(
      (p.tintColor.red   / 255.0),
      (p.tintColor.green / 255.0),
      (p.tintColor.blue  / 255.0),
    );

    for (int i = 0, pi = 0; i < w * h; i++, pi += 4) {
      double r = data[pi] / 255.0;
      double g = data[pi + 1] / 255.0;
      double b = data[pi + 2] / 255.0;

      // 亮度（gamma 空间近似）
      final y = (0.299 * r + 0.587 * g + 0.114 * b).clamp(0.0, 1.0);

      // 求 HSL.H（0..1）和 L
      final hsl = _rgbToHsl(r, g, b);
      double hueDeg = hsl[0] * 360.0;

      // 计算六个扇区的权重
      double wsum = 0.0, ssum = 0.0;
      for (int k = 0; k < 6; k++) {
        final wgt = _cosWindow(_angDistDeg(hueDeg, centers[k]), hueHalfWidth);
        if (wgt <= 0) continue;
        wsum += wgt;
        ssum += wgt * scales[k];
      }
      final scale = (wsum > 0 ? (ssum / wsum) : 1.0);

      // 灰度
      double gray = (y * scale).clamp(0.0, 1.0);

      // 着色（按强度混合）
      if (p.tintEnable && p.tintStrength > 0) {
        final hh = tintHueSat[0];      // tint H
        final ss = tintHueSat[1];      // tint S
        final tinted = _hslToRgb(hh, ss, gray); // 用灰度作为 L
        r = _mix(gray, tinted[0], p.tintStrength);
        g = _mix(gray, tinted[1], p.tintStrength);
        b = _mix(gray, tinted[2], p.tintStrength);
      } else {
        r = g = b = gray;
      }

      data[pi]     = (r * 255.0).round().clamp(0, 255);
      data[pi + 1] = (g * 255.0).round().clamp(0, 255);
      data[pi + 2] = (b * 255.0).round().clamp(0, 255);
      // alpha 原样
    }
  }

  // —— 工具函数 —— //
  static double _cosWindow(double distDeg, double halfWidth) {
    if (distDeg >= halfWidth) return 0.0;
    final x = distDeg / halfWidth;
    return 0.5 * (math.cos(math.pi * x) + 1.0);
  }

  static double _angDistDeg(double a, double b) {
    double d = (a - b).abs() % 360.0;
    if (d > 180.0) d = 360.0 - d;
    return d;
  }

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

  static List<double> _hslToRgb(double h, double s, double l) {
    double hue2rgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1/6) return p + (q - p) * 6 * t;
      if (t < 1/2) return q;
      if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
      return p;
    }
    double r, g, b;
    if (s == 0) {
      r = g = b = l;
    } else {
      final q = l < 0.5 ? l * (1 + s) : (l + s - l * s);
      final p = 2 * l - q;
      r = hue2rgb(p, q, h + 1/3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1/3);
    }
    return <double>[r, g, b];
  }

  static double _mix(double a, double b, double t) => a + (b - a) * t;
}
