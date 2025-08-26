import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../params/color_balance_params.dart';

class ColorBalanceEngine {
  static Future<ui.Image> applyToImage(ui.Image src, ColorBalanceParams p) async {
    final w = src.width, h = src.height;
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = bd!.buffer.asUint8List();
    applyToRgbaInPlace(bytes, w, h, p);

    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  /// 简化版 PS Color Balance：
  /// - 三个区域按亮度(L)权重：阴影/中间调/高光平滑过渡
  /// - 每个轮的 cr/mg/yb ∈ [-100,100] 映射到 R/G/B 的加法
  /// - preserveLuminosity: 用 Rec.709 luma 归一，尽量保持亮度
  static void applyToRgbaInPlace(
      Uint8List rgba, int width, int height, ColorBalanceParams p) {
    if (p.isNeutral) return;

    // slider 映射系数（100 -> 1.0 的加成，较猛；如需温和可改 0.5/0.75）
    const double k = 0.01;

    // 亮度权重（基于 HSL 的 L，0..1）
    double wShadow(double l) => _saturate((0.5 - l) * 2.0);           // 0..1
    double wHighlight(double l) => _saturate((l - 0.5) * 2.0);        // 0..1
    double wMid(double l) => _saturate(1.0 - (2.0 * (l - 0.5)).abs() * 2.0); // 0..1

    for (int i = 0, pi = 0; i < width * height; i++, pi += 4) {
      double r = rgba[pi] / 255.0;
      double g = rgba[pi + 1] / 255.0;
      double b = rgba[pi + 2] / 255.0;

      // —— RGB -> HSL(只取 L 做权重) —— //
      final maxc = math.max(r, math.max(g, b));
      final minc = math.min(r, math.min(g, b));
      final l = (maxc + minc) * 0.5;

      final ws = wShadow(l), wm = wMid(l), wh = wHighlight(l);

      // 三个轮叠加（线性混合）
      final cr = (p.shadows.cr * ws + p.mids.cr * wm + p.highs.cr * wh) * k;
      final mg = (p.shadows.mg * ws + p.mids.mg * wm + p.highs.mg * wh) * k;
      final yb = (p.shadows.yb * ws + p.mids.yb * wm + p.highs.yb * wh) * k;

      // Cyan-Red -> R；Magenta-Green -> G；Yellow-Blue -> B
      double r2 = _saturate(r + cr);
      double g2 = _saturate(g + mg);
      double b2 = _saturate(b + yb);

      if (p.preserveLuminosity) {
        // 用 Rec.709 luma 尽量保持亮度
        final y0 = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        final y1 = 0.2126 * r2 + 0.7152 * g2 + 0.0722 * b2;
        if (y1 > 1e-6) {
          final s = y0 / y1;
          r2 = _saturate(r2 * s);
          g2 = _saturate(g2 * s);
          b2 = _saturate(b2 * s);
        }
      }

      rgba[pi]     = (r2 * 255.0).round().clamp(0, 255);
      rgba[pi + 1] = (g2 * 255.0).round().clamp(0, 255);
      rgba[pi + 2] = (b2 * 255.0).round().clamp(0, 255);
      // alpha 不动
    }
  }

  static double _saturate(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
}
