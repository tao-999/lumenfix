// lib/widgets/face/engine/skin_gpu.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:vector_math/vector_math_64.dart' show Matrix4;

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
    if ((p.skinSmooth <= 0 && p.whitening <= 0 && p.skinTone.abs() <= 0.001)) {
      return inBytes;
    }

    final img = await decodeImageCompat(inBytes);
    final size = ui.Size(img.width.toDouble(), img.height.toDouble());
    final rect = ui.Offset.zero & size;

    // 优先全身皮肤掩膜
    ui.Image? maskImage;
    if (r.skinSegMask != null && r.skinW != null && r.skinH != null) {
      maskImage = await _alphaMaskToImage(r.skinSegMask!, r.skinW!, r.skinH!,
          color: const ui.Color(0xFFFFFFFF));
    }

    return drawGpu(img, (c, _) {
      // 背景原图
      drawFullImage(c, img, size);

      // 效果画到图层里
      c.saveLayer(rect, ui.Paint());

      // 基底铺一次，保证效果按完整图做（稍后用 dstIn 限定）
      drawFullImage(c, img, size);

      // —— 磨皮（缩放模糊）——
      if (p.skinSmooth > 0) {
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
          rect,
          ui.Paint()
            ..filterQuality = ui.FilterQuality.high
            ..color = const ui.Color(0xFFFFFFFF).withOpacity(p.skinSmooth),
        );
        small.dispose();
      }

      // —— 美白（Screen）——
      if (p.whitening > 0) {
        c.drawRect(
          rect,
          ui.Paint()
            ..color = const ui.Color(0xFFFFFFFF).withOpacity(0.12 * p.whitening)
            ..blendMode = ui.BlendMode.screen,
        );
      }

      // —— 冷暖（色温矩阵）——
      if (p.skinTone.abs() > 0.001) {
        c.saveLayer(rect, ui.Paint()..colorFilter = colorTempMatrix(p.skinTone));
        drawFullImage(c, img, size);
        c.restore();
      }

      // —— 用“皮肤掩膜/脸部肌肤路径”做 dstIn，仅保留皮肤 —— //
      if (maskImage != null) {
        c.drawImageRect(
          maskImage,
          ui.Rect.fromLTWH(0, 0, maskImage.width.toDouble(), maskImage.height.toDouble()),
          rect,
          ui.Paint()..blendMode = ui.BlendMode.dstIn,
        );
      } else if (r.faceSkinPath != null) {
        c.drawPath(
          r.faceSkinPath!,
          ui.Paint()
            ..color = const ui.Color(0xFFFFFFFF)
            ..blendMode = ui.BlendMode.dstIn,
        );
      }

      c.restore(); // 合成回背景
    });
  }

  // α 掩膜 → Image
  Future<ui.Image> _alphaMaskToImage(Uint8List a, int w, int h, {ui.Color color = const ui.Color(0xFFFFFFFF)}) async {
    final rgba = Uint8List(w * h * 4);
    final r = color.red, g = color.green, b = color.blue;
    for (int i = 0, j = 0; i < a.length; i++, j += 4) {
      rgba[j] = r; rgba[j + 1] = g; rgba[j + 2] = b; rgba[j + 3] = a[i];
    }
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }
}
