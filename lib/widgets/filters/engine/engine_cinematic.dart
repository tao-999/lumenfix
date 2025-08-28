// lib/widgets/filters/engine/engine_cinematic.dart
//
// 电影感（Cinematic）专用引擎：和“胶片”拉开差距的专业化处理。
// 1) 在传入 spec 基础上融合“电影味”下限（青橙分离、冷阴影暖高光、对比 & 抬黑、自适应亮度）
// 2) 空域效果：高光 roll-off（高光柔和）、轻微 bloom（高光晕影）、轻度暗角（聚焦）
// 最终交给 color_common 做逐像素调色，随后再做空域处理。
// 注意：color_common 只做“按 spec 应用”；电影化 heuristics 仅在此文件。

import 'dart:math' as math;
import 'dart:typed_data';

import '../presets.dart';
import 'color_common.dart';

Future<Uint8List> engineCinematic(
    Uint8List base,
    int w,
    int h,
    FilterPreset p,
    ) async {
  final spec = Map<String, dynamic>.from(p.toMap());
  _composeCineSpec(spec, base, w, h);

  // 先做调色
  final out = colorApplyThumb(base, w, h, spec);

  // 再做“电影味”的空间增强（缩略图和预览都可承受）
  final area = w * h;
  final roll = (area <= 1200000) ? 0.26 : 0.18; // 大图稍降强度
  final bloomK = (area <= 1200000) ? 0.18 : 0.10;
  final vign = (area <= 1200000) ? 0.12 : 0.08;

  _highlightRolloffInPlace(out, w, h, roll);
  _bloom3x3InPlace(out, w, h, thr: 0.78, k: bloomK);
  _vignetteInPlace(out, w, h, amount: vign);

  return out;
}

// 给 compute 使用：{rgba: Uint8List, w:int, h:int, spec:Map}
Uint8List cinematicApplySpecIsolate(Map<String, dynamic> a) {
  final Uint8List rgba = a['rgba'] as Uint8List;
  final int w = a['w'] as int, h = a['h'] as int;
  final Map<String, dynamic> spec =
  (a['spec'] as Map).cast<String, dynamic>();

  final out = Uint8List.fromList(rgba);
  _composeCineSpec(spec, out, w, h);
  colorApplySpecInPlace(out, w, h, spec);

  final area = w * h;
  final roll = (area <= 1200000) ? 0.26 : 0.18;
  final bloomK = (area <= 1200000) ? 0.18 : 0.10;
  final vign = (area <= 1200000) ? 0.12 : 0.08;

  _highlightRolloffInPlace(out, w, h, roll);
  _bloom3x3InPlace(out, w, h, thr: 0.78, k: bloomK);
  _vignetteInPlace(out, w, h, amount: vign);

  return out;
}

// —— 合成“电影味”基础（尊重预设，只拉到下限/微调） —— //
void _composeCineSpec(
    Map<String, dynamic> spec,
    Uint8List rgba,
    int w,
    int h,
    ) {
  final lum = _avgLuma(rgba, w, h);

  // 对比 & 抬黑：暗场加强对比、亮场稍降
  final matteFloor    = (lum > 0.70) ? 0.06 : (lum > 0.45 ? 0.08 : 0.10);
  final contrastFloor = (lum > 0.70) ? 0.16 : (lum > 0.45 ? 0.20 : 0.22);

  // 色彩：轻冷、护肤，避免数码感
  const satToward  = -0.06;
  const vibFloor   =  0.12;
  const tempToward = -0.06;
  const tintToward =  0.00;

  // 分离色调 & 青橙力度
  const splitAmtFloor = 0.18;
  const splitBalDefault = -0.08; // 偏阴影
  const splitShadow = 0xFF1E8CA8; // 青
  const splitHigh   = 0xFFE7A35A; // 暖金
  final tealFloor   = (lum > 0.65) ? 0.42 : 0.55;

  // 曲线：固定 film
  spec['curve'] = 3;

  spec['matte']       = _maxNum(spec['matte'],       matteFloor,    0.0, 0.20);
  spec['contrast']    = _maxMag(spec['contrast'],    contrastFloor, -1.0, 1.0);
  spec['saturation']  = _blendToward(spec['saturation'],  satToward,  wt: .6, min: -0.30, max: 0.30);
  spec['vibrance']    = _maxNum    (spec['vibrance'],     vibFloor,   -1.0,   1.0);
  spec['temperature'] = _blendToward(spec['temperature'], tempToward, wt: .6, min: -0.30, max: 0.30);
  spec['tint']        = _blendToward(spec['tint'],        tintToward, wt: .4, min: -0.30, max: 0.30);

  spec['splitAmount']   = _maxNum(spec['splitAmount'],  splitAmtFloor, 0.0, 0.35);
  spec['splitBalance']  = (spec['splitBalance'] ?? splitBalDefault);
  spec['splitShadow'] ??= splitShadow;
  spec['splitHighlight'] ??= splitHigh;
  spec['tealOrange']     = _maxNum(spec['tealOrange'], tealFloor, 0.0, 0.75);

  if (spec['bw'] == true) spec['bw'] = false;
}

// —— 空域：高光 rolloff —— //
void _highlightRolloffInPlace(Uint8List rgba, int w, int h, double roll) {
  final n = w * h;
  final keep = 1.0 - roll; // 0.74~
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    double r = rgba[o]     / 255.0;
    double g = rgba[o + 1] / 255.0;
    double b = rgba[o + 2] / 255.0;

    r = (r > .80) ? 1.0 - (1.0 - r) * keep * keep : r;
    g = (g > .80) ? 1.0 - (1.0 - g) * keep * keep : g;
    b = (b > .80) ? 1.0 - (1.0 - b) * keep * keep : b;

    rgba[o]     = _to8(r);
    rgba[o + 1] = _to8(g);
    rgba[o + 2] = _to8(b);
  }
}

// —— 空域：高光 bloom（3x3 高光加权模糊叠加） —— //
void _bloom3x3InPlace(Uint8List rgba, int w, int h,
    {double thr = .78, double k = .18}) {
  if (k <= 0) return;

  final n = w * h;
  final accR = Float32List(n);
  final accG = Float32List(n);
  final accB = Float32List(n);

  // 高斯近似核（归一前）：1 2 1 / 2 4 2 / 1 2 1  -> sum=16
  const kw = [1, 2, 1, 2, 4, 2, 1, 2, 1];

  int idx(int x, int y) => (y * w + x) << 2;

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      double rs = 0, gs = 0, bs = 0, ws = 0;
      int kidx = 0;
      for (int dy = -1; dy <= 1; dy++) {
        final yy = (y + dy).clamp(0, h - 1);
        for (int dx = -1; dx <= 1; dx++) {
          final xx = (x + dx).clamp(0, w - 1);
          final o = idx(xx, yy);
          final r = rgba[o]     / 255.0;
          final g = rgba[o + 1] / 255.0;
          final b = rgba[o + 2] / 255.0;
          final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          final m = _smoothstep(thr, 1.0, lum); // 仅高光参与
          if (m > 0) {
            final wgt = kw[kidx].toDouble() * m;
            rs += r * wgt; gs += g * wgt; bs += b * wgt; ws += wgt;
          }
          kidx++;
        }
      }
      if (ws > 0) {
        final i = y * w + x;
        accR[i] = rs / 16.0;
        accG[i] = gs / 16.0;
        accB[i] = bs / 16.0;
      }
    }
  }

  for (int i = 0; i < n; i++) {
    final o = i << 2;
    final r0 = rgba[o]     / 255.0;
    final g0 = rgba[o + 1] / 255.0;
    final b0 = rgba[o + 2] / 255.0;

    final r = (r0 + accR[i] * k).clamp(0.0, 1.0);
    final g = (g0 + accG[i] * k).clamp(0.0, 1.0);
    final b = (b0 + accB[i] * k).clamp(0.0, 1.0);

    rgba[o]     = _to8(r);
    rgba[o + 1] = _to8(g);
    rgba[o + 2] = _to8(b);
  }
}

// —— 空域：暗角 —— //
void _vignetteInPlace(Uint8List rgba, int w, int h, {double amount = .12}) {
  if (amount <= 0) return;
  final cx = (w - 1) * 0.5;
  final cy = (h - 1) * 0.5;
  final maxd = math.sqrt(cx * cx + cy * cy);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final dx = (x - cx).toDouble();
      final dy = (y - cy).toDouble();
      final d = math.sqrt(dx * dx + dy * dy) / maxd;
      final v = (1.0 - amount * math.pow(d, 1.6)).clamp(0.0, 1.0);
      final o = (y * w + x) << 2;
      rgba[o]     = _to8((rgba[o]     / 255.0) * v);
      rgba[o + 1] = _to8((rgba[o + 1] / 255.0) * v);
      rgba[o + 2] = _to8((rgba[o + 2] / 255.0) * v);
    }
  }
}

// ——— 工具 —— //
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

double _smoothstep(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

int _to8(double x) => (x.clamp(0.0, 1.0) * 255.0 + .5).floor();
