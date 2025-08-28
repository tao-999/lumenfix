// lib/widgets/face/engine/face_regions.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

import 'gpu_utils.dart';

class FaceRegions {
  FaceRegions({
    required this.imageSize,
    required this.hasFace,
    this.facePath,
    this.faceSkinPath,
    this.lipsPath,
    this.leftEyePath,
    this.rightEyePath,
    this.noseCenter,
    this.faceBox,
  });

  final ui.Size imageSize;
  final bool hasFace;

  final ui.Rect? faceBox;

  /// 整脸轮廓
  final ui.Path? facePath;

  /// 脸部“肌肤区域”：= facePath - lips - eyes
  final ui.Path? faceSkinPath;

  /// 唇部闭合区域
  final ui.Path? lipsPath;

  /// 左/右眼闭合区域
  final ui.Path? leftEyePath;
  final ui.Path? rightEyePath;

  /// 鼻尖/鼻底中心（用于瘦鼻锚点）
  final ui.Offset? noseCenter;
}

class FaceRegionsDetector {
  const FaceRegionsDetector();

  Future<FaceRegions> detect(Uint8List bytes) async {
    // 用临时文件给 MLKit
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

    // 图片尺寸（绘制坐标系用）
    final img = await decodeImageCompat(bytes);
    final imgSize = ui.Size(img.width.toDouble(), img.height.toDouble());
    img.dispose();

    if (faces.isEmpty) {
      return FaceRegions(imageSize: imgSize, hasFace: false);
    }
    final f = faces.first;
    final box = ui.Rect.fromLTWH(
      f.boundingBox.left.toDouble(),
      f.boundingBox.top.toDouble(),
      f.boundingBox.width.toDouble(),
      f.boundingBox.height.toDouble(),
    );

    ui.Path? buildClosedPath(FaceContourType t) {
      final c = f.contours[t];
      if (c == null || c.points.isEmpty) return null;
      final first = c.points.first;
      final path = ui.Path()
        ..moveTo(first.x.toDouble(), first.y.toDouble()); // ← 必须 double
      for (var i = 1; i < c.points.length; i++) {
        final p = c.points[i];
        path.lineTo(p.x.toDouble(), p.y.toDouble());      // ← 必须 double
      }
      path.close();
      return path;
    }

    ui.Path? lipsPath() {
      // 组合上下唇轮廓
      final uppT = buildClosedPath(FaceContourType.upperLipTop);
      final uppB = buildClosedPath(FaceContourType.upperLipBottom);
      final lowT = buildClosedPath(FaceContourType.lowerLipTop);
      final lowB = buildClosedPath(FaceContourType.lowerLipBottom);
      final parts = [uppT, uppB, lowT, lowB].whereType<ui.Path>();
      if (parts.isEmpty) return null;
      return unionAll(parts);
    }

    final face = buildClosedPath(FaceContourType.face);
    final lip = lipsPath();
    final leftEye = buildClosedPath(FaceContourType.leftEye);
    final rightEye = buildClosedPath(FaceContourType.rightEye);

    final eyesUnion = unionAll([
      if (leftEye != null) leftEye,
      if (rightEye != null) rightEye,
    ]);

    ui.Path? faceSkin;
    if (face != null) {
      ui.Path cut = face;
      if (lip != null) {
        cut = ui.Path.combine(ui.PathOperation.difference, cut, lip);
      }
      if (!eyesUnion.getBounds().isEmpty) {
        cut = ui.Path.combine(ui.PathOperation.difference, cut, eyesUnion);
      }
      faceSkin = cut;
    }

    // 鼻尖/鼻底中心
    ui.Offset? noseCenter;
    final nose = f.landmarks[FaceLandmarkType.noseBase];
    if (nose != null) {
      noseCenter = ui.Offset(
        nose.position.x.toDouble(),
        nose.position.y.toDouble(),
      );
    } else if ((f.contours[FaceContourType.noseBottom]?.points.isNotEmpty ?? false)) {
      final pts = f.contours[FaceContourType.noseBottom]!.points;
      final sx = pts.fold<double>(0, (s, e) => s + e.x.toDouble());
      final sy = pts.fold<double>(0, (s, e) => s + e.y.toDouble());
      noseCenter = ui.Offset(sx / pts.length, sy / pts.length);
    }

    return FaceRegions(
      imageSize: imgSize,
      hasFace: true,
      faceBox: box,
      facePath: face,
      faceSkinPath: faceSkin,
      lipsPath: lip,
      leftEyePath: leftEye,
      rightEyePath: rightEye,
      noseCenter: noseCenter,
    );
  }

  Future<File> _writeTemp(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/ml_face_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
