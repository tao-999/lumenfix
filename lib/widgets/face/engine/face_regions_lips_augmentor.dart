// lib/widgets/face/engine/face_regions_lips_augmentor.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'face_mesh_provider.dart';
import 'face_regions_lips_builder.dart';

/// 用 facemesh 强化 FaceRegions 的唇部：
/// - 写回 lipsOuterPath / lipsInnerPath（平滑闭合）
/// - 额外写 lipsUpperRing / lipsLowerRing（真正上妆区域，绝不染牙）
/// - 若无 Provider 或检测失败，保持原样不动
Future<void> augmentFaceRegionsLips({
  required Uint8List imageBytes,
  required dynamic faceRegions, // 你的 FaceRegions（用 dynamic 以免类型冲突）
}) async {
  final prov = FaceMesh.provider;
  if (prov == null) return;

  final mesh = await prov.detectLandmarks(imageBytes);
  if (mesh == null || mesh.points.length < 468) return;

  final adv = buildLipsAdvancedFromMesh(
    imageSize: ui.Size(mesh.width.toDouble(), mesh.height.toDouble()),
    pointsPx: mesh.points,
  );

  // 动态写回；如果你的 FaceRegions 字段是 final，这里 try-catch 忽略
  try { faceRegions.lipsOuterPath = adv.outer; } catch (_) {}
  try { faceRegions.lipsInnerPath = adv.inner; } catch (_) {}
  try { faceRegions.lipsUpperRing = adv.ringUpper; } catch (_) {}
  try { faceRegions.lipsLowerRing = adv.ringLower; } catch (_) {}
}
