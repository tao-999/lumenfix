// lib/widgets/filters/panels/panel_bw.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../presets.dart';
import 'panel_common.dart';

// ✅ 用你的黑白引擎
import '../engine/engine_bw.dart' as eng;

// ✅ 只做缩略图的内存缓存（不落盘）
import '../../../services/thumb_cache.dart';

class PanelBW extends StatelessWidget {
  const PanelBW({
    super.key,
    required this.img,
    required this.selectedId,
    required this.onPick,
  });

  final ui.Image img;
  final String? selectedId;
  final void Function(FilterPreset) onPick;

  @override
  Widget build(BuildContext context) {
    return PanelGrid<FilterPreset>(
      img: img,
      items: _bwPresets,
      selectedId: selectedId,
      idOf: (p) => p.id,
      onPick: onPick,
      // ⚡️ 渲染走引擎 + ThumbCache 做内存缓存（跨 Tab/返回也命中）
      renderRgba: (base, w, h, p) => _renderWithEngineAndCache(base, w, h, p),
    );
  }
}

Future<Uint8List> _renderWithEngineAndCache(
    Uint8List base, int w, int h, FilterPreset p,
    ) async {
  // 缩略图缓存 key：底图 + 预设 id（底图指纹很轻量）
  final key = 'thumb:v2:bw:${p.id}|${_fingerprint(base, w, h)}';

  return ThumbCache.I.getOrCompute(key, () async {
    // 用你的 BW 引擎渲染（传副本，避免改到上层 base）
    return eng.engineBW(Uint8List.fromList(base), w, h, p);
  });
}

// 轻量指纹：避免每次算整图 md5（够用且快）
String _fingerprint(Uint8List b, int w, int h) {
  final n = b.length;
  int a = n > 0 ? b[0] : 0;
  int m = n > 2 ? b[n >> 1] : 0;
  int z = n > 1 ? b[n - 1] : 0;
  return '${w}x$h|$n|$a|$m|$z';
}

// ===== 20 个黑白滤镜（原样保留） =====
final List<FilterPreset> _bwPresets = [
  // 1 经典
  const FilterPreset(
    id: 'bw_经典',
    name: '经典',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.none,
    contrast: 0.06,
  ),
  // 2 高反差
  const FilterPreset(
    id: 'bw_高反差',
    name: '高反差',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.hard,
    contrast: 0.22,
  ),
  // 3 雾面
  const FilterPreset(
    id: 'bw_雾面',
    name: '雾面',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.matte,
    matte: 0.16,
    contrast: -0.02,
  ),
  // 4 胶片
  const FilterPreset(
    id: 'bw_胶片',
    name: '胶片',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.film,
    contrast: 0.12,
  ),
  // 5 柔黑
  const FilterPreset(
    id: 'bw_柔黑',
    name: '柔黑',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.soft,
    contrast: 0.06,
  ),
  // 6 冲击
  const FilterPreset(
    id: 'bw_冲击',
    name: '冲击',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.hard,
    contrast: 0.26,
    vibrance: -0.20,
  ),
  // 7 高调（提亮）
  const FilterPreset(
    id: 'bw_高调',
    name: '高调',
    cat: FilterCategory.bw,
    bw: true,
    exposureEv: 0.18,
    contrast: 0.10,
    curve: CurveType.soft,
  ),
  // 8 低调（压暗）
  const FilterPreset(
    id: 'bw_低调',
    name: '低调',
    cat: FilterCategory.bw,
    bw: true,
    exposureEv: -0.18,
    contrast: 0.16,
    curve: CurveType.hard,
  ),
  // 9 银蓝（冷调分色调）
  const FilterPreset(
    id: 'bw_银蓝',
    name: '银蓝',
    cat: FilterCategory.bw,
    bw: true,
    splitAmount: 0.18,
    splitBalance: 0.06,
    splitShadow: Color(0xFF7AA6C7),
    splitHighlight: Color(0xFFD7E8F7),
    curve: CurveType.film,
  ),
  // 10 棕褐（暖调分色调）
  const FilterPreset(
    id: 'bw_棕褐',
    name: '棕褐',
    cat: FilterCategory.bw,
    bw: true,
    splitAmount: 0.22,
    splitBalance: 0.10,
    splitShadow: Color(0xFF7A5A3A),
    splitHighlight: Color(0xFFE4C59A),
    curve: CurveType.soft,
  ),
  // 11 钢灰（冷硬）
  const FilterPreset(
    id: 'bw_钢灰',
    name: '钢灰',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.hard,
    contrast: 0.20,
    splitAmount: 0.10,
    splitShadow: Color(0xFF7E8A96),
    splitHighlight: Color(0xFFE6EAEE),
  ),
  // 12 青铜（暖高光）
  const FilterPreset(
    id: 'bw_青铜',
    name: '青铜',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.film,
    splitAmount: 0.16,
    splitBalance: 0.12,
    splitShadow: Color(0xFF6A6A6A),
    splitHighlight: Color(0xFFE3B068),
  ),
  // 13 报刊（压灰中间调）
  const FilterPreset(
    id: 'bw_报刊',
    name: '报刊',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.matte,
    matte: 0.12,
    contrast: -0.04,
  ),
  // 14 炭笔（深阴影）
  const FilterPreset(
    id: 'bw_炭笔',
    name: '炭笔',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.hard,
    contrast: 0.24,
    matte: 0.02,
  ),
  // 15 泛银（高光拉亮）
  const FilterPreset(
    id: 'bw_泛银',
    name: '泛银',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.soft,
    contrast: 0.08,
    splitAmount: 0.10,
    splitHighlight: Color(0xFFF0F3F8),
  ),
  // 16 暗角黑（更深的低调）
  const FilterPreset(
    id: 'bw_暗角黑',
    name: '暗角黑',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.hard,
    contrast: 0.26,
    saturation: -0.10,
  ),
  // 17 冷夜（冷分色调 + 轻抬黑）
  const FilterPreset(
    id: 'bw_冷夜',
    name: '冷夜',
    cat: FilterCategory.bw,
    bw: true,
    matte: 0.08,
    splitAmount: 0.16,
    splitShadow: Color(0xFF5C7FA3),
    splitHighlight: Color(0xFFE6EEF8),
    curve: CurveType.film,
  ),
  // 18 温柔（柔对比 + 雾面）
  const FilterPreset(
    id: 'bw_温柔',
    name: '温柔',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.matte,
    matte: 0.14,
    contrast: -0.02,
  ),
  // 19 复古灰（整体偏灰但不发闷）
  const FilterPreset(
    id: 'bw_复古灰',
    name: '复古灰',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.matte,
    matte: 0.12,
    contrast: 0.04,
  ),
  // 20 黑色电影（强反差 + 轻暖高光）
  const FilterPreset(
    id: 'bw_黑色电影',
    name: '黑色电影',
    cat: FilterCategory.bw,
    bw: true,
    curve: CurveType.hard,
    contrast: 0.24,
    splitAmount: 0.12,
    splitHighlight: Color(0xFFE7C38A),
  ),
];
