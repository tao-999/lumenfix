// lib/widgets/adjust/engine/ops_fx_bloom_vignette_grain.dart
part of 'adjust_engine.dart';

void opBloom(img.Image im, Bloom b) {
  if (b.isNeutral) return;
  final double th = b.threshold.clamp(0.0, 1.0);
  final int rad = b.radius.clamp(1, 80).round();
  final double k = (b.intensity / 100.0).clamp(0.0, 2.0);

  final mask = List<double>.filled(im.width * im.height, 0.0, growable: false);
  int idx = 0;
  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++, idx++) {
      final p = im.getPixel(x, y);
      final l = (0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b) / 255.0;
      mask[idx] = ((l - th) / (1.0 - th)).clamp(0.0, 1.0);
    }
  }

  final bright = img.Image.from(im);
  idx = 0;
  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++, idx++) {
      final m = mask[idx];
      if (m <= 0) {
        bright.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        final p = im.getPixel(x, y);
        bright.setPixelRgba(x, y, (p.r * m).round(), (p.g * m).round(), (p.b * m).round(), p.a);
      }
    }
  }
  final glow = img.gaussianBlur(bright, radius: rad);

  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++) {
      final p = im.getPixel(x, y), g = glow.getPixel(x, y);
      p
        ..r = (p.r + k * g.r).clamp(0, 255)
        ..g = (p.g + k * g.g).clamp(0, 255)
        ..b = (p.b + k * g.b).clamp(0, 255);
    }
  }
}

void opVignette(img.Image im, Vignette v) {
  if (v.isNeutral) return;
  final cx = (im.width - 1) / 2.0 + v.cx * im.width * 0.25;
  final cy = (im.height - 1) / 2.0 + v.cy * im.height * 0.25;
  final rx = v.radius * im.width / 2.0;
  final ry = v.radius * im.height / 2.0 * (1.0 - v.roundness * 0.5);
  final feather = (v.feather.clamp(0.01, 1.0)) * 0.5;
  final k = (v.amount / 100.0).clamp(-1.0, 1.0);

  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++) {
      final dx = (x - cx) / rx, dy = (y - cy) / ry;
      final d = math.sqrt(dx * dx + dy * dy);
      final t = ((d - (1 - feather)) / feather).clamp(0.0, 1.0);
      final f = 1.0 - k * t;
      final p = im.getPixel(x, y);
      p
        ..r = (p.r * f).clamp(0, 255).round()
        ..g = (p.g * f).clamp(0, 255).round()
        ..b = (p.b * f).clamp(0, 255).round();
    }
  }
}

void opGrain(img.Image im, Grain g) {
  if (g.isNeutral) return;
  final rnd = math.Random(1337);
  final k = (g.amount / 100.0).clamp(0.0, 1.0);
  final size = g.size.clamp(0.5, 8.0);

  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++) {
      final _ = (x / size).floor() ^ (y / size).floor(); // decorrelate
      rnd.nextDouble();
      final n = (rnd.nextDouble() * 2 - 1) * (0.6 + 0.4 * g.roughness);
      final p = im.getPixel(x, y);
      p
        ..r = (p.r + n * 30 * k).clamp(0, 255).round()
        ..g = (p.g + n * 30 * k).clamp(0, 255).round()
        ..b = (p.b + n * 30 * k).clamp(0, 255).round();
    }
  }
}
