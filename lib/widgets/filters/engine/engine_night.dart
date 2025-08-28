// lib/widgets/filters/engine/engine_night.dart
//
// ✅ 夜景专用引擎：在预设基础上做“夜景友好”的轻量增强（不改 FilterPreset，本地合成 spec）
// 规则：按画面亮度自适配曝光/对比；矫正钠灯偏黄；增强霓虹（冷阴影/暖高光 + 适度青橙）
// 说明：缩略图已降分，直接在 UI isolate 使用也足够流畅；如需更重处理再迁移 compute。
import 'dart:math' as math;
import 'dart:typed_data';

import '../presets.dart';
import 'color_common.dart';

Future<Uint8List> engineNight(
    Uint8List base,
    int w,
    int h,
    FilterPreset p,
    ) async {
  final spec = Map<String, dynamic>.from(p.toMap());

  // —— 估计平均亮度（子采样）——
  double avgLum = _avgLuma(base, w, h);

  // —— 夜景默认基线（在预设基础上“抬下限”而不是硬覆盖）——
  // 低亮度稍微提曝光与对比，避免涂抹；高亮度略压曝光防爆
  final double expBoost   = (avgLum < 0.22) ? 0.22 : (avgLum < 0.35 ? 0.12 : 0.0);
  final double expCut     = (avgLum > 0.65) ? -0.10 : 0.0;
  final double contrast0  = (avgLum < 0.30) ? 0.16 : 0.10;
  const double matte0     = 0.04;   // 轻微抬黑，夜景不“灰”
  const double vib0       = 0.12;   // 用自然饱和拉色，避免过分饱和
  const double sat0       = -0.04;  // 略降纯饱和
  const double tempFix    = -0.14;  // 纠正钠灯发黄（冷一些）
  const double teal0      = 0.38;   // 轻度青橙，配合霓虹
  const double hueJitter  = -4.0;   // 略偏蓝紫

  // 阴影偏青，高光偏暖，兼容霓虹与夜色
  const int splitShadow   = 0xFF116E8A;
  const int splitHigh     = 0xFFE59A57;
  const double splitAmt0  = 0.18;
  const double splitBal0  = 0.08;

  // 合成：只在不足时“补到”基线
  spec['curve']        = (spec['curve'] ?? 3); // 优先使用预设；否则用 film 曲线
  spec['exposureEv']   = (_asNum(spec['exposureEv']) + expBoost + expCut).clamp(-2.0, 2.0);
  spec['contrast']     = _maxNum(spec['contrast'], contrast0, -1.0, 1.0);
  spec['matte']        = _maxNum(spec['matte'],    matte0,    0.0, 1.0);
  spec['vibrance']     = _maxNum(spec['vibrance'], vib0,     -1.0, 1.0);
  spec['saturation']   = _blendToward(spec['saturation'], sat0, wt: .6, min: -1.0, max: 1.0);
  spec['temperature']  = _blendToward(spec['temperature'], tempFix, wt: .7, min: -1.0, max: 1.0);
  spec['tealOrange']   = _maxNum(spec['tealOrange'], teal0,   0.0, 1.0);
  spec['hueShift']     = _blendToward(spec['hueShift'], hueJitter, wt: .5, min: -180.0, max: 180.0);

  spec['splitAmount']   = _maxNum(spec['splitAmount'],  splitAmt0, 0.0, 1.0);
  spec['splitBalance']  = spec['splitBalance'] ?? splitBal0;
  spec['splitShadow'] ??= splitShadow;
  spec['splitHighlight'] ??= splitHigh;

  // 夜景默认保留颜色（若预设误开黑白，这里关闭）
  if (spec['bw'] == true) spec['bw'] = false;

  return colorApplyThumb(base, w, h, spec);
}

double _avgLuma(Uint8List rgba, int w, int h) {
  if (w <= 0 || h <= 0) return .5;
  final stepX = math.max(1, w ~/ 64);
  final stepY = math.max(1, h ~/ 64);
  double acc = 0.0; int cnt = 0;
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
