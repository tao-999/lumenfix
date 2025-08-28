// lib/services/lut_apply.dart
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// 把 LUT PNG 应用到 RGBA（返回同尺寸 RGBA）
Future<Uint8List> applyLutToRgba({
  required Uint8List rgba,
  required int w,
  required int h,
  required Uint8List lutPng,
  required int lutSize,
  double intensity = 1.0,
}) async {
  final lutIm = img.decodePng(lutPng);
  if (lutIm == null) return rgba; // 兜底直接回原图

  // strip 布局: width = S*S, height = S
  final stripW = lutSize * lutSize;
  Uint8List out = Uint8List.fromList(rgba);

  int idx(int r, int g, int b) {
    final ir = (r * (lutSize - 1) / 255).round();
    final ig = (g * (lutSize - 1) / 255).round();
    final ib = (b * (lutSize - 1) / 255).round();
    final x = ir + ig * lutSize; // [0, S*S)
    final y = ib;                // [0, S)
    return (y * stripW + x) << 2; // RGBA 索引（image包内部用32位色）
  }

  final lutBytes = lutIm.getBytes(order: img.ChannelOrder.rgba);
  final k = intensity.clamp(0.0, 1.0);

  for (int i = 0; i < w * h; i++) {
    final o = i << 2;
    final r = rgba[o], g = rgba[o + 1], b = rgba[o + 2], a = rgba[o + 3];
    final li = idx(r, g, b);

    final lr = lutBytes[li], lg = lutBytes[li + 1], lb = lutBytes[li + 2];

    // 线性混合：k=1 完全LUT，k=0 原图
    out[o]     = (r + k * (lr - r)).round();
    out[o + 1] = (g + k * (lg - g)).round();
    out[o + 2] = (b + k * (lb - b)).round();
    out[o + 3] = a;
  }
  return out;
}
