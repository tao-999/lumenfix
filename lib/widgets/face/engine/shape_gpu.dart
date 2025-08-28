import 'dart:typed_data';
import 'dart:ui' as ui;

import 'gpu_utils.dart';
import '../panels/panel_common.dart';
import 'face_regions.dart';

/// 局部“形变”：用 **裁剪 + 围绕锚点缩放** 的方式对局部做微变形：
/// - 眼睛放大：对左右眼 Path 各自围绕中心 >1.0 缩放并回贴
/// - 瘦脸：围绕脸中心做 X 方向 <1.0 缩放，但仅在脸部 Path 内
/// - 瘦鼻：围绕鼻中心对一个椭圆区域做 X 方向 <1.0 缩放
class FaceGpuShapeEngine {
  const FaceGpuShapeEngine();

  Future<Uint8List> process(
      Uint8List inBytes,
      FaceParams p,
      FaceRegions r,
      ) async {
    if (!r.hasFace ||
        (p.eyeScale <= 0 && p.jawSlim <= 0 && p.noseThin <= 0)) {
      return inBytes;
    }

    final img = await decodeImageCompat(inBytes);

    return drawGpu(img, (c, size) {
      final rect = ui.Offset.zero & size;

      // 背景：原图
      drawFullImage(c, img, size);

      // ---------- 眼睛放大 ----------
      if (p.eyeScale > 0) {
        final scale = 1.0 + 0.15 * p.eyeScale; // 1 ~ 1.15
        void enlargeEye(ui.Path? eyePath) {
          if (eyePath == null) return;
          final b = eyePath.getBounds();
          final cx = b.center.dx;
          final cy = b.center.dy;

          c.save();
          c.clipPath(eyePath);
          c.translate(cx, cy);
          c.scale(scale, scale);
          c.translate(-cx, -cy);
          drawFullImage(c, img, size);
          c.restore();
        }
        enlargeEye(r.leftEyePath);
        enlargeEye(r.rightEyePath);
      }

      // ---------- 瘦脸（仅脸部 Path 内按 X 缩小） ----------
      if (p.jawSlim > 0 && r.facePath != null) {
        final slim = 1.0 - 0.10 * p.jawSlim; // 1 ~ 0.9
        final fb = r.facePath!.getBounds();
        final cx = fb.center.dx;
        final cy = fb.center.dy;

        c.save();
        c.clipPath(r.facePath!);
        c.translate(cx, cy);
        c.scale(slim, 1.0); // X 压缩
        c.translate(-cx, -cy);
        drawFullImage(c, img, size);
        c.restore();
      }

      // ---------- 瘦鼻（鼻中心附近 X 压缩） ----------
      if (p.noseThin > 0 && r.noseCenter != null) {
        final cx = r.noseCenter!.dx;
        final cy = r.noseCenter!.dy;
        final fb = r.facePath?.getBounds();
        final radius = (fb?.width ?? size.width) * 0.12;

        final noseArea = ui.Path()
          ..addOval(ui.Rect.fromCircle(center: ui.Offset(cx, cy), radius: radius));

        final thin = 1.0 - 0.15 * p.noseThin; // 1 ~ 0.85

        c.save();
        c.clipPath(noseArea);
        c.translate(cx, cy);
        c.scale(thin, 1.0);
        c.translate(-cx, -cy);
        drawFullImage(c, img, size);
        c.restore();
      }
    });
  }
}
