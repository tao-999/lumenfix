// lib/widgets/face/engine/face_regions.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'gpu_utils.dart';
import 'lips_seg.dart'; // ✅ 专用唇部分割

class FaceRegions {
  FaceRegions({
    required this.imageSize,
    required this.hasFace,
    this.faceBox,
    this.facePath,
    this.faceSkinPath,
    this.lipsPath,        // 兼容旧字段（= lipsOuterPath）
    this.lipsOuterPath,
    this.lipsInnerPath,
    this.leftEyePath,
    this.rightEyePath,
    this.noseCenter,
    this.skinSegMask,     // 全身皮肤分割 alpha 掩膜（可为空）
    this.skinW,
    this.skinH,
    this.segMasks,        // ✅ 新增：通用分割掩膜（上/下唇/牙齿/并集等）
  });

  final ui.Size imageSize;
  final bool hasFace;

  final ui.Rect? faceBox;

  /// 整脸轮廓
  final ui.Path? facePath;

  /// 脸部“肌肤区域”：= facePath - lipsOuter - eyes
  final ui.Path? faceSkinPath;

  /// 唇部闭合区域（外环，兼容字段）
  final ui.Path? lipsPath;

  /// 外唇闭合区域
  final ui.Path? lipsOuterPath;

  /// 内唇闭合区域（口腔）
  final ui.Path? lipsInnerPath;

  /// 左/右眼闭合区域
  final ui.Path? leftEyePath;
  final ui.Path? rightEyePath;

  /// 鼻尖/鼻底中心（用于瘦鼻锚点）
  final ui.Offset? noseCenter;

  /// 全身皮肤分割掩膜（alpha 0/255）
  final Uint8List? skinSegMask;
  final int? skinW, skinH;

  /// ✅ 多分类掩膜（ui.Image 的 alpha 承载掩膜）
  /// 可能包含：'upper_lip' | 'lower_lip' | 'lips' | 'teeth' ...
  final Map<String, ui.Image>? segMasks;
}

class FaceRegionsDetector {
  const FaceRegionsDetector();

  Future<FaceRegions> detect(Uint8List bytes) async {
    // --- 图片尺寸 ---
    final img = await _decodeBytes(bytes);
    final imgSize = ui.Size(img.width.toDouble(), img.height.toDouble());

    // --- 人脸轮廓（MLKit） ---
    final tmp = await _writeTemp(bytes);
    final input = InputImage.fromFilePath(tmp.path);
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: true,
      enableLandmarks: true,
    );
    final detector = FaceDetector(options: options);
    final faces = await detector.processImage(input);
    await detector.close();
    try { await tmp.delete(); } catch (_) {}

    ui.Path? face;
    ui.Path? lipsOuter;
    ui.Path? lipsInner;
    ui.Path? leftEye;
    ui.Path? rightEye;
    ui.Offset? noseCenter;
    ui.Rect? faceBox;

    if (faces.isNotEmpty) {
      final f = faces.first;
      faceBox = ui.Rect.fromLTWH(
        f.boundingBox.left.toDouble(),
        f.boundingBox.top.toDouble(),
        f.boundingBox.width.toDouble(),
        f.boundingBox.height.toDouble(),
      );

      List<ui.Offset>? _poly(FaceContourType t) {
        final c = f.contours[t];
        if (c == null || c.points.isEmpty) return null;
        return c.points.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList(growable: false);
      }

      ui.Path? _closed(List<ui.Offset>? pts) {
        if (pts == null || pts.isEmpty) return null;
        final p = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
        for (var i = 1; i < pts.length; i++) {
          p.lineTo(pts[i].dx, pts[i].dy);
        }
        p.close();
        return p;
      }

      ui.Path? _ring(List<ui.Offset>? up, List<ui.Offset>? down) {
        if (up == null || up.isEmpty || down == null || down.isEmpty) return null;
        final p = ui.Path()..moveTo(up.first.dx, up.first.dy);
        for (var i = 1; i < up.length; i++) { p.lineTo(up[i].dx, up[i].dy); }
        for (var i = down.length - 1; i >= 0; i--) { p.lineTo(down[i].dx, down[i].dy); }
        p.close();
        return p;
      }

      face     = _closed(_poly(FaceContourType.face));
      leftEye  = _closed(_poly(FaceContourType.leftEye));
      rightEye = _closed(_poly(FaceContourType.rightEye));

      final upTop = _poly(FaceContourType.upperLipTop);
      final upBot = _poly(FaceContourType.upperLipBottom);
      final loTop = _poly(FaceContourType.lowerLipTop);
      final loBot = _poly(FaceContourType.lowerLipBottom);
      lipsOuter = _ring(upTop, loBot);
      lipsInner = _ring(upBot, loTop);

      final nose = f.landmarks[FaceLandmarkType.noseBase];
      if (nose != null) {
        noseCenter = ui.Offset(nose.position.x.toDouble(), nose.position.y.toDouble());
      } else if ((f.contours[FaceContourType.noseBottom]?.points.isNotEmpty ?? false)) {
        final pts = f.contours[FaceContourType.noseBottom]!.points;
        final sx = pts.fold<double>(0, (s, e) => s + e.x.toDouble());
        final sy = pts.fold<double>(0, (s, e) => s + e.y.toDouble());
        noseCenter = ui.Offset(sx / pts.length, sy / pts.length);
      }
    }

    // 脸部肌肤区域：face - lipsOuter - eyes
    ui.Path? faceSkin;
    if (face != null) {
      ui.Path cut = face;
      if (lipsOuter != null) {
        cut = ui.Path.combine(ui.PathOperation.difference, cut, lipsOuter);
      }
      final eyes = <ui.Path>[];
      if (leftEye  != null) eyes.add(leftEye);
      if (rightEye != null) eyes.add(rightEye);
      if (eyes.isNotEmpty) {
        final unionEyes = unionAll(eyes);
        cut = ui.Path.combine(ui.PathOperation.difference, cut, unionEyes);
      }
      faceSkin = cut;
    }

    // --- 专用唇部分割（优先用于上妆；不上色时也能当可视化参考） ---
    Map<String, ui.Image>? lipsSeg;
    try {
      final seg = await LipsSegmentor.run(
        bytes: bytes,
        image: img,
        faceRect: faceBox,
      );
      if (seg != null && seg.isNotEmpty) {
        lipsSeg = seg;
      }
    } catch (_) {
      // 忽略失败
    }

    // --- 全身皮肤分割（可选）---
    Uint8List? skinMask;
    int? skinW, skinH;
    try {
      final seg = await _runSkinSeg(bytes); // 可能抛异常
      if (seg != null) {
        skinMask = seg.$1; skinW = seg.$2; skinH = seg.$3;
      }
    } catch (_) {
      // 忽略失败，使用脸部区域兜底
    }

    return FaceRegions(
      imageSize: imgSize,
      hasFace: faces.isNotEmpty,
      faceBox: faceBox,
      facePath: face,
      faceSkinPath: faceSkin,
      lipsPath: lipsOuter,     // 兼容字段 = 外唇
      lipsOuterPath: lipsOuter,
      lipsInnerPath: lipsInner,
      leftEyePath: leftEye,
      rightEyePath: rightEye,
      noseCenter: noseCenter,
      skinSegMask: skinMask,
      skinW: skinW,
      skinH: skinH,
      segMasks: lipsSeg,       // ✅ 回填
    );
  }

  // ======== TFLite 多分类皮肤分割（只取皮肤类；失败返回 null） ========
  // 需要 assets/models/selfie_multiclass_256x256.tflite
  Future<(Uint8List,int,int)?> _runSkinSeg(Uint8List srcBytes) async {
    tfl.Interpreter? interp;
    try {
      // 注意：asset 路径不要加前导斜杠
      interp = await tfl.Interpreter.fromAsset(
        'assets/models/selfie_multiclass_256x256.tflite',
      );
    } catch (_) {
      return null; // 模型不存在则跳过
    }

    const sz = 256;

    // 1) 预缩放到 256x256，并取 RGBA
    final orig = await _decodeBytes(srcBytes);
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.drawImageRect(
      orig,
      ui.Rect.fromLTWH(0, 0, orig.width.toDouble(), orig.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final scaled = await rec.endRecording().toImage(sz, sz);
    final bd = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = bd!.buffer.asUint8List();
    scaled.dispose();

    // 2) 构输入（float32, NHWC, [0..1]）
    final inputTensor = interp.getInputTensor(0);
    final inShape = inputTensor.shape; // 期望 [1, H, W, 3]
    final inH = inShape.length >= 2 ? inShape[1] : sz;
    final inW = inShape.length >= 3 ? inShape[2] : sz;

    final input = List.generate(
      1,
          (_) => List.generate(
        inH,
            (y) => List.generate(
          inW,
              (x) {
            final sx = (x * sz / inW).floor().clamp(0, sz - 1);
            final sy = (y * sz / inH).floor().clamp(0, sz - 1);
            final i = (sy * sz + sx) * 4;
            final r = rgba[i]     / 255.0;
            final g = rgba[i + 1] / 255.0;
            final b = rgba[i + 2] / 255.0;
            return [r, g, b];
          },
          growable: false,
        ),
        growable: false,
      ),
      growable: false,
    );

    // 3) 输出张量信息
    final outTensor = interp.getOutputTensor(0);
    final outShape = outTensor.shape; // [1, H, W, C]
    final outH = outShape.length >= 2 ? outShape[1] : sz;
    final outW = outShape.length >= 3 ? outShape[2] : sz;
    final outC = outShape.length >= 4 ? outShape[3] : 1;

    if (outC <= 1) {
      try { interp.close(); } catch (_) {}
      return null;
    }

    // 4) 推理
    final output = List.generate(
      1,
          (_) => List.generate(
        outH,
            (_) => List.generate(outW, (_) => List.filled(outC, 0.0), growable: false),
        growable: false,
      ),
      growable: false,
    );
    interp.run(input, output);
    try { interp.close(); } catch (_) {}

    // 5) 只保留“皮肤类”通道（示例：2=body_skin, 3=face_skin；按你的模型调整）
    const Set<int> SKIN_CLASS_IDS = {2, 3};

    final mask = Uint8List(outW * outH);
    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        int arg = 0;
        double best = output[0][y][x][0] as double;
        for (int k = 1; k < outC; k++) {
          final v = output[0][y][x][k] as double;
          if (v > best) { best = v; arg = k; }
        }
        mask[y * outW + x] = SKIN_CLASS_IDS.contains(arg) ? 255 : 0;
      }
    }

    return (mask, outW, outH);
  }

  // ========== helpers ==========
  Future<File> _writeTemp(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ml_face_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<ui.Image> _decodeBytes(Uint8List bytes) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) => c.complete(img));
    return c.future;
  }
}
