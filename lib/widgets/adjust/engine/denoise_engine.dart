// lib/widgets/adjust/engine/denoise_engine.dart
import 'dart:math' as math;
import 'dart:typed_data';

import '../params/denoise_params.dart';

class DenoiseEngine {
  static void applyToRgbaInPlace(
      Uint8List rgba,
      int w,
      int h,
      DenoiseParams p,
      ) {
    if (p.isNeutral) return;

    switch (p.mode) {
      case DenoiseMode.bilateral:
        _guidedBilateralLike(rgba, w, h, p, forNlm: false);
        break;
      case DenoiseMode.nlmLite:
        _guidedBilateralLike(rgba, w, h, p, forNlm: true);
        break;
      case DenoiseMode.wavelet:
        _waveletSoftYCbCr(rgba, w, h, p);
        break;
      case DenoiseMode.median:
        _medianSeparableY(rgba, w, h, radius: p.radius, strength: p.strength);
        break;
    }
  }

  /* ---------------- 基础工具 ---------------- */

  static int _ofs(int x, int y, int w) => ((y * w + x) << 2);

  static void _rgb2ycbcr(double r, double g, double b, List<double> out) {
    final y = 0.299 * r + 0.587 * g + 0.114 * b;
    final cb = -0.168736 * r - 0.331264 * g + 0.5 * b + 128.0;
    final cr = 0.5 * r - 0.418688 * g - 0.081312 * b + 128.0;
    out[0] = y;
    out[1] = cb;
    out[2] = cr;
  }

  static void _ycbcr2rgb(double y, double cb, double cr, List<double> out) {
    final cbb = cb - 128.0;
    final crr = cr - 128.0;
    double r = y + 1.402 * crr;
    double g = y - 0.344136 * cbb - 0.714136 * crr;
    double b = y + 1.772 * cbb;
    if (r < 0) r = 0; else if (r > 255) r = 255;
    if (g < 0) g = 0; else if (g > 255) g = 255;
    if (b < 0) b = 0; else if (b > 255) b = 255;
    out[0] = r; out[1] = g; out[2] = b;
  }

  static _YCbCrPlanes _toYCbCrPlanes(Uint8List rgba, int w, int h) {
    final Y = Float32List(w * h);
    final Cb = Float32List(w * h);
    final Cr = Float32List(w * h);
    final buf = List<double>.filled(3, 0.0);
    for (int y = 0; y < h; y++) {
      final row = y * w;
      for (int x = 0; x < w; x++) {
        final i = ((row + x) << 2);
        _rgb2ycbcr(
          rgba[i].toDouble(),
          rgba[i + 1].toDouble(),
          rgba[i + 2].toDouble(),
          buf,
        );
        final k = row + x;
        Y[k] = buf[0];
        Cb[k] = buf[1];
        Cr[k] = buf[2];
      }
    }
    return _YCbCrPlanes(Y, Cb, Cr);
  }

  static void _writeRgbFromYCbCr(
      Uint8List rgba,
      Float32List Y,
      Float32List Cb,
      Float32List Cr,
      int w,
      int h,
      ) {
    final buf = List<double>.filled(3, 0.0);
    for (int y = 0; y < h; y++) {
      final row = y * w;
      for (int x = 0; x < w; x++) {
        final k = row + x;
        _ycbcr2rgb(Y[k], Cb[k], Cr[k], buf);
        final i = (k << 2);
        rgba[i]     = buf[0].toInt();
        rgba[i + 1] = buf[1].toInt();
        rgba[i + 2] = buf[2].toInt();
      }
    }
  }

  /* ---------------- 盒滤波：O(N) 两趟滑动窗口 ---------------- */

  static void _boxFilter(
      Float32List src,
      Float32List dst,
      int w,
      int h,
      int r,
      Float32List tmp, // 长度 w*h
      ) {
    // 横向
    for (int y = 0; y < h; y++) {
      final base = y * w;
      double sum = src[base] * (r + 1);
      for (int i = 1; i <= r; i++) {
        final x = i < w ? i : (w - 1);
        sum += src[base + x];
      }
      for (int x = 0; x < w; x++) {
        tmp[base + x] = sum;
        final addIdx = x + r + 1;
        final subIdx = x - r;
        final add = src[base + (addIdx < w ? addIdx : (w - 1))];
        final sub = src[base + (subIdx >= 0 ? subIdx : 0)];
        sum += add - sub;
      }
    }
    // 纵向
    for (int x = 0; x < w; x++) {
      double sum = tmp[x] * (r + 1);
      for (int i = 1; i <= r; i++) {
        final y = i < h ? i : (h - 1);
        sum += tmp[y * w + x];
      }
      for (int y = 0; y < h; y++) {
        dst[y * w + x] = sum;
        final addIdx = y + r + 1;
        final subIdx = y - r;
        final add = tmp[(addIdx < h ? addIdx : (h - 1)) * w + x];
        final sub = tmp[(subIdx >= 0 ? subIdx : 0) * w + x];
        sum += add - sub;
      }
    }
  }

  /* ---------------- Guided Filter（灰度） ---------------- */

  static void _guidedFilterGray(
      Float32List I, // 引导 == 输入
      int w,
      int h, {
        required int radius,
        required double eps,   // 建议 0.002~0.2 (数值针对 0..255 标度)
        required double mix,   // 0..1，输出 = (1-mix)*I + mix*q
      }) {
    // 准备
    final N = Float32List(w * h);
    final ones = Float32List(w * h);
    for (int i = 0; i < ones.length; i++) ones[i] = 1.0;

    final tmp = Float32List(w * h);
    _boxFilter(ones, N, w, h, radius, tmp); // 每个像素窗口内像素数

    final meanI = Float32List(w * h);
    _boxFilter(I, meanI, w, h, radius, tmp);
    for (int i = 0; i < meanI.length; i++) {
      meanI[i] = meanI[i] / (N[i] + 1e-9);
    }

    final II = Float32List(w * h);
    for (int i = 0; i < II.length; i++) {
      final v = I[i];
      II[i] = v * v;
    }
    final corrI = Float32List(w * h);
    _boxFilter(II, corrI, w, h, radius, tmp);
    for (int i = 0; i < corrI.length; i++) {
      corrI[i] = corrI[i] / (N[i] + 1e-9);
    }

    // varI 与 covIp（p=I）
    final varI = Float32List(w * h);
    for (int i = 0; i < varI.length; i++) {
      final m = meanI[i];
      varI[i] = corrI[i] - m * m;
    }

    final a = Float32List(w * h);
    final b = Float32List(w * h);
    for (int i = 0; i < a.length; i++) {
      final vi = varI[i];
      final mi = meanI[i];
      final ai = vi / (vi + eps);
      a[i] = ai;
      b[i] = mi * (1.0 - ai);
    }

    final meana = Float32List(w * h);
    final meanb = Float32List(w * h);
    _boxFilter(a, meana, w, h, radius, tmp);
    _boxFilter(b, meanb, w, h, radius, tmp);
    for (int i = 0; i < meana.length; i++) {
      meana[i] = meana[i] / (N[i] + 1e-9);
      meanb[i] = meanb[i] / (N[i] + 1e-9);
    }

    // q = meana * I + meanb
    for (int i = 0; i < I.length; i++) {
      final q = meana[i] * I[i] + meanb[i];
      I[i] = I[i] * (1.0 - mix) + q * mix;
    }
  }

  /* --------- Bilateral / NLM-Lite：两套参数映射到 Guided Filter ---------- */

  static void _guidedBilateralLike(
      Uint8List rgba,
      int w,
      int h,
      DenoiseParams p, {
        required bool forNlm, // true: 更强平滑，半径更大、eps 更小
      }) {
    final planes = _toYCbCrPlanes(rgba, w, h);
    final Y = planes.Y, Cb = planes.Cb, Cr = planes.Cr;

    // 半径：UI 的 1/2/3 → 3/5/7 或 5/7/9（NLM）
    final rBase = (p.radius.clamp(1, 3));
    final radius = forNlm ? (rBase * 2 + 3) : (rBase * 2 + 1);

    // 混合强度（0..1）
    final mix = (p.strength.clamp(0, 100)) / 100.0;

    // eps：边越大越保边（eps 越小）；同时强度越大 eps 略增，避免塑料感
    final edgeKeep = p.edge.clamp(0, 100);
    final eps = (forNlm
        ? 0.002 + (100.0 - edgeKeep) * 0.0010  // NLM-Lite：更细腻
        : 0.005 + (100.0 - edgeKeep) * 0.0015) // Bilateral-like
        * (1.0 + mix * 0.6) * 255.0 * 255.0;

    _guidedFilterGray(Y, w, h, radius: radius, eps: eps, mix: mix);

    // 彩色噪点：对 Cb/Cr 轻量高斯
    final rc = math.max(1, p.radius - 1);
    if (p.chroma > 0 && rc > 0) {
      final sigma = 0.6 + p.chroma * 0.02;
      _gaussSeparable(Cb, w, h, rc, sigma);
      _gaussSeparable(Cr, w, h, rc, sigma);
    }

    _writeRgbFromYCbCr(rgba, Y, Cb, Cr, w, h);
  }

  /* ---------------- 2) Wavelet（Haar，1 层软阈值） ---------------- */

  static void _waveletSoftYCbCr(Uint8List rgba, int w, int h, DenoiseParams p) {
    if (w < 2 || h < 2) return;

    final planes = _toYCbCrPlanes(rgba, w, h);
    final Y = planes.Y, Cb = planes.Cb, Cr = planes.Cr;

    // 行/列缓冲
    final row = Float32List(w);
    final col = Float32List(h);

    void forward1D(Float32List a, int n) {
      if (n < 2) return;
      final m = (n & 1) == 1 ? n - 1 : n;
      final t = Float32List(m);
      int j = 0;
      for (int i = 0; i < m; i += 2) {
        final s = (a[i] + a[i + 1]) * 0.5;
        final d = (a[i] - a[i + 1]) * 0.5;
        t[j] = s;
        t[j + (m >> 1)] = d;
        j++;
      }
      for (int i = 0; i < m; i++) a[i] = t[i];
    }

    void inverse1D(Float32List a, int n) {
      if (n < 2) return;
      final m = (n & 1) == 1 ? n - 1 : n;
      final t = Float32List(m);
      int k = 0;
      for (int i = 0; i < (m >> 1); i++) {
        final s = a[i];
        final d = a[i + (m >> 1)];
        t[k++] = s + d;
        t[k++] = s - d;
      }
      for (int i = 0; i < m; i++) a[i] = t[i];
    }

    // 行
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) row[x] = Y[y * w + x];
      forward1D(row, w);
      for (int x = 0; x < w; x++) Y[y * w + x] = row[x];
    }
    // 列
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) col[y] = Y[y * w + x];
      forward1D(col, h);
      for (int y = 0; y < h; y++) Y[y * w + x] = col[y];
    }

    // 高频软阈值
    final T = 2.0 + p.strength * 0.6; // 2..62
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final inLL = (x < (w >> 1)) && (y < (h >> 1));
        if (inLL) continue;
        final k = y * w + x;
        final v = Y[k];
        final sgn = v < 0 ? -1.0 : 1.0;
        final mag = v.abs();
        Y[k] = (mag <= T) ? 0.0 : (mag - T) * sgn;
      }
    }

    // 逆变换：列 → 行
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) col[y] = Y[y * w + x];
      inverse1D(col, h);
      for (int y = 0; y < h; y++) Y[y * w + x] = col[y];
    }
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) row[x] = Y[y * w + x];
      inverse1D(row, w);
      for (int x = 0; x < w; x++) Y[y * w + x] = row[x];
    }

    // 彩噪
    final rc = math.max(1, p.radius - 1);
    if (p.chroma > 0 && rc > 0) {
      final sigma = 0.6 + p.chroma * 0.02;
      _gaussSeparable(Cb, w, h, rc, sigma);
      _gaussSeparable(Cr, w, h, rc, sigma);
    }

    // 轻混合，避免过度平滑
    final mix = (p.strength.clamp(0, 100)) / 100.0;
    if (mix < 1.0) {
      final Yorig = Float32List.fromList(Y);
      for (int i = 0; i < Y.length; i++) {
        Y[i] = Yorig[i] * (1.0 - mix) + Y[i] * mix;
      }
    }

    _writeRgbFromYCbCr(rgba, Y, Cb, Cr, w, h);
  }

  /* ---------------- 3) 高斯可分离（给 Cb/Cr） ---------------- */

  static void _gaussSeparable(
      Float32List src,
      int w,
      int h,
      int radius,
      double sigma,
      ) {
    if (radius <= 0) return;
    final kSize = 2 * radius + 1;
    final k = Float32List(kSize);
    double sum = 0.0;
    final den = 2.0 * sigma * sigma;
    for (int i = -radius; i <= radius; i++) {
      final v = math.exp(-(i * i) / den);
      k[i + radius] = v;
      sum += v;
    }
    for (int i = 0; i < kSize; i++) k[i] /= sum;

    final tmp = Float32List(w * h);

    // 横向
    for (int y = 0; y < h; y++) {
      final base = y * w;
      for (int x = 0; x < w; x++) {
        double v = 0.0;
        for (int i = -radius; i <= radius; i++) {
          final xx = x + i;
          final cx = (xx < 0) ? 0 : (xx >= w ? (w - 1) : xx);
          v += src[base + cx] * k[i + radius];
        }
        tmp[base + x] = v;
      }
    }
    // 纵向
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        double v = 0.0;
        for (int i = -radius; i <= radius; i++) {
          final yy = y + i;
          final cy = (yy < 0) ? 0 : (yy >= h ? (h - 1) : yy);
          v += tmp[cy * w + x] * k[i + radius];
        }
        src[y * w + x] = v;
      }
    }
  }

  /* ---------------- 4) Median（分离式近似，滑动直方图） ---------------- */

  static void _medianSeparableY(
      Uint8List rgba,
      int w,
      int h, {
        required int radius, // 1..3
        required double strength, // 0..100
      }) {
    final r = radius.clamp(1, 3);
    final mix = (strength.clamp(0, 100)) / 100.0;

    // 转 Y/Cb/Cr
    final planes = _toYCbCrPlanes(rgba, w, h);
    final Y = planes.Y, Cb = planes.Cb, Cr = planes.Cr;

    // 先把 Y 量化到 [0..255]，行中值 → 列中值
    final y8 = Uint8List(w * h);
    for (int i = 0; i < y8.length; i++) {
      double v = Y[i];
      if (v < 0) v = 0; else if (v > 255) v = 255;
      y8[i] = v.toInt();
    }

    final rowOut = Uint8List(w * h);
    _median1DRow(y8, rowOut, w, h, r);
    final colOut = Uint8List(w * h);
    _median1DCol(rowOut, colOut, w, h, r);

    // 混合回浮点 Y
    for (int i = 0; i < Y.length; i++) {
      final fy = colOut[i].toDouble();
      Y[i] = Y[i] * (1.0 - mix) + fy * mix;
    }

    // 彩噪略降
    if (r > 0) {
      final sigma = 0.5 + 0.02 * strength;
      _gaussSeparable(Cb, w, h, math.max(1, r - 1), sigma);
      _gaussSeparable(Cr, w, h, math.max(1, r - 1), sigma);
    }

    _writeRgbFromYCbCr(rgba, Y, Cb, Cr, w, h);
  }

  static void _median1DRow(
      Uint8List src,
      Uint8List dst,
      int w,
      int h,
      int r,
      ) {
    final win = 2 * r + 1;
    final half = (win * 1 + 1) >> 1;

    for (int y = 0; y < h; y++) {
      final base = y * w;
      final hist = Uint32List(256);
      int m = 0;          // 当前中位索引
      int acc = 0;        // 累计直方图 <= m 的计数

      // 初始化窗口（x=0）
      for (int dx = -r; dx <= r; dx++) {
        int xx = dx;
        if (xx < 0) xx = 0;
        if (xx >= w) xx = w - 1;
        hist[src[base + xx]]++;
      }
      // 找到初始中位
      while (acc < half) {
        acc += hist[m++];
      }
      m--; // 回到第一个使累计>=half 的 bin

      // 写第一个
      dst[base + 0] = m;

      // 滑动
      for (int x = 1; x < w; x++) {
        final addX = x + r;
        final subX = x - r - 1;
        final addVal = src[base + (addX < w ? addX : (w - 1))];
        final subVal = src[base + (subX >= 0 ? subX : 0)];

        hist[addVal]++;
        hist[subVal]--;

        if (addVal <= m) acc++;
        if (subVal <= m) acc--;

        // 向右或向左微调 m
        while (acc < half) { m++; acc += hist[m]; }
        while (acc - hist[m] >= half) { acc -= hist[m]; m--; }

        dst[base + x] = m;
      }
    }
  }

  static void _median1DCol(
      Uint8List src,
      Uint8List dst,
      int w,
      int h,
      int r,
      ) {
    final win = 2 * r + 1;
    final half = (win * 1 + 1) >> 1;

    for (int x = 0; x < w; x++) {
      final hist = Uint32List(256);
      int m = 0;
      int acc = 0;

      // 初始窗口（y=0）
      for (int dy = -r; dy <= r; dy++) {
        int yy = dy;
        if (yy < 0) yy = 0;
        if (yy >= h) yy = h - 1;
        hist[src[yy * w + x]]++;
      }
      while (acc < half) {
        acc += hist[m++];
      }
      m--;

      dst[0 * w + x] = m;

      for (int y = 1; y < h; y++) {
        final addY = y + r;
        final subY = y - r - 1;
        final addVal = src[(addY < h ? addY : (h - 1)) * w + x];
        final subVal = src[(subY >= 0 ? subY : 0) * w + x];

        hist[addVal]++;
        hist[subVal]--;

        if (addVal <= m) acc++;
        if (subVal <= m) acc--;

        while (acc < half) { m++; acc += hist[m]; }
        while (acc - hist[m] >= half) { acc -= hist[m]; m--; }

        dst[y * w + x] = m;
      }
    }
  }
}

class _YCbCrPlanes {
  _YCbCrPlanes(this.Y, this.Cb, this.Cr);
  final Float32List Y, Cb, Cr;
}
