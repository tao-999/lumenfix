// lib/widgets/filters/panels/panel_cinematic.dart
//
// 电影感 Panel（与 presets.dart 解耦）：本地 20 个预设 + 引擎渲染（无 LUT 落盘）。
// - 缩略图：正方形、中心裁剪、右下角勾勾（panel_common）
// - 缩略图低分辨率由 PanelGrid 内部控制（长边 ~200px）
// - 缩略图结果进内存缓存（ThumbCache），切 Tab/重开不再 loading

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../presets.dart';
import 'panel_common.dart';

// ✅ 用电影感引擎（无 LUT）
import '../engine/engine_cinematic.dart' as eng;

// ✅ 只缓存缩略图到内存（不持久化）
import '../../../services/thumb_cache.dart';

class PanelCinematic extends StatelessWidget {
  const PanelCinematic({
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
    // 你现有的 20 个预设列表：_cinePresets（保持不变）
    const items = _cinePresets;

    return PanelGrid<FilterPreset>(
      img: img,
      items: items,
      selectedId: selectedId,
      idOf: (p) => p.id,
      onPick: onPick,
      // ⚡️ 渲染走引擎 + ThumbCache 做内存缓存（跨 Tab / 返回也命中）
      renderRgba: (base, w, h, p) => _renderWithEngineAndCache(base, w, h, p),
    );
  }
}

/// 引擎 + 内存缓存的缩略图渲染
Future<Uint8List> _renderWithEngineAndCache(
    Uint8List base, int w, int h, FilterPreset p,
    ) async {
  // 同一底图 + 预设 → 命中直接返回
  final key = 'thumb:v2:cine:${p.id}|${_fingerprint(base, w, h)}';

  return ThumbCache.I.getOrCompute(key, () async {
    try {
      // 用电影感引擎在后台 isolate 渲染（传副本，避免上层被改）
      return compute<Map<String, dynamic>, Uint8List>(
        eng.cinematicApplySpecIsolate,
        {
          'rgba': Uint8List.fromList(base),
          'w': w,
          'h': h,
          'spec': p.toMap(),
        },
      );
    } catch (_) {
      // 出错就兜底还原
      return base;
    }
  });
}

// 轻量指纹：避免算整图 md5；对缩略图缓存够用且快
String _fingerprint(Uint8List b, int w, int h) {
  final n = b.length;
  int a = n > 0 ? b[0] : 0;
  int m = n > 2 ? b[n >> 1] : 0;
  int z = n > 1 ? b[n - 1] : 0;
  return '${w}x$h|$n|$a|$m|$z';
}

// —— 20 个“电影感”预设（差异明显；全部中文；不含黑白） ——
// 注：最终效果 = 本预设参数 + LUT 烘焙时的电影感底层融合（由 LutBakeCache 内部实现）
const List<FilterPreset> _cinePresets = [
  // 1 冷峻青橙（强青橙 + 冷阴影）
  FilterPreset(
    id: 'cine_冷峻青橙',
    name: '冷峻青橙',
    cat: FilterCategory.cinematic,
    curve: CurveType.film,
    contrast: 0.18,
    saturation: -0.06,
    vibrance: 0.10,
    temperature: -0.12,
    tealOrange: 0.45,
  ),
  // 2 金调暖片（偏暖，肤色友好）
  FilterPreset(
    id: 'cine_金调暖片',
    name: '金调暖片',
    cat: FilterCategory.cinematic,
    curve: CurveType.soft,
    contrast: 0.10,
    temperature: 0.16,
    vibrance: 0.08,
    splitAmount: 0.12,
    splitBalance: 0.10,
  ),
  // 3 钢蓝电影（硬质感 + 冷）
  FilterPreset(
    id: 'cine_钢蓝电影',
    name: '钢蓝电影',
    cat: FilterCategory.cinematic,
    curve: CurveType.hard,
    contrast: 0.22,
    temperature: -0.18,
    vibrance: -0.04,
    tealOrange: 0.38,
  ),
  // 4 夜色霓虹（夜景加成）
  FilterPreset(
    id: 'cine_夜色霓虹',
    name: '夜色霓虹',
    cat: FilterCategory.cinematic,
    exposureEv: -0.20,
    curve: CurveType.film,
    temperature: -0.10,
    vibrance: 0.14,
    splitAmount: 0.22,
    splitBalance: -0.08,
  ),
  // 5 柔雾哑光（哑光低反差，电影灰但不脏）
  FilterPreset(
    id: 'cine_柔雾哑光',
    name: '柔雾哑光',
    cat: FilterCategory.cinematic,
    curve: CurveType.matte,
    matte: 0.12,
    contrast: -0.02,
    vibrance: 0.06,
    temperature: -0.02,
  ),
  // 6 冷金对比（冷阴影+暖高光）
  FilterPreset(
    id: 'cine_冷金对比',
    name: '冷金对比',
    cat: FilterCategory.cinematic,
    curve: CurveType.film,
    contrast: 0.20,
    temperature: -0.06,
    splitAmount: 0.18,
    splitBalance: -0.06,
  ),
  // 7 暗夜蓝（更暗更冷）
  FilterPreset(
    id: 'cine_暗夜蓝',
    name: '暗夜蓝',
    cat: FilterCategory.cinematic,
    exposureEv: -0.25,
    curve: CurveType.film,
    contrast: 0.18,
    temperature: -0.16,
    vibrance: 0.08,
  ),
  // 8 银幕肤色（护肤）
  FilterPreset(
    id: 'cine_银幕肤色',
    name: '银幕肤色',
    cat: FilterCategory.cinematic,
    curve: CurveType.soft,
    saturation: -0.06,
    vibrance: 0.16,
    temperature: 0.06,
    tint: -0.02,
  ),
  // 9 暖日落（强暖 + 金色高光）
  FilterPreset(
    id: 'cine_暖日落',
    name: '暖日落',
    cat: FilterCategory.cinematic,
    curve: CurveType.film,
    temperature: 0.22,
    vibrance: 0.12,
    splitAmount: 0.16,
    splitBalance: 0.12,
  ),
  // 10 赛博蓝（硬核冷色）
  FilterPreset(
    id: 'cine_赛博蓝',
    name: '赛博蓝',
    cat: FilterCategory.cinematic,
    curve: CurveType.hard,
    contrast: 0.24,
    temperature: -0.20,
    vibrance: 0.06,
  ),
  // 11 冷暖均衡（适配多数场景）
  FilterPreset(
    id: 'cine_冷暖均衡',
    name: '冷暖均衡',
    cat: FilterCategory.cinematic,
    curve: CurveType.film,
    contrast: 0.14,
    temperature: -0.02,
    tealOrange: 0.28,
  ),
  // 12 城市质感（街头）
  FilterPreset(
    id: 'cine_城市质感',
    name: '城市质感',
    cat: FilterCategory.cinematic,
    curve: CurveType.film,
    contrast: 0.18,
    saturation: -0.04,
    vibrance: 0.10,
    temperature: -0.06,
  ),
  // 13 森林冷影（绿影加强）
  FilterPreset(
    id: 'cine_森林冷影',
    name: '森林冷影',
    cat: FilterCategory.cinematic,
    curve: CurveType.film,
    contrast: 0.12,
    saturation: -0.04,
    vibrance: 0.12,
    tint: -0.08,
    temperature: -0.04,
  ),
  // 14 冬日冷金
  FilterPreset(
    id: 'cine_冬日冷金',
    name: '冬日冷金',
    cat: FilterCategory.cinematic,
    curve: CurveType.film,
    contrast: 0.16,
    temperature: -0.10,
    splitAmount: 0.14,
    splitBalance: 0.06,
  ),
  // 15 海岸银蓝
  FilterPreset(
    id: 'cine_海岸银蓝',
    name: '海岸银蓝',
    cat: FilterCategory.cinematic,
    curve: CurveType.film,
    contrast: 0.12,
    temperature: -0.12,
    vibrance: 0.10,
    tealOrange: 0.32,
  ),
  // 16 钢铁都市
  FilterPreset(
    id: 'cine_钢铁都市',
    name: '钢铁都市',
    cat: FilterCategory.cinematic,
    curve: CurveType.hard,
    contrast: 0.26,
    saturation: -0.06,
    temperature: -0.08,
  ),
  // 17 柔金晨光
  FilterPreset(
    id: 'cine_柔金晨光',
    name: '柔金晨光',
    cat: FilterCategory.cinematic,
    curve: CurveType.soft,
    contrast: 0.08,
    temperature: 0.14,
    vibrance: 0.10,
  ),
  // 18 夜幕金蓝
  FilterPreset(
    id: 'cine_夜幕金蓝',
    name: '夜幕金蓝',
    cat: FilterCategory.cinematic,
    exposureEv: -0.18,
    curve: CurveType.film,
    contrast: 0.18,
    temperature: -0.12,
    splitAmount: 0.20,
    splitBalance: -0.04,
  ),
  // 19 质感胶彩
  FilterPreset(
    id: 'cine_质感胶彩',
    name: '质感胶彩',
    cat: FilterCategory.cinematic,
    curve: CurveType.film,
    contrast: 0.20,
    saturation: 0.04,
    vibrance: 0.12,
    tealOrange: 0.30,
  ),
  // 20 冷峭硬朗
  FilterPreset(
    id: 'cine_冷峭硬朗',
    name: '冷峭硬朗',
    cat: FilterCategory.cinematic,
    curve: CurveType.hard,
    contrast: 0.26,
    saturation: -0.04,
    temperature: -0.16,
    vibrance: 0.06,
  ),
];
