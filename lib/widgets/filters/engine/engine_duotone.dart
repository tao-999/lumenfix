// lib/widgets/filters/engine/engine_duotone.dart
//
// ✅ 双色调专用引擎：在通用 spec 基础上，保证“先去色 → 再按明度映射两种颜色”
// 规则：
// - 强制降低原始色彩影响（把 saturation 向 -1.0 收敛，vibrance 归零）
// - 若未提供 duoA/duoB，则给一组默认青橙
// - 保底 duoAmount（至少 0.20），并给轻度曲线/对比与抬黑，按平均亮度微调
// - 不修改传入 FilterPreset，本地合成后交给 colorApplyThumb
//
import 'dart:math' as math;
import 'dart:typed_data';

import '../presets.dart';
import 'color_common.dart';

Future<Uint8List> engineDuotone(
    Uint8List base,
    int w,
    int h,
    FilterPreset p,
    ) async {
  final spec = Map<String, dynamic>.from(p.toMap());

  // 明度自适配（很轻）
  final avg = _avgLuma(base, w, h);
  final matte0    = (avg > 0.65) ? 0.10 : (avg > 0.40 ? 0.08 : 0.06);
  final contrast0 = (avg > 0.65) ? 0.08 : (avg > 0.40 ? 0.10 : 0.12);

  // duo 颜色保底
  spec['duoA'] ??= 0xFF0BA3A3; // 青
  spec['duoB'] ??= 0xFFE48A3C; // 橙

  // duo 强度保底
  spec['duoAmount'] = _maxNum(spec['duoAmount'], 0.20, 0.0, 1.0);

  // 先去色，把原色影响压到极低，再让 duo 生效
  spec['saturation']  = _blendToward(spec['saturation'], -1.0, wt: .80, min: -1.0, max: 0.0);
  spec['vibrance']    = _blendToward(spec['vibrance'],   0.0,  wt: .80);
  // 防止误开黑白（黑白会把 duo 变弱）
  spec['bw'] = false;

  // 轻曲线/对比/抬黑，增强分层
  spec['curve']     = spec['curve'] ?? CurveType.soft.index;
  spec['matte']     = _maxNum(spec['matte'],    matte0,    0.0, 1.0);
  spec['contrast']  = _maxNum(spec['contrast'], contrast0, -1.0, 1.0);

  // 双色调里不做 tealOrange / splitTone 等额外着色，避免串味
  spec.remove('tealOrange');
  spec.remove('splitAmount');
  spec.remove('splitBalance');
  spec.remove('splitShadow');
  spec.remove('splitHighlight');

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
