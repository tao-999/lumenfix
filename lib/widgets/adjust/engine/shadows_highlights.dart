// lib/widgets/adjust/engine/shadows_highlights.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../params/shadows_highlights_params.dart';

/// 阴影/高光 引擎（新版参数）
/// - shAmount / hiAmount: -100..100（强度）
/// - shTone / hiTone: 0..100（覆盖宽度；越大越“宽”）
/// - shRadius / hiRadius: 0..200 px（空间半径；用于计算局部亮度 L 的邻域平滑）
/// - color: -100..100（饱和度微调）
/// 核心：按半径对亮度做可分离盒滤波，得到局部亮度 Ls/Lh，再用 Tone 生成权重，按强度回拉，最后按亮度比例缩放 RGB。
class ShadowsHighlightsEngine {
  /// 直接处理 ui.Image
  static Future<ui.Image> applyToImage(
      ui.Image src,
      ShadowsHighlightsParams p,
      ) async {
    final w = src.width, h = src.height;
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = bd!.buffer.asUint8List();

    applyToRgbaInPlace(bytes, w, h, p);

    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  /// 原地处理 RGBA（需要提供宽高以做卷积）
  static void applyToRgbaInPlace(
      Uint8List rgba,
      int width,
      int height,
      ShadowsHighlightsParams p,
      ) {
    final n = width * height;

    // 亮度（原始）
    final luma = Float32List(n);
    for (int i = 0, pi = 0; i < n; i++, pi += 4) {
      final r = rgba[pi].toDouble();
      final g = rgba[pi + 1].toDouble();
      final b = rgba[pi + 2].toDouble();
      luma[i] = (0.2126 * r + 0.7152 * g + 0.0722 * b);
    }

    // 阴影/高光分别用各自半径做局部亮度（盒滤波近似高斯）
    final rs = p.shRadius.clamp(0, 200).round();
    final rh = p.hiRadius.clamp(0, 200).round();

    final lumaShadow = (rs > 0) ? _boxBlurGray(luma, width, height, rs) : luma;
    final lumaHigh   = (rh > 0) ? _boxBlurGray(luma, width, height, rh) : luma;

    // Tone -> 覆盖宽度
    double mapToneShadow(double t) => (0.20 + (t / 100.0) * 0.35); // 0.20..0.55
    double mapToneHighlight(double t) => (0.20 + (t / 100.0) * 0.35);

    final toneWShadow = mapToneShadow(p.shTone);
    final toneWHigh   = mapToneHighlight(p.hiTone);

    double smoothstep(double a, double b, double x) {
      final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    // 强度 & 饱和度
    final sAmt = (p.shAmount / 100.0).clamp(-1.0, 1.0);
    final hAmt = (p.hiAmount / 100.0).clamp(-1.0, 1.0);
    final satK = (1.0 + p.color / 100.0).clamp(0.0, 3.0);

    // 阴影/高光中心（固定在 0.25 / 0.75）
    const cs = 0.25; // 阴影中心
    const ch = 0.75; // 高光中心

    // 逐像素处理
    for (int i = 0, pi = 0; i < n; i++, pi += 4) {
      double r = rgba[pi].toDouble();
      double g = rgba[pi + 1].toDouble();
      double b = rgba[pi + 2].toDouble();

      final L0 = luma[i];
      final LnS = (lumaShadow[i] / 255.0).clamp(0.0, 1.0);
      final LnH = (lumaHigh[i] / 255.0).clamp(0.0, 1.0);

      // 权重：阴影在暗部大，高光在亮部大
      final ws = (1.0 - smoothstep(cs, cs + toneWShadow, LnS));
      final wh = smoothstep(ch - toneWHigh, ch, LnH);

      // 回拉
      double L = L0;
      if (sAmt >= 0) {
        L = L + sAmt * ws * (255.0 - L);
      } else {
        L = L + sAmt * ws * L;
      }
      final mid = 128.0;
      L = L - hAmt * wh * (L - mid);
      L = L.clamp(0.0, 255.0);

      // 按亮度比例缩放 RGB（保持色相）
      final scale = L / (L0 + 1e-6);
      r *= scale;
      g *= scale;
      b *= scale;

      // 饱和度微调：和 L 做插值
      r = L + (r - L) * satK;
      g = L + (g - L) * satK;
      b = L + (b - L) * satK;

      rgba[pi]     = r.round().clamp(0, 255);
      rgba[pi + 1] = g.round().clamp(0, 255);
      rgba[pi + 2] = b.round().clamp(0, 255);
    }
  }

  /// 可分离盒滤波（半径 r），两次盒滤近似高斯足够预览
  static Float32List _boxBlurGray(Float32List src, int w, int h, int r) {
    if (r <= 0) return src;
    final tmp = Float32List(w * h);
    final dst = Float32List(w * h);

    // 横向滑窗
    final win = 2 * r + 1;
    for (int y = 0; y < h; y++) {
      int base = y * w;
      double sum = 0;
      for (int x = -r; x <= r; x++) {
        final xx = x.clamp(0, w - 1);
        sum += src[base + xx];
      }
      for (int x = 0; x < w; x++) {
        tmp[base + x] = (sum / win);
        final xAdd = (x + r + 1).clamp(0, w - 1);
        final xSub = (x - r).clamp(0, w - 1);
        sum += src[base + xAdd] - src[base + xSub];
      }
    }

    // 纵向滑窗
    for (int x = 0; x < w; x++) {
      double sum = 0;
      for (int y = -r; y <= r; y++) {
        final yy = y.clamp(0, h - 1);
        sum += tmp[yy * w + x];
      }
      for (int y = 0; y < h; y++) {
        dst[y * w + x] = (sum / win);
        final yAdd = (y + r + 1).clamp(0, h - 1);
        final ySub = (y - r).clamp(0, h - 1);
        sum += tmp[yAdd * w + x] - tmp[ySub * w + x];
      }
    }
    return dst;
  }
}
