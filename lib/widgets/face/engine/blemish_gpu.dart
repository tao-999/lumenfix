import 'dart:typed_data';
import 'dart:ui' as ui;

import 'gpu_utils.dart';

/// 祛痘：在点击圆域内做缩小-回拉平滑（后续可替换 inpaint）
class FaceGpuBlemishEngine {
  const FaceGpuBlemishEngine();

  Future<Uint8List> processAt(
      Uint8List inBytes,
      ui.Offset imageCoord,
      double radius,
      ) async {
    final img = await decodeImageCompat(inBytes);

    return drawGpu(img, (c, size) {
      // 背景
      drawFullImage(c, img, size);

      final cx = imageCoord.dx;
      final cy = imageCoord.dy;
      final clipRect = ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: radius);

      c.save();
      c.clipPath(ui.Path()..addOval(clipRect));

      // 以点击点为锚点做轻微缩小→平滑
      const factor = 0.8;
      c.translate(cx, cy);
      c.scale(factor, factor);
      c.translate(-cx, -cy);

      drawFullImage(c, img, size);
      c.restore();
    });
  }
}
