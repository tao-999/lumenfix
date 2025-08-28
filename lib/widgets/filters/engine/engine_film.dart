// lib/widgets/filters/engine/engine_film.dart
//
// 胶片（Film）专用引擎：在传入 spec 基础上融合“胶片味”下限，最后交给 color_common 应用。
// 目标：区分度明显、避免一片灰、不过度电影风。
// - 固定 film 曲线；轻抬黑 + 自适配对比
// - 轻降饱和 + 回拉自然饱和；轻暖/轻绿校正
// - 轻分离色调（青绿阴影 / 暖黄高光）
// - 低剂量青橙（避免电影感过强）
//
// 用法：panel 的缩略图/预览直接 compute(filmApplySpecIsolate, {...})
// 或直接调用 engineFilm(..)

import 'dart:math' as math;
import 'dart:typed_data';
import '../presets.dart';
import 'color_common.dart';

Future<Uint8List> engineFilm(
    Uint8List base,
    int w,
    int h,
    FilterPreset p,
    ) async {
  final spec = Map<String, dynamic>.from(p.toMap());
  _composeFilmSpec(spec, base, w, h);
  return colorApplyThumb(base, w, h, spec);
}

// 给 compute 使用：{rgba: Uint8List, w:int, h:int, spec:Map}
Uint8List filmApplySpecIsolate(Map<String, dynamic> a) {
  final Uint8List rgba = a['rgba'] as Uint8List;
  final int w = a['w'] as int, h = a['h'] as int;
  final Map<String, dynamic> spec =
  (a['spec'] as Map).cast<String, dynamic>();
  final out = Uint8List.fromList(rgba);
  _composeFilmSpec(spec, out, w, h);
  colorApplySpecInPlace(out, w, h, spec);
  return out;
}

// —— 合成“胶片味”下限（不覆盖用户强设，做下限/微调） —— //
void _composeFilmSpec(
    Map<String, dynamic> spec,
    Uint8List rgba,
    int w,
    int h,
    ) {
  final lum = _avgLuma(rgba, w, h);

  // 自适配对比 / 抬黑：高亮场景降低对比，暗场提升一点
  final matteFloor    = (lum > 0.68) ? 0.06 : (lum > 0.45 ? 0.05 : 0.04);
  final contrastFloor = (lum > 0.68) ? 0.10 : (lum > 0.45 ? 0.12 : 0.16);

  // 胶片基调：柔和颜色、护肤、轻暖 + 轻绿矫正
  const satToward  = -0.04;
  const vibFloor   =  0.12;
  const tempToward =  0.04;
  const tintToward = -0.02;

  // 轻分离色调 + 低剂量青橙（保持“胶片”，不是电影）
  const splitAmtFloor = 0.10;
  const splitBalDefault = 0.08;
  const splitShadow = 0xFF2F5E73; // 青绿阴影
  const splitHigh   = 0xFFECCB9A; // 暖黄高光
  const tealFloor   = 0.14;

  // 保证 film 曲线
  spec['curve'] = 3;

  // 轻抬黑与对比的“下限”
  spec['matte']    = _maxNum(spec['matte'],    matteFloor,    0.0, 0.12);
  spec['contrast'] = _maxMag(spec['contrast'], contrastFloor, -1.0, 1.0);

  // 颜色微调：往目标方向靠一点，但留足空间给预设本身
  spec['saturation']  = _blendToward(spec['saturation'],  satToward,  wt: .5, min: -0.25, max: 0.25);
  spec['vibrance']    = _maxNum    (spec['vibrance'],     vibFloor,   -1.0,   1.0);
  spec['temperature'] = _blendToward(spec['temperature'], tempToward, wt: .5, min: -0.30, max: 0.30);
  spec['tint']        = _blendToward(spec['tint'],        tintToward, wt: .5, min: -0.30, max: 0.30);

  // 分离色调 + 轻青橙
  spec['splitAmount']   = _maxNum(spec['splitAmount'],  splitAmtFloor, 0.0, 0.25);
  spec['splitBalance']  = (spec['splitBalance'] ?? splitBalDefault);
  spec['splitShadow'] ??= splitShadow;
  spec['splitHighlight'] ??= splitHigh;
  spec['tealOrange']     = _maxNum(spec['tealOrange'], tealFloor, 0.0, 0.35);

  // 避免灰：禁止在“胶片”里启用黑白
  if (spec['bw'] == true) spec['bw'] = false;
}

// —— helpers —— //
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

double _asNum(dynamic v, [double d = 0]) => v is num ? v.toDouble() : d;

double _maxNum(dynamic current, double floor, double min, double max) {
  final v = _asNum(current);
  return v >= floor ? v.clamp(min, max) : floor.clamp(min, max);
}

double _maxMag(dynamic current, double target, double min, double max) {
  final v = _asNum(current);
  if (v == 0.0) return target.clamp(min, max);
  final sign = v.sign;
  return (sign * math.max(v.abs(), target.abs())).clamp(min, max);
}

double _blendToward(
    dynamic current,
    double toward, {
      double wt = .5,
      double min = -1.0,
      double max = 1.0,
    }) {
  final v = _asNum(current);
  final out = v + (toward - v) * wt;
  return out.clamp(min, max);
}
