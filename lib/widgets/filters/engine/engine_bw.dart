// lib/widgets/filters/engine/engine_bw.dart
//
// ✅ 黑白专用引擎：只在这里做黑白风格增强（不改传入 FilterPreset，本地合成 spec）
// 规则：自适配亮度做轻微曝光/对比/抬黑；强制 bw=true；允许用分离色调做冷暖调的黑白风格。
// 输出：把合成后的 spec 交给 color_common 的通用套用。

import 'dart:math' as math;
import 'dart:typed_data';

import '../presets.dart';
import 'color_common.dart';

Future<Uint8List> engineBW(
    Uint8List base,
    int w,
    int h,
    FilterPreset p,
    ) async {
  final spec = Map<String, dynamic>.from(p.toMap());

  // —— 平均亮度估计（子采样）——
  final avg = _avgLuma(base, w, h);

  // —— 黑白基线（根据亮度微调）——
  final double expAdj   = avg < 0.25 ? 0.12 : (avg > 0.72 ? -0.10 : 0.0);
  final double contrast0= avg < 0.30 ? 0.18 : (avg < 0.55 ? 0.14 : 0.10);
  const  double matte0  = 0.06;

  // 合成到 spec：只抬下限
  spec['bw']          = true;                           // 强制黑白
  spec['curve']       = (spec['curve'] ?? 3);           // 默认 film 曲线
  spec['exposureEv']  = (_asNum(spec['exposureEv']) + expAdj).clamp(-2.0, 2.0);
  spec['contrast']    = _maxNum(spec['contrast'], contrast0, -1.0, 1.0);
  spec['matte']       = _maxNum(spec['matte'], matte0,   0.0, 1.0);

  // 饱和度/自然饱和在黑白之后影响很小，但避免负面叠加，这里轻柔向 0 收敛
  spec['saturation']  = _blendToward(spec['saturation'], 0.0, wt: .6);
  spec['vibrance']    = _blendToward(spec['vibrance'],   0.0, wt: .6);

  // 青橙在 bw 之后会当作轻微分色调处理，避免过强
  final ta = _asNum(spec['tealOrange']);
  if (ta > 0.5) spec['tealOrange'] = 0.5;

  return colorApplyThumb(base, w, h, spec);
}

double _avgLuma(Uint8List rgba, int w, int h) {
  if (w <= 0 || h <= 0) return .5;
  final sx = math.max(1, w ~/ 64);
  final sy = math.max(1, h ~/ 64);
  double acc = 0; int cnt = 0;
  for (int y = 0; y < h; y += sy) {
    final row = y * w * 4;
    for (int x = 0; x < w; x += sx) {
      final i = row + x * 4;
      final r = rgba[i].toDouble();
      final g = rgba[i + 1].toDouble();
      final b = rgba[i + 2].toDouble();
      acc += (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
      cnt++;
    }
  }
  return cnt == 0 ? .5 : (acc / cnt).clamp(0.0, 1.0);
}

double _asNum(dynamic v, [double d = 0]) => (v is num) ? v.toDouble() : d;
double _maxNum(dynamic current, double floor, double min, double max) {
  final v = _asNum(current);
  return v >= floor ? v.clamp(min, max) : floor.clamp(min, max);
}
double _blendToward(dynamic current, double toward, {double wt = .5, double min = -1.0, double max = 1.0}) {
  final v = _asNum(current);
  return (v + (toward - v) * wt).clamp(min, max);
}
