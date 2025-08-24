// lib/services/whiten_service.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 自然美白 v2（更克制：高光保护 + 限制最大提亮 + 温和去红黄）
/// - strength: 0..1（默认 0.55；建议 0.45~0.65）
/// - 单次遍历，极快
class WhitenService {
  static Future<Uint8List> whiten(
      Uint8List src, {
        double strength = 0.55,
        int jpegQuality = 95,
      }) {
    strength = strength.clamp(0.0, 1.0);
    return compute<_Args, Uint8List>(
      _whitenIsolate,
      _Args(src, strength, jpegQuality),
    );
  }
}

class _Args {
  final Uint8List src;
  final double s;
  final int q;
  const _Args(this.src, this.s, this.q);
}

Uint8List _whitenIsolate(_Args a) {
  final im0 = img.decodeImage(a.src);
  if (im0 == null) throw StateError('Unsupported image format');
  final im = img.bakeOrientation(im0);

  final data = im.data;
  if (data == null || data.palette != null || data.format != img.Format.uint8) {
    _whitenSlow(im, a.s);
    return Uint8List.fromList(img.encodeJpg(im, quality: a.q));
  }

  final bytes = data.toUint8List();
  final stride = data.rowStride;
  final ch = data.numChannels;
  final w = im.width, h = im.height;
  if (ch < 3) {
    _whitenSlow(im, a.s);
    return Uint8List.fromList(img.encodeJpg(im, quality: a.q));
  }

  // 皮肤检测（BT.601）的软区间
  const int CbMin = 77,  CbMax = 127;
  const int CrMin = 133, CrMax = 173;
  const int YMin  = 40,  YMax  = 245; // 放宽上界，避免极亮区误判

  double tri(int x, int lo, int hi, int fall) {
    if (x < lo - fall || x > hi + fall) return 0.0;
    if (x >= lo && x <= hi) return 1.0;
    if (x < lo) {
      final t = (x - (lo - fall)) / fall;
      return t < 0 ? 0 : (t > 1 ? 1 : t);
    } else {
      final t = ((hi + fall) - x) / fall;
      return t < 0 ? 0 : (t > 1 ? 1 : t);
    }
  }

  // 参数：更保守的一组
  const int MAX_Y_TARGET = 235;         // 高光上限（强保护）
  const int MAX_LIFT_CAP = 60;          // 单像素最大提亮
  const int HIGHLIGHT_START = 185;      // 从偏亮开始衰减力度
  const int HIGHLIGHT_FULL = 255;       // 到纯亮基本 0 力度
  const double CbReduce = 0.25;         // Cb 回中性系数（温和）
  const double CrReduce = 0.35;         // Cr 回中性系数（更强：去红黄）

  for (int y = 0; y < h; y++) {
    int row = y * stride;
    for (int x = 0; x < w; x++) {
      final i = row + x * ch;
      int r = bytes[i];
      int g = bytes[i + 1];
      int b = bytes[i + 2];

      // YCbCr（整数近似）
      final Y  = ((77 * r + 150 * g + 29 * b) >> 8);
      final Cb = (((-43 * r - 85 * g + 128 * b) >> 8) + 128);
      final Cr = (((128 * r - 107 * g - 21 * b) >> 8) + 128);

      // 皮肤 mask（乘积，并做一次 sqrt 软化，避免“口罩边”）
      final mCb = tri(Cb, CbMin, CbMax, 12);
      final mCr = tri(Cr, CrMin, CrMax, 12);
      final mY  = tri(Y,  YMin,  YMax,  20);
      double mask = (mCb * mCr * mY);
      mask = mask > 0 ? mathSqrt(mask) : 0; // 软化边界

      if (mask > 0) {
        // —— 自适应力度：亮区越亮，力度越小（避免过白）——
        final hiT = ((Y - HIGHLIGHT_START) / (HIGHLIGHT_FULL - HIGHLIGHT_START))
            .clamp(0.0, 1.0);
        final hiProtect = 1.0 - hiT;           // 185 开始衰减，255 接近 0
        final k = a.s * mask * hiProtect;      // 实际强度（0..~a.s）

        if (k > 0) {
          // 1) 限制最大提亮量：最多 +60，并且目标不超过 235
          final maxLift = (MAX_Y_TARGET - Y).clamp(0, MAX_LIFT_CAP);
          final Yf = (Y + maxLift * (0.6 * k)).clamp(0, MAX_Y_TARGET).toDouble();

          // 2) 去红黄（温和）：Cr/Cb 朝 128 回拉
          final Cbf = 128 + (Cb - 128) * (1.0 - CbReduce * k);
          final Crf = 128 + (Cr - 128) * (1.0 - CrReduce * k);

          // 3) 反算回 RGB（BT.601）
          double Rd = Yf + 1.402 * (Crf - 128.0);
          double Gd = Yf - 0.344136 * (Cbf - 128.0) - 0.714136 * (Crf - 128.0);
          double Bd = Yf + 1.772 * (Cbf - 128.0);

          // clamp
          r = Rd.clamp(0.0, 255.0).toInt();
          g = Gd.clamp(0.0, 255.0).toInt();
          b = Bd.clamp(0.0, 255.0).toInt();

          bytes[i] = r; bytes[i + 1] = g; bytes[i + 2] = b;
        }
      }
      // A 通道不动
    }
  }

  return Uint8List.fromList(img.encodeJpg(im, quality: a.q));
}

// 兜底慢路径：同逻辑（极少触发）
void _whitenSlow(img.Image im, double s) {
  const int MAX_Y_TARGET = 235;
  const int MAX_LIFT_CAP = 60;
  const int HIGHLIGHT_START = 185;
  const int HIGHLIGHT_FULL = 255;
  const double CbReduce = 0.25;
  const double CrReduce = 0.35;

  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++) {
      final p = im.getPixel(x, y);
      final a = p.a.toInt();
      final r0 = p.r.toInt(), g0 = p.g.toInt(), b0 = p.b.toInt();

      final Y  = ((77 * r0 + 150 * g0 + 29 * b0) >> 8);
      final Cb = (((-43 * r0 - 85 * g0 + 128 * b0) >> 8) + 128);
      final Cr = (((128 * r0 - 107 * g0 - 21 * b0) >> 8) + 128);

      double tri(int x, int lo, int hi, int fall) {
        if (x < lo - fall || x > hi + fall) return 0.0;
        if (x >= lo && x <= hi) return 1.0;
        if (x < lo) {
          final t = (x - (lo - fall)) / fall;
          return t.clamp(0.0, 1.0);
        } else {
          final t = ((hi + fall) - x) / fall;
          return t.clamp(0.0, 1.0);
        }
      }

      const int CbMin = 77, CbMax = 127, CrMin = 133, CrMax = 173, YMin = 40, YMax = 245;
      double mask = tri(Cb, CbMin, CbMax, 12) * tri(Cr, CrMin, CrMax, 12) * tri(Y, YMin, YMax, 20);
      mask = mask > 0 ? mathSqrt(mask) : 0;

      if (mask > 0) {
        final hiT = ((Y - HIGHLIGHT_START) / (HIGHLIGHT_FULL - HIGHLIGHT_START))
            .clamp(0.0, 1.0);
        final hiProtect = 1.0 - hiT;
        final k = s * mask * hiProtect;

        if (k > 0) {
          final maxLift = (MAX_Y_TARGET - Y).clamp(0, MAX_LIFT_CAP);
          final Yf = (Y + maxLift * (0.6 * k)).clamp(0, MAX_Y_TARGET).toDouble();
          final Cbf = 128 + (Cb - 128) * (1.0 - CbReduce * k);
          final Crf = 128 + (Cr - 128) * (1.0 - CrReduce * k);

          double Rd = Yf + 1.402 * (Crf - 128.0);
          double Gd = Yf - 0.344136 * (Cbf - 128.0) - 0.714136 * (Crf - 128.0);
          double Bd = Yf + 1.772 * (Cbf - 128.0);

          im.setPixelRgba(
            x, y,
            Rd.clamp(0.0, 255.0).toInt(),
            Gd.clamp(0.0, 255.0).toInt(),
            Bd.clamp(0.0, 255.0).toInt(),
            a,
          );
        }
      }
    }
  }
}

/// 小工具：不引入 dart:math 也能 sqrt（牛顿迭代 2 次够用）
double mathSqrt(double x) {
  if (x <= 0) return 0;
  double r = x < 1 ? 1.0 : x;
  r = 0.5 * (r + x / r);
  r = 0.5 * (r + x / r);
  return r;
}
