// lib/widgets/adjust/engine/ops_detail_texture_sharpen_denoise.dart
part of 'adjust_engine.dart';

void opTexture(img.Image im, double amount) {
  if (amount == 0) return;
  final low = img.gaussianBlur(img.Image.from(im), radius: 5);
  final k = (amount / 100.0) * 0.5;
  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++) {
      final p0 = im.getPixel(x, y), pl = low.getPixel(x, y);
      num r = p0.r + k * (p0.r - pl.r),
          g = p0.g + k * (p0.g - pl.g),
          b = p0.b + k * (p0.b - pl.b);
      p0..r = _clamp255(r)..g = _clamp255(g)..b = _clamp255(b);
    }
  }
}

void opClarity(img.Image im, double clarity) {
  if (clarity == 0) return;
  final low = img.gaussianBlur(img.Image.from(im), radius: 3);
  final k = (clarity / 100.0) * 0.6;
  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++) {
      final p0 = im.getPixel(x, y), pl = low.getPixel(x, y);
      num r = p0.r + k * (p0.r - pl.r),
          g = p0.g + k * (p0.g - pl.g),
          b = p0.b + k * (p0.b - pl.b);
      p0..r = _clamp255(r)..g = _clamp255(g)..b = _clamp255(b);
    }
  }
}

void opUsm(img.Image im, Usm usm, double legacySharp) {
  final double amount = usm.isNeutral ? (legacySharp / 100.0) * 0.8 : (usm.amount / 100.0);
  if (amount <= 0) return;
  final int rad = (usm.isNeutral ? 1.0 : usm.radius).clamp(0.5, 6.0).round().clamp(1, 999);
  final int thr = (usm.isNeutral ? 0 : usm.threshold).clamp(0.0, 255.0).round();

  final img.Image low = img.gaussianBlur(img.Image.from(im), radius: rad);
  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++) {
      final p0 = im.getPixel(x, y);
      final pL = low.getPixel(x, y);
      final num dr = (p0.r - pL.r).abs(),
          dg = (p0.g - pL.g).abs(),
          db = (p0.b - pL.b).abs();
      if (thr > 0 && dr < thr && dg < thr && db < thr) continue;
      p0
        ..r = _clamp255(p0.r + amount * (p0.r - pL.r)).round()
        ..g = _clamp255(p0.g + amount * (p0.g - pL.g)).round()
        ..b = _clamp255(p0.b + amount * (p0.b - pL.b)).round();
    }
  }
}

void opDenoise(img.Image im, double legacy, DenoiseAdv adv) {
  final double lumaK   = adv.luma == 0 ? (legacy / 100.0) * 0.3 : (adv.luma / 100.0);
  final double chromaK = (adv.chroma / 100.0);
  if (lumaK <= 0 && chromaK <= 0 && legacy <= 0) return;

  if (lumaK > 0) {
    final int lumaRad = (lumaK * 3).clamp(0.0, 3.0).round();
    if (lumaRad > 0) {
      final sm = img.gaussianBlur(img.Image.from(im), radius: lumaRad);
      for (int y = 0; y < im.height; y++) {
        for (int x = 0; x < im.width; x++) {
          final p = im.getPixel(x, y), s = sm.getPixel(x, y);
          p
            ..r = (p.r * (1 - lumaK) + s.r * lumaK).round().clamp(0, 255)
            ..g = (p.g * (1 - lumaK) + s.g * lumaK).round().clamp(0, 255)
            ..b = (p.b * (1 - lumaK) + s.b * lumaK).round().clamp(0, 255);
        }
      }
    }
  }

  if (chromaK > 0) {
    final int chromaRad = (chromaK * 5).clamp(1.0, 6.0).round();
    final sm = img.gaussianBlur(img.Image.from(im), radius: chromaRad);
    for (int y = 0; y < im.height; y++) {
      for (int x = 0; x < im.width; x++) {
        final p = im.getPixel(x, y);
        final s = sm.getPixel(x, y);
        final double Y  = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        final double Ys = 0.299 * s.r + 0.587 * s.g + 0.114 * s.b;
        final double Cb = 0.564 * (s.b - Ys);
        final double Cr = 0.713 * (s.r - Ys);
        double r1 = (Y + 1.403 * Cr);
        double g1 = (Y - 0.344 * Cb - 0.714 * Cr);
        double b1 = (Y + 1.773 * Cb);
        r1 = (p.r * (1 - chromaK) + r1 * chromaK).clamp(0.0, 255.0);
        g1 = (p.g * (1 - chromaK) + g1 * chromaK).clamp(0.0, 255.0);
        b1 = (p.b * (1 - chromaK) + b1 * chromaK).clamp(0.0, 255.0);
        p..r = r1.round()..g = g1.round()..b = b1.round();
      }
    }
  }
}
