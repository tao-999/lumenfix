// lib/widgets/adjust/engine/ops_lut.dart
part of 'adjust_engine.dart';

void opLut(img.Image im, LutConfig cfg) {
  if (cfg.isNeutral) return;
  final k = cfg.strength.clamp(0.0, 1.0);
  for (final px in im) {
    num r = px.r, g = px.g, b = px.b;
    r = (r * (1 - k) + (r * 1.06) * k).clamp(0, 255);
    g = (g * (1 - k) + g * k).clamp(0, 255);
    b = (b * (1 - k) + (b * 0.94) * k).clamp(0, 255);
    px..r = r.round()..g = g.round()..b = b.round();
  }
  // TODO: 解析 .cube/.3dl + 3D LUT 采样
}
