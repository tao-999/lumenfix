// lib/widgets/adjust/engine/posterize_engine.dart
import 'dart:typed_data';
import 'dart:math' as math;

import '../params/posterize_params.dart';

class PosterizeEngine {
  /// 将每个 RGB 通道量化为 L 个等级（L>=2）
  static void applyToRgbaInPlace(
      Uint8List rgba,
      int width,
      int height,
      PosterizeParams p,
      ) {
    int L = p.levels.clamp(2, 255);        // 2..255
    final q = 255.0 / (L - 1);             // 等级步长

    for (int i = 0; i < rgba.length; i += 4) {
      final r = rgba[i].toDouble();
      final g = rgba[i + 1].toDouble();
      final b = rgba[i + 2].toDouble();

      rgba[i]     = _quant(r, q);
      rgba[i + 1] = _quant(g, q);
      rgba[i + 2] = _quant(b, q);
      // alpha 不动
    }
  }

  static int _quant(double v, double q) {
    // 经典量化：round(v/q)*q
    final out = ( (v / q).round() * q ).clamp(0.0, 255.0);
    return out.toInt();
  }
}
