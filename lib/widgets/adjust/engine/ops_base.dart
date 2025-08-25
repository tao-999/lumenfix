// lib/widgets/adjust/engine/ops_base.dart
part of 'adjust_engine.dart';

void opBase(img.Image im, AdjustParams p) {
  final expMul = math.pow(2.0, p.exposure).toDouble();
  final contrastK = p.contrast / 100.0;
  final satK = p.saturation / 100.0;
  final vibK = p.vibrance / 100.0;
  final tempK = p.temperature / 100.0;
  final tintK = p.tint / 100.0;
  final whitesK = p.whites / 100.0;
  final blacksK = p.blacks / 100.0;
  final highsK = p.highlights / 100.0;
  final shadowsK = p.shadows / 100.0;
  final gamma = p.gamma.clamp(0.5, 1.5);

  for (final px in im) {
    num r = px.r, g = px.g, b = px.b; final a = px.a;

    // 曝光
    r *= expMul; g *= expMul; b *= expMul;

    // 白平衡（简化比例）
    final rMul = 1.0 + 0.10 * tempK;
    final bMul = 1.0 - 0.10 * tempK;
    final gMul = 1.0 + 0.10 * tintK;
    r *= rMul; g *= gMul; b *= bMul;

    // 高光/阴影
    final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    if (shadowsK != 0) {
      final t = (1.0 - (y / 255.0)).clamp(0.0, 1.0);
      final gain = 1.0 + 0.8 * shadowsK * t;
      r *= gain; g *= gain; b *= gain;
    }
    if (highsK != 0) {
      final t = (y / 255.0).clamp(0.0, 1.0);
      final gain = 1.0 - 0.8 * highsK * t;
      r *= gain; g *= gain; b *= gain;
    }

    // 白场/黑场端点
    if (whitesK != 0) {
      final k = (1.0 + 0.5 * whitesK).clamp(0.5, 1.5);
      r = 255 - (255 - r) * k; g = 255 - (255 - g) * k; b = 255 - (255 - b) * k;
    }
    if (blacksK != 0) {
      final k = (1.0 + 0.5 * blacksK).clamp(0.5, 1.5);
      r = r * k; g = g * k; b = b * k;
    }

    // 对比度
    if (contrastK != 0) {
      final k = 1.0 + 1.5 * contrastK;
      r = (r - 127.5) * k + 127.5;
      g = (g - 127.5) * k + 127.5;
      b = (b - 127.5) * k + 127.5;
    }

    // 饱和/鲜艳
    final gray = 0.299 * r + 0.587 * g + 0.114 * b;
    if (satK != 0) {
      r = gray + (r - gray) * (1.0 + satK);
      g = gray + (g - gray) * (1.0 + satK);
      b = gray + (b - gray) * (1.0 + satK);
    }
    if (vibK != 0) {
      final sat = ((r - gray).abs() + (g - gray).abs() + (b - gray).abs()) / 3.0;
      final weight = (1.0 - (sat / 128.0)).clamp(0.0, 1.0);
      final kv = 1.0 + vibK * weight;
      r = gray + (r - gray) * kv;
      g = gray + (g - gray) * kv;
      b = gray + (b - gray) * kv;
    }

    // gamma
    if ((gamma - 1.0).abs() > 1e-6) {
      final inv = 1.0 / gamma;
      r = 255.0 * math.pow((r / 255.0).clamp(0.0, 1.0), inv);
      g = 255.0 * math.pow((g / 255.0).clamp(0.0, 1.0), inv);
      b = 255.0 * math.pow((b / 255.0).clamp(0.0, 1.0), inv);
    }

    px..r = _clamp255(r)..g = _clamp255(g)..b = _clamp255(b)..a = a;
  }
}
