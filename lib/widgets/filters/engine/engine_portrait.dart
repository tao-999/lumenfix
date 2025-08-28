// lib/widgets/filters/engine/engine_portrait.dart
//
// ✅ 人像专用引擎：在通用 spec 基础上做「护肤+通透」微调
// 只在这里做“人像味”增强；common 只负责按 spec 应用。
//
// 规则：
// - 轻降 saturation、提升 vibrance（护肤不脏）
// - 默认 soft/matte 曲线与轻微抬黑，避免高光炸/暗部死黑
// - 轻暖肤（temperature>0），分离色调：阴影微冷/高光微暖
// - 适度抑制青橙（tealOrange 不超过 0.25），更贴近人像
//
// 提供给缩略图/预览：enginePortraitIsolate 作为 compute callback；
// 若需直接在当前 isolate 执行，可用 enginePortrait。

import 'dart:math' as math;
import 'dart:typed_data';

import '../presets.dart';
import 'color_common.dart' as cc;

/// 主入口（当前 isolate 执行）
Future<Uint8List> enginePortrait(
    Uint8List base,
    int w,
    int h,
    FilterPreset p,
    ) async {
  final spec = _mergePortraitSpec(p.toMap(), _avgLuma(base, w, h));
  return cc.colorApplyThumb(base, w, h, spec);
}

/// 给 compute 用的顶层函数（跨 isolate 只能用基础类型）
Uint8List enginePortraitIsolate(Map<String, dynamic> a) {
  final Uint8List rgba = a['rgba'] as Uint8List;
  final int w = a['w'] as int, h = a['h'] as int;
  final Map<String, dynamic> specIn = (a['spec'] as Map).cast<String, dynamic>();
  final spec = _mergePortraitSpec(specIn, _avgLuma(rgba, w, h));
  cc.colorApplySpecInPlace(rgba, w, h, spec);
  return rgba;
}

// ======= Heuristics =======

Map<String, dynamic> _mergePortraitSpec(Map<String, dynamic> spec, double avgLum) {
  final out = Map<String, dynamic>.from(spec);

  // 基线（按亮度轻量自适配）
  final matteBase     = (avgLum > 0.65) ? 0.10 : (avgLum > 0.45 ? 0.08 : 0.06);
  final contrastBase  = (avgLum > 0.65) ? 0.06 : (avgLum > 0.45 ? 0.08 : 0.10);
  const satFloor      = -0.06;
  const vibFloor      =  0.12;
  const tempBias      =  0.06;      // 轻暖肤
  const tealCap       =  0.25;      // 人像不宜过强青橙
  const splitAmtMin   =  0.08;
  const splitBalDef   =  0.12;      // 高光偏暖
  const splitShadow   =  0xFF2B6673; // 阴影微冷青
  const splitHigh     =  0xFFE8B07A; // 高光暖金

  // 曲线：若未指定，默认 soft；若 matte 更贴肤，也接受
  final curve = (out['curve'] ?? 0) as int; // none/soft/hard/film/matte => 0..4
  if (curve == 0) out['curve'] = 1;         // 默认 soft

  // 抬黑/对比（保证下限）
  out['matte']       = _maxNum(out['matte'],     matteBase,    0.0, 1.0);
  out['contrast']    = _maxNum(out['contrast'],  contrastBase, -1.0, 1.0);

  // 饱和/自然饱和（护肤）
  out['saturation']  = _floorNum(out['saturation'], satFloor, -1.0, 1.0);
  out['vibrance']    = _maxNum(out['vibrance'],     vibFloor, -1.0, 1.0);

  // 轻暖肤
  out['temperature'] = _blendToward(out['temperature'], tempBias, wt: .6, min: -1.0, max: 1.0);

  // 青橙控制上限
  final to = _asNum(out['tealOrange']);
  out['tealOrange']  = to > tealCap ? tealCap : to;

  // 分离色调：保证一个最小人像味
  out['splitAmount']   = _maxNum(out['splitAmount'],   splitAmtMin, 0.0, 1.0);
  out['splitBalance']  = out['splitBalance'] ?? splitBalDef;
  out['splitShadow'] ??= splitShadow;
  out['splitHighlight'] ??= splitHigh;

  // 人像默认不开黑白
  if (out['bw'] == true) out['bw'] = false;

  return out;
}

double _avgLuma(Uint8List rgba, int w, int h) {
  if (w <= 0 || h <= 0) return .5;
  final sx = math.max(1, w ~/ 64);
  final sy = math.max(1, h ~/ 64);
  double acc = 0.0; int n = 0;
  for (int y = 0; y < h; y += sy) {
    final row = y * w * 4;
    for (int x = 0; x < w; x += sx) {
      final i = row + x * 4;
      final r = rgba[i].toDouble(), g = rgba[i+1].toDouble(), b = rgba[i+2].toDouble();
      acc += (0.2126*r + 0.7152*g + 0.0722*b) / 255.0; n++;
    }
  }
  return n == 0 ? .5 : (acc / n).clamp(0.0, 1.0);
}

double _asNum(dynamic v, [double d = 0]) => (v is num) ? v.toDouble() : d;
double _maxNum(dynamic current, double floor, double min, double max) {
  final v = _asNum(current);
  return (v >= floor ? v : floor).clamp(min, max);
}
double _floorNum(dynamic current, double floor, double min, double max) {
  final v = _asNum(current);
  return (v <= floor ? v : floor).clamp(min, max);
}
double _blendToward(dynamic current, double toward, {double wt = .5, double min = -1.0, double max = 1.0}) {
  final v = _asNum(current);
  final out = v + (toward - v) * wt;
  return out.clamp(min, max);
}
