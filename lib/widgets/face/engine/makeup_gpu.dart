import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import 'face_regions.dart';
import 'gpu_utils.dart';
import '../panels/panel_common.dart';

/// 上妆（唇彩）—— 仅在嘴唇闭合区域内上色
class FaceGpuMakeupEngine {
  const FaceGpuMakeupEngine();

  /// 只改唇部：使用 regions.lipsPath（图像坐标），按 lipColor + lipAlpha 叠加
  Future<Uint8List> process(
      Uint8List inBytes,
      FaceParams p,
      FaceRegions regions,
      ) async {
    // 无唇部或强度为 0：直通
    if (regions.lipsPath == null || p.lipAlpha <= 0.0) {
      return inBytes;
    }

    // 1) 解码到 ui.Image（保持原始像素坐标系）
    final src = await decodeImageCompat(inBytes);

    // 2) 画布：先画底图
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    final srcSize = ui.Size(src.width.toDouble(), src.height.toDouble());
    canvas.drawImage(src, ui.Offset.zero, ui.Paint());

    // 3) 仅在“嘴唇 Path”内上色
    final ui.Path lips = regions.lipsPath!; // 已是图像坐标
    canvas.save();
    // 选一种：直接填充 Path（更准），或 clip 后再画任意形状
    // 这里采用“直接填充 Path”
    final paint = ui.Paint()
      ..isAntiAlias = true
    // 叠色强度
      ..color = p.lipColor.withOpacity(p.lipAlpha.clamp(0.0, 1.0))
    // 更接近唇彩的叠加：overlay 在高光/暗部保留细节
      ..blendMode = ui.BlendMode.overlay;

    // 为了边缘更柔一点，先来一层轻微内发光（可按需调整/去掉）
    final soft = ui.Paint()
      ..isAntiAlias = true
      ..color = p.lipColor.withOpacity((p.lipAlpha * 0.35).clamp(0.0, 1.0))
      ..blendMode = ui.BlendMode.overlay
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5);

    // 先轻柔一层
    canvas.drawPath(lips, soft);
    // 再主色层
    canvas.drawPath(lips, paint);
    canvas.restore();

    // 4) 收图并编码（JPEG，避免 PNG 过大；放后台 isolate）
    final outImage = await rec.endRecording().toImage(src.width, src.height);
    final out = await _encodeJpegIsolate(outImage, quality: 92);

    // 释放
    try { src.dispose(); } catch (_) {}
    try { outImage.dispose(); } catch (_) {}

    return out;
  }
}

/// =============== 编码（在后台 isolate） ===============
class _EncodeArg {
  final Uint8List rgba;
  final int w, h, quality;
  const _EncodeArg(this.rgba, this.w, this.h, this.quality);
}

Future<Uint8List> _encodeJpegIsolate(ui.Image img, {int quality = 92}) async {
  final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final arg = _EncodeArg(
    Uint8List.fromList(bd!.buffer.asUint8List()),
    img.width,
    img.height,
    quality,
  );
  return compute<_EncodeArg, Uint8List>(_encodeJpegWorker, arg);
}

Uint8List _encodeJpegWorker(_EncodeArg a) {
  img.Image _fromBytesCompat(Uint8List bytes) {
    try {
      return img.Image.fromBytes(
        width: a.w,
        height: a.h,
        bytes: bytes.buffer,
        rowStride: a.w * 4,
        order: img.ChannelOrder.rgba,
      );
    } catch (_) {
      return img.Image.fromBytes(
        width: a.w,
        height: a.h,
        bytes: bytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
    }
  }

  try {
    final im = _fromBytesCompat(a.rgba);
    final jpg = img.encodeJpg(im, quality: a.quality);
    return Uint8List.fromList(jpg);
  } catch (_) {
    // 兜底：返回原 RGBA（上层会再处理/压缩）
    return a.rgba;
  }
}
