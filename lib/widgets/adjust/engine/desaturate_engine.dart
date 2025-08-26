import 'dart:typed_data';

/// 去色：把像素转换为灰度（保持 Alpha）
/// 公式采用 BT.601：Y = 0.299R + 0.587G + 0.114B
class DesaturateEngine {
  static void applyToRgbaInPlace(Uint8List bytes, int w, int h) {
    for (int i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      final y = (0.299 * r + 0.587 * g + 0.114 * b).round();
      bytes[i]     = y;
      bytes[i + 1] = y;
      bytes[i + 2] = y;
      // bytes[i + 3] 保持不变
    }
  }
}
