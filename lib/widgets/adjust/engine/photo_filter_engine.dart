// lib/widgets/adjust/engine/photo_filter_engine.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../params/photo_filter_params.dart';

class PhotoFilterEngine {
  /// 直接在内存里改 RGBA（预览/导出都复用）
  static void applyToRgbaInPlace(
      Uint8List rgba, int width, int height, PhotoFilterParams p) {
    final n = width * height;
    final k = p.density.clamp(0.0, 1.0); // 0..1

    if (k == 0) return;

    // 过滤色（0..1）
    final fr = (p.color.red   / 255.0);
    final fg = (p.color.green / 255.0);
    final fb = (p.color.blue  / 255.0);

    // 预计算过滤色的 HSL（保留明度模式用）
    final _HSL fHsl = _rgb2hsl(fr, fg, fb);

    for (int i = 0, pi = 0; i < n; i++, pi += 4) {
      double r = rgba[pi]     / 255.0;
      double g = rgba[pi + 1] / 255.0;
      double b = rgba[pi + 2] / 255.0;

      if (p.preserveLum) {
        // —— 只改色相/饱和度，保留明度（近似 PS Preserve Luminosity）——
        final _HSL o = _rgb2hsl(r, g, b);

        // hue 走最近角度、sat 线性插值、lightness 原样
        final double dh = _shortestHueDelta(o.h, fHsl.h);
        final double nh = o.h + dh * k; // 插值到滤镜色相
        final double ns = o.s + (fHsl.s - o.s) * k;

        final _RGB out = _hsl2rgb(_wrap01(nh), ns.clamp(0.0, 1.0), o.l);
        r = out.r; g = out.g; b = out.b;
      } else {
        // —— 直接在 sRGB 空间里做颜色叠加 ——（简单高效）
        r = r + (fr - r) * k;
        g = g + (fg - g) * k;
        b = b + (fb - b) * k;
      }

      rgba[pi]     = (r * 255.0).round().clamp(0, 255);
      rgba[pi + 1] = (g * 255.0).round().clamp(0, 255);
      rgba[pi + 2] = (b * 255.0).round().clamp(0, 255);
      // alpha 保持不动
    }
  }

  /// 方便独立调用（和你们其他引擎风格一致）
  static Future<ui.Image> applyToImage(ui.Image src, PhotoFilterParams p) async {
    final w = src.width, h = src.height;
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = bd!.buffer.asUint8List();
    applyToRgbaInPlace(bytes, w, h, p);

    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }
}

/* ======= 小工具：HSL/RGB 转换 ======= */

class _HSL { final double h, s, l; const _HSL(this.h, this.s, this.l); }
class _RGB { final double r, g, b; const _RGB(this.r, this.g, this.b); }

double _wrap01(double x) => x - x.floorToDouble();

double _shortestHueDelta(double a, double b) {
  // a,b ∈ [0,1)
  double d = b - a;
  if (d > 0.5)  d -= 1.0;
  if (d < -0.5) d += 1.0;
  return d;
}

_HSL _rgb2hsl(double r, double g, double b) {
  final maxc = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final minc = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final l = (maxc + minc) * 0.5;
  double h = 0.0, s = 0.0;
  final d = maxc - minc;
  if (d != 0) {
    s = l > 0.5 ? d / (2.0 - maxc - minc) : d / (maxc + minc);
    if (maxc == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (maxc == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h /= 6.0; // 0..1
  }
  return _HSL(h, s, l);
}

double _hue2rgb(double p, double q, double t) {
  if (t < 0) t += 1;
  if (t > 1) t -= 1;
  if (t < 1 / 6) return p + (q - p) * 6 * t;
  if (t < 1 / 2) return q;
  if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
  return p;
}

_RGB _hsl2rgb(double h, double s, double l) {
  if (s == 0) return _RGB(l, l, l);
  final q = l < 0.5 ? l * (1 + s) : (l + s - l * s);
  final p = 2 * l - q;
  final r = _hue2rgb(p, q, h + 1 / 3);
  final g = _hue2rgb(p, q, h);
  final b = _hue2rgb(p, q, h - 1 / 3);
  return _RGB(r, g, b);
}
