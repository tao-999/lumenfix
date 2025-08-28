// lib/services/filter_material_cache.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../widgets/filters/presets.dart';
import '../widgets/filters/engine/color_common.dart' as cc;

/// 滤镜素材（LUT）持久化缓存
class FilterMaterialCache {
  FilterMaterialCache._();
  static final FilterMaterialCache I = FilterMaterialCache._();
  static FilterMaterialCache get instance => I; // 兼容 instance 写法

  final int defaultLutSize = 33;

  String _safe(String s) => base64Url.encode(utf8.encode(s));

  Future<Directory> _rootDir() async {
    final dir = await getApplicationSupportDirectory();
    final root = Directory(p.join(dir.path, 'filter_materials'));
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  Future<File> _lutFile(String presetId, int size) async {
    final root = await _rootDir();
    final name = 'lut3d_${_safe(presetId)}_$size.png';
    return File(p.join(root.path, name));
  }

  /// 直接用 id + spec：返回 PNG 字节
  Future<Uint8List> ensureLutBytes({
    required String id,
    required Map<String, dynamic> spec,
    int? size,
    bool forceRebake = false,
  }) async {
    final s = size ?? defaultLutSize;
    final f = await _lutFile(id, s);
    if (!forceRebake && await f.exists()) {
      return f.readAsBytes();
    }
    final png = await _bakeLutPng(spec: spec, size: s);
    await f.writeAsBytes(png, flush: true);
    return png;
  }

  /// 需要 File 的版本
  Future<File> ensureLutFile({
    required String id,
    required Map<String, dynamic> spec,
    int? size,
    bool forceRebake = false,
  }) async {
    final s = size ?? defaultLutSize;
    final f = await _lutFile(id, s);
    if (!forceRebake && await f.exists()) return f;
    final png = await _bakeLutPng(spec: spec, size: s);
    await f.writeAsBytes(png, flush: true);
    return f;
  }

  /// 兼容：如果你手头已经是 FilterPreset，也能用这个封装
  Future<Uint8List> getOrBakeLutPng({
    required FilterPreset preset,
    int? size,
    bool forceRebake = false,
  }) {
    return ensureLutBytes(id: preset.id, spec: preset.toMap(), size: size, forceRebake: forceRebake);
  }

  /// 核心烘焙：strip 布局（width=size*size, height=size）
  Future<Uint8List> _bakeLutPng({
    required Map<String, dynamic> spec,
    required int size,
  }) async {
    final width  = size * size;
    final height = size;
    final im = img.Image(width: width, height: height, numChannels: 4);

    final px = Uint8List(4)..[3] = 255; // 复用，减小分配

    for (int b = 0; b < size; b++) {
      final bz = b / (size - 1);
      for (int g = 0; g < size; g++) {
        final gy = g / (size - 1);
        for (int r = 0; r < size; r++) {
          final rx = r / (size - 1);

          px[0] = (rx * 255 + 0.5).floor();
          px[1] = (gy * 255 + 0.5).floor();
          px[2] = (bz * 255 + 0.5).floor();

          // 你的颜色管线：1x1 应用 preset spec
          cc.colorApplySpecInPlace(px, 1, 1, spec);

          final x = r + g * size; // [0, size*size)
          final y = b;            // [0, size)
          im.setPixelRgba(x, y, px[0], px[1], px[2], 255);
        }
      }
    }

    return Uint8List.fromList(img.encodePng(im));
  }
}
