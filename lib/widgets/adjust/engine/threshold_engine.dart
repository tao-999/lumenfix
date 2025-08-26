// lib/widgets/adjust/engine/threshold_engine.dart
import 'dart:typed_data';
import '../params/threshold_params.dart';

class ThresholdEngine {
  /// 基于亮度 Y = 0.299R + 0.587G + 0.114B 的二值化
  static void applyToRgbaInPlace(
      Uint8List rgba,
      int width,
      int height,
      ThresholdParams p,
      ) {
    if (!p.enabled) return; // ✅ 未启用则直接跳过

    final t = p.level.clamp(1, 255);
    for (int i = 0; i < rgba.length; i += 4) {
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final y = (0.299 * r + 0.587 * g + 0.114 * b).round();
      final v = (y >= t) ? 255 : 0;
      rgba[i] = v;
      rgba[i + 1] = v;
      rgba[i + 2] = v;
      // alpha 保留
    }
  }
}
