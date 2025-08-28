// lib/widgets/filters/engine/engine_vintage.dart
//
// ✅ 复古感专用引擎：把传入 FilterPreset 的 spec 与“复古基线”融合，得到更像老照片的味道。
// - 默认走 matte 曲线（褪色抬黑），适度降低对比与饱和，略暖偏纸黄
// - 轻微分离色调：阴影偏青绿，高光偏茶琥珀
// - 根据画面平均亮度微调 matte/对比，避免一刀切
//
// 用法：
//  1) 面板缩略图/预览：compute(vintageApplyIsolate, {...})  —— 跨 isolate 背景算
//  2) 若需要直接在当前 isolate：engineVintage(base, w, h, preset)

import 'dart:math' as math;
import 'dart:typed_data';

import '../presets.dart';
import 'color_common.dart' as cc;

/// 同步计算平均亮度（子采样）
double _avgLuma(Uint8List rgba, int w, int h) {
  if (w <= 0 || h <= 0) return .5;
  final stepX = math.max(1, w ~/ 64);
  final stepY = math.max(1, h ~/ 64);
  double acc = 0.0;
  int cnt = 0;
  for (int y = 0; y < h; y += stepY) {
    final row = y * w * 4;
    for (int x = 0; x < w; x += stepX) {
      final i = row + x * 4;
      final r = rgba[i].toDouble();
      final g = rgba[i + 1].toDouble();
      final b = rgba[i + 2].toDouble();
      final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
      acc += lum; cnt++;
    }
  }
  if (cnt == 0) return .5;
  return (acc / cnt).clamp(0.0, 1.0);
}

double _asNum(dynamic v, [double d = 0]) => (v is num) ? v.toDouble() : d;
double _clamp(double x, double a, double b) => x < a ? a : (x > b ? b : x);
double _maxNum(dynamic current, double floor, double min, double max) {
  final v = _asNum(current);
  return _clamp(v >= floor ? v : floor, min, max);
}
double _minNum(dynamic current, double ceil, double min, double max) {
  final v = _asNum(current);
  return _clamp(v <= ceil ? v : ceil, min, max);
}
double _blendToward(dynamic current, double toward,
    {double wt = .5, double min = -1.0, double max = 1.0}) {
  final v = _asNum(current);
  final out = v + (toward - v) * wt;
  return _clamp(out, min, max);
}

/// 把“复古基线”融合进 spec（不修改入参 map；返回新 map）
Map<String, dynamic> _composeVintageSpec(
    Map<String, dynamic> specIn,
    double avgLum,
    ) {
  final spec = Map<String, dynamic>.from(specIn);

  // —— 复古基线（随亮度微调）——
  final matteFloor    = (avgLum > 0.65) ? 0.16 : (avgLum > 0.40 ? 0.14 : 0.12);
  final contrastCeil  = (avgLum > 0.65) ? 0.04 : (avgLum > 0.40 ? 0.02 : -0.02);

  // 纸黄微暖 + 轻绿偏（旧纸张味）
  const tempToward    =  0.08;
  const tintToward    = -0.03;

  // 降纯饱和，回一点自然饱和
  const satToward     = -0.12;
  const vibFloor      =  0.08;

  // 轻分离色调：阴影青绿 / 高光茶琥珀
  const splitAmtFloor = 0.14;
  const splitBalBase  = 0.08;
  const splitShadow   = 0xFF2B6B5E; // 青绿
  const splitHigh     = 0xFFD9A15A; // 茶琥珀

  // 统一基线：matte 曲线
  spec['curve'] = 4; // matte
  spec['matte']       = _maxNum(spec['matte'], matteFloor, 0.0, 1.0);
  spec['contrast']    = _minNum(spec['contrast'], contrastCeil, -1.0, 1.0);

  spec['saturation']  = _blendToward(spec['saturation'],  satToward, wt: .7);
  spec['vibrance']    = _maxNum(spec['vibrance'], vibFloor, -1.0, 1.0);

  spec['temperature'] = _blendToward(spec['temperature'], tempToward, wt: .6);
  spec['tint']        = _blendToward(spec['tint'],        tintToward, wt: .5);

  spec['splitAmount']  = _maxNum(spec['splitAmount'],  splitAmtFloor, 0.0, 1.0);
  spec['splitBalance'] = spec['splitBalance'] ?? splitBalBase;
  spec['splitShadow']  ??= splitShadow;
  spec['splitHighlight'] ??= splitHigh;

  // 黑白在复古里默认关（由“黑白”类负责）
  if (spec['bw'] == true) spec['bw'] = false;

  return spec;
}

/// 在当前 isolate 直接应用（不建议用于 UI 线程的大图）
Future<Uint8List> engineVintage(
    Uint8List base,
    int w,
    int h,
    FilterPreset p,
    ) async {
  final spec = _composeVintageSpec(p.toMap(), _avgLuma(base, w, h));
  return cc.colorApplyThumb(base, w, h, spec);
}

/// 给 compute 用的顶层函数（跨 isolate）
Uint8List vintageApplyIsolate(Map<String, dynamic> a) {
  final rgba = a['rgba'] as Uint8List;
  final w = a['w'] as int, h = a['h'] as int;
  final spec0 = (a['spec'] as Map).cast<String, dynamic>();
  final spec = _composeVintageSpec(spec0, _avgLuma(rgba, w, h));
  cc.colorApplySpecInPlace(rgba, w, h, spec);
  return rgba;
}
