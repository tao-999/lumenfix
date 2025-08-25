// lib/widgets/adjust/engine/adjust_engine.dart
library adjust_engine;

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../adjust_params.dart';

// 把各功能拆成 part，保留“_私有”访问
part 'ops_utils.dart';
part 'ops_base.dart';
part 'ops_color_curves_hsl_grade_split.dart';
part 'ops_detail_texture_sharpen_denoise.dart';
part 'ops_fx_bloom_vignette_grain.dart';
part 'ops_optics_geometry.dart';
part 'ops_lut.dart';

// ===== 新增：FAST 预览开关（part 内可见） =====
bool _FAST = false;

class AdjustEngine {
  static Future<Uint8List> buildPreview(
      Uint8List src,
      AdjustParams p, {
        int maxSide = 1080,
      }) {
    return compute<Map<String, dynamic>, Uint8List>(_applyIsolate, {
      'src': src,
      'params': p.toMap(),
      'maxSide': maxSide,
      'export': false,
    });
  }

  static Future<Uint8List> exportFull(Uint8List src, AdjustParams p) {
    return compute<Map<String, dynamic>, Uint8List>(_applyIsolate, {
      'src': src,
      'params': p.toMap(),
      'maxSide': 0,
      'export': true,
    });
  }
}

// ====================== isolate ======================
Future<Uint8List> _applyIsolate(Map<String, dynamic> m) async {
  final Uint8List src = m['src'] as Uint8List;
  final p = AdjustParams.fromMap(m['params'] as Map);
  final int maxSideIn = m['maxSide'] as int;
  final bool export = m['export'] as bool;

  // 打开 FAST 预览
  _FAST = !export;

  final decoded = img.decodeImage(src);
  if (decoded == null) return src;

  img.Image im = decoded;

  // 预览降采样（FAST 再压一点提升交互流畅）
  int effMaxSide = maxSideIn;
  if (!export) {
    if (effMaxSide <= 0) effMaxSide = 1080;
    effMaxSide = math.min(effMaxSide, 720); // ✅ 预览最长边不超过 720
  }
  if (!export && effMaxSide > 0) {
    final s = (im.width > im.height) ? effMaxSide / im.width : effMaxSide / im.height;
    if (s < 1.0) {
      im = img.copyResize(
        im,
        width: (im.width * s).round(),
        height: (im.height * s).round(),
        interpolation: img.Interpolation.average,
      );
    }
  }

  // ===== Pipeline：几何在前，其它跟着走（预览内置快路径） =====
  opBase(im, p);                          // 曝光/高光阴影/对比/饱和/鲜艳/Gamma
  opCurves(im, p.curves);                 // 曲线
  opHslBands(im, p.hsl);                  // HSL 8 分区
  opColorGrade(im, p.grade);              // 色轮三段
  opSplitToning(im, p.split);             // 分离色调
  opTexture(im, p.texture);               // 纹理（_FAST 时半径减小）
  opClarity(im, p.clarity);               // 清晰度（_FAST 时半径减小）
  opUsm(im, p.usm, p.sharpness);          // USM + 兼容旧 sharpness（_FAST 缩半径）
  opDenoise(im, p.denoise, p.denoiseAdv); // 降噪 亮/色（_FAST 缩半径）
  opBloom(im, p.bloom);                   // 辉光（_FAST 缩半径）
  opVignette(im, p.vignette);             // 暗角（便宜，照常）
  opGrain(im, p.grain);                   // 颗粒（便宜，照常）
  opLut(im, p.lut);                       // LUT（占位混合）

  return Uint8List.fromList(img.encodePng(im));
}
