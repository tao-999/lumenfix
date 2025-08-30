// lib/widgets/face/engine/face_mesh_provider.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

class FaceMeshResult {
  final int width;
  final int height;
  final List<ui.Offset> points; // 像素坐标，长度>=468
  FaceMeshResult({required this.width, required this.height, required this.points});
}

abstract class FaceMeshProvider {
  Future<FaceMeshResult?> detectLandmarks(Uint8List imageBytes);
}

class FaceMesh {
  static FaceMeshProvider? provider;
}
