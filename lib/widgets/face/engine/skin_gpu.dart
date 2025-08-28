import 'dart:typed_data';
import 'dart:ui' as ui;

import 'gpu_utils.dart';
import '../panels/panel_common.dart';
import 'face_regions.dart';

class FaceGpuSkinEngine {
  const FaceGpuSkinEngine();

  Future<Uint8List> process(
      Uint8List inBytes,
      FaceParams p,
      FaceRegions r,
      ) async {
    if (!r.hasFace || r.faceSkinPath == null || p.skinSmooth <= 0 && p.whitening <= 0 && p.skinTone.abs() <= 0.001) {
      return inBytes;
    }

    final img = await decodeImageCompat(inBytes);

    return drawGpu(img, (c, size) {
      // 背景：原图
      drawFullImage(c, img, size);

      // 只处理脸部肌肤
      final area = r.faceSkinPath!;
      final clipBounds = area.getBounds();
      final rect = ui.Offset.zero & size;

      // 磨皮（缩放-回拉），在裁剪内
      if (p.skinSmooth > 0) {
        c.save();
        c.clipPath(area);
        final s = (1.0 - 0.25 * p.skinSmooth).clamp(0.6, 1.0);
        final w = (size.width * s).round();
        final h = (size.height * s).round();

        final rec = ui.PictureRecorder();
        final cc = ui.Canvas(rec);
        drawFullImage(cc, img, ui.Size(w.toDouble(), h.toDouble()));
        final small = rec.endRecording().toImageSync(w, h);

        c.drawImageRect(
          small,
          ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          ui.Rect.fromLTWH(0, 0, size.width, size.height),
          ui.Paint()
            ..filterQuality = ui.FilterQuality.high
            ..color = const ui.Color(0xFFFFFFFF).withOpacity(p.skinSmooth),
        );
        small.dispose();
        c.restore();
      }

      // 美白（Screen），在裁剪内
      if (p.whitening > 0) {
        c.saveLayer(rect, ui.Paint());
        c.clipPath(area);
        drawFullImage(c, img, size);
        c.drawRect(
          rect,
          ui.Paint()
            ..color = const ui.Color(0xFFFFFFFF).withOpacity(0.12 * p.whitening)
            ..blendMode = ui.BlendMode.screen,
        );
        c.restore();
      }

      // 冷暖（矩阵），在裁剪内
      if (p.skinTone.abs() > 0.001) {
        c.saveLayer(rect, ui.Paint()..colorFilter = colorTempMatrix(p.skinTone));
        c.clipPath(area);
        drawFullImage(c, img, size);
        c.restore();
      }
    });
  }
}
