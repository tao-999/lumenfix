import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';

import '../params/hsl_params.dart';

class HslEngine {
  /// 与 VibranceEngine 同款管线：toByteData(rawRgba) -> 改字节 -> decodeImageFromPixels
  static Future<ui.Image> applyToImage(ui.Image src, HslParams params) async {
    final w = src.width, h = src.height;
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return src;

    final bytes = bd.buffer.asUint8List(); // RGBA8888
    _applyToRgbaInPlace(bytes, w, h, params);

    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      w,
      h,
      ui.PixelFormat.rgba8888,
      c.complete,
      // rowBytes 可省略（= w * 4），若你后面做行对齐再填
    );
    return c.future;
  }

  /// 原地修改 RGBA 像素
  static void _applyToRgbaInPlace(
      Uint8List rgba, int width, int height, HslParams p) {
    final master = p.bands[HslBand.master] ?? const HslBandAdjust();

    // 各色域中心角
    final centers = <HslBand, double>{
      for (final b in HslBand.values)
        if (b != HslBand.master) b: kBandCentersDeg[b]!,
    };

    for (int i = 0; i < rgba.length; i += 4) {
      final a = rgba[i + 3] / 255.0;
      if (a == 0) continue;

      final r = rgba[i] / 255.0;
      final g = rgba[i + 1] / 255.0;
      final b = rgba[i + 2] / 255.0;

      var hsl = _rgbToHsl(r, g, b); // h:[0,360), s:[0,1], l:[0,1]

      if (p.colorize) {
        // 着色：直接指定 H/S/L
        hsl.h = _wrapDegLocal(p.colorizeHueDeg);
        hsl.s = _clamp01(p.colorizeSatPercent / 100.0);
        hsl.l = _clamp01((p.colorizeLightPercent + 100.0) / 200.0);
      } else {
        // 计算色域权重（三角羽化：核心60° + 两侧 featherDeg）
        double wSum = 0;
        final weights = <HslBand, double>{};
        for (final e in centers.entries) {
          final dist = _circularDistDeg(hsl.h, e.value);
          final w = _weight(dist, p.featherDeg);
          if (w > 0) {
            weights[e.key] = w;
            wSum += w;
          }
        }
        if (wSum > 0) {
          weights.updateAll((_, v) => v / wSum);
        }

        double dH = master.hueDeg;
        double dS = master.satPercent;
        double dL = master.lightPercent;

        for (final e in weights.entries) {
          final adj = p.bands[e.key] ?? const HslBandAdjust();
          dH += adj.hueDeg * e.value;
          dS += adj.satPercent * e.value;
          dL += adj.lightPercent * e.value;
        }

        hsl.h = _wrapDegLocal(hsl.h + dH);
        hsl.s = _clamp01(hsl.s + dS / 100.0);
        hsl.l = _clamp01(hsl.l + dL / 100.0);
      }

      final rgb = _hslToRgb(hsl.h, hsl.s, hsl.l);

      rgba[i]     = (rgb.r * 255.0).round().clamp(0, 255);
      rgba[i + 1] = (rgb.g * 255.0).round().clamp(0, 255);
      rgba[i + 2] = (rgb.b * 255.0).round().clamp(0, 255);
      // alpha 原样保留
      rgba[i + 3] = (a * 255.0).round().clamp(0, 255);
    }
  }

  /// 三角权重：中心<=30°权重1；30°~(30+feather)线性衰减到0
  static double _weight(double distDeg, double featherDeg) {
    const core = 60.0;
    final half = core / 2.0;          // 30°
    final maxR = half + featherDeg;   // 30°+羽化
    if (distDeg >= maxR) return 0.0;
    if (distDeg <= half) return 1.0;
    final t = (distDeg - half) / (maxR - half);
    return 1.0 - t;
  }

  // 在 class HslEngine 里补一个公开入口，与 VibranceEngine 对齐
  static void applyToRgbaInPlace(
      Uint8List rgba, int width, int height, HslParams params,
      ) {
    _applyToRgbaInPlace(rgba, width, height, params); // 直接转调你已有的私有实现
  }

}

/// ========== 工具区（放同文件，避免私有函数跨文件不可见） ==========
double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double _wrapDegLocal(double d) {
  d %= 360;
  return d < 0 ? d + 360 : d;
}

double _circularDistDeg(double a, double b) {
  final da = (_wrapDegLocal(a) - _wrapDegLocal(b)).abs();
  return math.min(da, 360 - da);
}

class _RGB { final double r,g,b; const _RGB(this.r,this.g,this.b); }
class _HSL { double h,s,l; _HSL(this.h,this.s,this.l); }

_HSL _rgbToHsl(double r, double g, double b) {
  final maxv = math.max(r, math.max(g, b));
  final minv = math.min(r, math.min(g, b));
  final l = (maxv + minv) * 0.5;

  double h = 0.0, s = 0.0;
  if (maxv != minv) {
    final d = maxv - minv;
    s = l > 0.5 ? d / (2 - maxv - minv) : d / (maxv + minv);
    if (maxv == r)      h = ((g - b) / d + (g < b ? 6 : 0)) * 60.0;
    else if (maxv == g) h = ((b - r) / d + 2) * 60.0;
    else                h = ((r - g) / d + 4) * 60.0;
  }
  return _HSL(_wrapDegLocal(h), _clamp01(s), _clamp01(l));
}

double _hue2rgb(double p, double q, double t) {
  if (t < 0) t += 1;
  if (t > 1) t -= 1;
  if (t < 1/6) return p + (q - p) * 6 * t;
  if (t < 1/2) return q;
  if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
  return p;
}

_RGB _hslToRgb(double hDeg, double s, double l) {
  final h = (hDeg % 360) / 360.0;
  if (s == 0) return _RGB(l, l, l);
  final q = l < 0.5 ? l * (1 + s) : (l + s - l * s);
  final p = 2 * l - q;
  final r = _hue2rgb(p, q, h + 1/3);
  final g = _hue2rgb(p, q, h);
  final b = _hue2rgb(p, q, h - 1/3);
  return _RGB(r, g, b);
}
