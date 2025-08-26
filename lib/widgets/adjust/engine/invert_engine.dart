// lib/widgets/adjust/engine/invert_engine.dart
import 'dart:typed_data';
import '../params/invert_params.dart';

class InvertEngine {
  /// 直接 R/G/B 取反；保留 alpha
  static void applyToRgbaInPlace(
      Uint8List rgba, int width, int height, InvertParams p) {
    if (!p.enabled) return;
    final n = width * height;
    for (int i = 0, pi = 0; i < n; i++, pi += 4) {
      rgba[pi]     = 255 - rgba[pi];     // R
      rgba[pi + 1] = 255 - rgba[pi + 1]; // G
      rgba[pi + 2] = 255 - rgba[pi + 2]; // B
      // A 不动
    }
  }
}
