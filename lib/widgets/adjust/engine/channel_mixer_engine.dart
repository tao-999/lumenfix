// lib/widgets/adjust/engine/channel_mixer_engine.dart
import 'dart:typed_data';
import 'dart:math' as math;
import '../params/channel_mixer_params.dart';

class ChannelMixerEngine {
  static void applyToRgbaInPlace(
      Uint8List rgba,
      int width,
      int height,
      ChannelMixerParams p,
      ) {
    final n = width * height;

    // 取系数
    final m = p.matrix;
    final r_r = m[0], r_g = m[1], r_b = m[2];
    final g_r = m[3], g_g = m[4], g_b = m[5];
    final b_r = m[6], b_g = m[7], b_b = m[8];

    final oR = p.offset[0];
    final oG = p.offset[1];
    final oB = p.offset[2];

    for (int i = 0, pi = 0; i < n; i++, pi += 4) {
      final r = rgba[pi] / 255.0;
      final g = rgba[pi + 1] / 255.0;
      final b = rgba[pi + 2] / 255.0;

      double rr, gg, bb;

      if (p.monochrome) {
        // 用「红通道的那一行」当灰度混合系数（与很多实现一致）
        final gray = _clamp01(r * r_r + g * r_g + b * r_b + oR);
        rr = gg = bb = gray;
      } else {
        rr = _clamp01(r * r_r + g * r_g + b * r_b + oR);
        gg = _clamp01(r * g_r + g * g_g + b * g_b + oG);
        bb = _clamp01(r * b_r + g * b_g + b * b_b + oB);
      }

      rgba[pi]     = (rr * 255.0).round().clamp(0, 255);
      rgba[pi + 1] = (gg * 255.0).round().clamp(0, 255);
      rgba[pi + 2] = (bb * 255.0).round().clamp(0, 255);
      // A 不动
    }
  }

  static double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
}
