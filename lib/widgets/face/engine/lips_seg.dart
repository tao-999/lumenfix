// lib/widgets/face/engine/lips_seg.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

/// 轻量唇部分割（上/下唇分开），支持任意 256/320 等输入大小的人脸解析/唇部模型。
/// - 默认假设模型输出含类别：upper_lip、lower_lip、teeth（可改映射）
/// - 仅在 “人脸区域” 内做推理，再贴回全图坐标
/// - 返回：segMasks['upper_lip'|'lower_lip'|'lips'(并集)|'teeth' (可为空)] 的 ui.Image（灰度Alpha）
///
/// 你需要在 assets 放一个唇/人脸解析模型：
///   assets/models/lips_parsing_256.tflite
/// 如果你的模型类目 ID 不同，改下面的 `kClassIds` 即可。
class LipsSegmentor {
  LipsSegmentor._();

  static tfl.Interpreter? _interp;
  static List<int>? _inShape;   // [1,H,W,3]
  static List<int>? _outShape;  // [1,H,W,C]

  // 根据你的模型类别表修改这些 ID（示例：常见face-parsing/bisenet系）
  static const int kUpperLipId = 12;
  static const int kLowerLipId = 13;
  static const int kTeethId    = 21; // 没有牙齿就留着无效

  static Future<void> _ensure() async {
    if (_interp != null) return;
    final opt = tfl.InterpreterOptions()
      ..threads = 2
      ..useNnApiForAndroid = true;
    _interp = await tfl.Interpreter.fromAsset(
      'assets/models/lips_parsing_256.tflite',
      options: opt,
    );
    _inShape  = _interp!.getInputTensor(0).shape;  // [1,h,w,3]
    _outShape = _interp!.getOutputTensor(0).shape; // [1,h,w,c]
  }

  /// 主入口：
  /// [image] 原图（为取得尺寸用）；[bytes] 原图jpg/png；[faceRect] 可选人脸框（相对原图像素）
  static Future<Map<String, ui.Image>?> run({
    required Uint8List bytes,
    required ui.Image image,
    ui.Rect? faceRect,
  }) async {
    try {
      await _ensure();
    } catch (_) {
      return null; // 模型不存在 → 跳过
    }

    final inH = _inShape![1], inW = _inShape![2];

    // 1) 取推理区域（有人脸就扩一点，只跑这块）
    final ui.Rect full = ui.Offset.zero & ui.Size(image.width.toDouble(), image.height.toDouble());
    ui.Rect roi = faceRect == null || faceRect.isEmpty
        ? full
        : faceRect.inflate(faceRect.height * 0.18).intersect(full);
    if (roi.isEmpty) roi = full;

    // 2) 把 ROI 等比缩放/填满到模型输入
    final ui.PictureRecorder rec = ui.PictureRecorder();
    final ui.Canvas c = ui.Canvas(rec);
    c.drawImageRect(
      image,
      roi,
      ui.Rect.fromLTWH(0, 0, inW.toDouble(), inH.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final ui.Image scaled = await rec.endRecording().toImage(inW, inH);
    final bd = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = bd!.buffer.asUint8List();
    scaled.dispose();

    // 3) 构输入 NHWC float32 0..1
    final input = List.generate(1, (_) =>
        List.generate(inH, (y) =>
            List.generate(inW, (x) {
              final i = (y * inW + x) * 4;
              final r = rgba[i]     / 255.0;
              final g = rgba[i + 1] / 255.0;
              final b = rgba[i + 2] / 255.0;
              return [r, g, b];
            }, growable: false),
            growable: false),
        growable: false);

    // 4) 准备输出 [1,h,w,c]
    final outH = _outShape![1], outW = _outShape![2], outC = _outShape![3];
    final output = List.generate(1, (_) =>
        List.generate(outH, (_) =>
            List.generate(outW, (_) => List.filled(outC, 0.0), growable: false),
            growable: false),
        growable: false);

    _interp!.run(input, output);

    // 5) 逐像素 argmax → 标签图
    final labels = Uint16List(outW * outH);
    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        int arg = 0;
        double best = output[0][y][x][0] as double;
        for (int k = 1; k < outC; k++) {
          final v = output[0][y][x][k] as double;
          if (v > best) { best = v; arg = k; }
        }
        labels[y * outW + x] = arg;
      }
    }

    // 6) 组上/下/并集/牙齿 掩膜（模型若无 teeth，就会全透明）
    final upperCrop = await _labelToAlphaMask(
      labels, outW, outH, {kUpperLipId},
    );
    final lowerCrop = await _labelToAlphaMask(
      labels, outW, outH, {kLowerLipId},
    );
    final teethCrop = await _labelToAlphaMask(
      labels, outW, outH, {kTeethId},
    );
    final lipsCrop  = await _labelToAlphaMask(
      labels, outW, outH, {kUpperLipId, kLowerLipId},
    );

    // 7) 贴回到全图坐标（把 crop mask 拉回到 roi）
    final upperFull = await _placeToCanvas(upperCrop, roi, full.size);
    final lowerFull = await _placeToCanvas(lowerCrop, roi, full.size);
    final lipsFull  = await _placeToCanvas(lipsCrop , roi, full.size);
    final teethFull = await _placeToCanvas(teethCrop, roi, full.size);

    // 返回 map（有的可能是透明但也给）
    return <String, ui.Image>{
      'upper_lip': upperFull,
      'lower_lip': lowerFull,
      'lips':      lipsFull,
      'teeth':     teethFull,
    };
  }

  /// labels(WH) → Alpha(0/255) 的 ui.Image（白色，alpha 承载掩膜）
  static Future<ui.Image> _labelToAlphaMask(
      Uint16List labels, int w, int h, Set<int> keepIds) async {
    final out = Uint8List(w * h * 4);
    for (int i = 0; i < w * h; i++) {
      final a = keepIds.contains(labels[i]) ? 255 : 0;
      final j = i * 4;
      out[j] = 0xFF; out[j + 1] = 0xFF; out[j + 2] = 0xFF; out[j + 3] = a;
    }
    final buf = await ui.ImmutableBuffer.fromUint8List(out);
    final desc = ui.ImageDescriptor.raw(
      buf,
      width: w,
      height: h,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await desc.instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// 把裁剪掩膜（crop）缩放放置到 [roi] 在全图坐标的位置
  static Future<ui.Image> _placeToCanvas(
      ui.Image crop, ui.Rect roi, ui.Size full) async {
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    final dst = roi;
    c.drawImageRect(
      crop,
      ui.Rect.fromLTWH(0, 0, crop.width.toDouble(), crop.height.toDouble()),
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final pic = rec.endRecording();
    return pic.toImage(full.width.toInt(), full.height.toInt());
  }
}
