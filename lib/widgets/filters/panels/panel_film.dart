// lib/widgets/filters/panels/panel_film.dart
//
// 胶片 Panel（与 presets.dart 解耦）：本地 20 个预设 + 胶片专用引擎。
// - 缩略图：正方形、中心裁剪、右下角勾勾（panel_common）
// - 缩略图低分辨率由 PanelGrid 内部控制（长边 ~200px）
// - 所有名称中文，无黑白预设，差异显著

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../presets.dart';
import 'panel_common.dart';
import '../engine/engine_film.dart' as eng;

class PanelFilm extends StatelessWidget {
  const PanelFilm({
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
    const items = _filmPresets;
    return PanelGrid<FilterPreset>(
      img: img,
      items: items,
      selectedId: selectedId,
      idOf: (p) => p.id,
      onPick: onPick,
      renderRgba: (base, w, h, p) async {
        return compute<Map<String, dynamic>, Uint8List>(
          eng.filmApplySpecIsolate,
          {
            'rgba': Uint8List.fromList(base),
            'w': w,
            'h': h,
            'spec': p.toMap(),
          },
        );
      },
    );
  }
}

// —— 20 个“胶片味”预设（差异明显；全部中文；不含黑白） ——
// 注：最终效果 = 本预设参数 + 胶片引擎下限融合
const List<FilterPreset> _filmPresets = [
  // 1. 肤色向（暖）
  FilterPreset(
    id: 'film_暖肤金',
    name: '暖肤金',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.10,
    saturation: -0.04,
    vibrance: 0.14,
    temperature: 0.10,
    tint: -0.03,
    splitAmount: 0.10,
    splitBalance: 0.06,
  ),
  // 2. 冷调通透
  FilterPreset(
    id: 'film_冷调蓝',
    name: '冷调蓝',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.12,
    saturation: -0.02,
    vibrance: 0.10,
    temperature: -0.12,
    tint: -0.02,
    tealOrange: 0.12,
  ),
  // 3. 森林绿味
  FilterPreset(
    id: 'film_森野绿',
    name: '森野绿',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.08,
    saturation: -0.06,
    vibrance: 0.12,
    tint: -0.10,
    temperature: 0.02,
  ),
  // 4. 艳彩冲击
  FilterPreset(
    id: 'film_艳彩',
    name: '艳彩',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.14,
    saturation: 0.10,
    vibrance: 0.08,
    temperature: 0.02,
  ),
  // 5. 柔肤自然
  FilterPreset(
    id: 'film_柔肤',
    name: '柔肤',
    cat: FilterCategory.film,
    curve: CurveType.film,
    saturation: -0.06,
    vibrance: 0.16,
    temperature: 0.06,
    tint: -0.02,
  ),
  // 6. 暖褪色
  FilterPreset(
    id: 'film_暖褪色',
    name: '暖褪色',
    cat: FilterCategory.film,
    curve: CurveType.matte,
    matte: 0.06,
    contrast: -0.02,
    saturation: -0.06,
    temperature: 0.10,
  ),
  // 7. 冷褪色
  FilterPreset(
    id: 'film_冷褪色',
    name: '冷褪色',
    cat: FilterCategory.film,
    curve: CurveType.matte,
    matte: 0.06,
    contrast: -0.02,
    saturation: -0.06,
    temperature: -0.10,
  ),
  // 8. 夕阳橙调
  FilterPreset(
    id: 'film_夕阳橙',
    name: '夕阳橙',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.12,
    vibrance: 0.12,
    temperature: 0.20,
    hueShift: 6.0,
    splitAmount: 0.12,
    splitBalance: 0.12,
  ),
  // 9. 暮色蓝
  FilterPreset(
    id: 'film_暮蓝',
    name: '暮蓝',
    cat: FilterCategory.film,
    curve: CurveType.film,
    saturation: -0.04,
    vibrance: 0.08,
    temperature: -0.16,
    tealOrange: 0.12,
    splitAmount: 0.10,
    splitBalance: -0.02,
  ),
  // 10. 金绿对比
  FilterPreset(
    id: 'film_金绿',
    name: '金绿',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.16,
    saturation: -0.02,
    vibrance: 0.12,
    temperature: 0.12,
    tint: -0.06,
  ),
  // 11. 清晨薄雾
  FilterPreset(
    id: 'film_清晨雾',
    name: '清晨雾',
    cat: FilterCategory.film,
    curve: CurveType.soft,
    matte: 0.04,
    contrast: -0.02,
    saturation: -0.04,
    vibrance: 0.10,
    temperature: 0.02,
  ),
  // 12. 夏日晴空
  FilterPreset(
    id: 'film_夏日晴空',
    name: '夏日晴空',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.10,
    saturation: 0.04,
    vibrance: 0.12,
    temperature: -0.04,
  ),
  // 13. 街头硬朗
  FilterPreset(
    id: 'film_街头硬朗',
    name: '街头硬朗',
    cat: FilterCategory.film,
    curve: CurveType.hard,
    contrast: 0.20,
    saturation: -0.02,
    vibrance: 0.06,
    temperature: -0.02,
    tealOrange: 0.10,
  ),
  // 14. 通透自然
  FilterPreset(
    id: 'film_通透',
    name: '通透',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.08,
    saturation: -0.02,
    vibrance: 0.12,
    temperature: 0.00,
  ),
  // 15. 海岛蓝绿
  FilterPreset(
    id: 'film_海岛',
    name: '海岛',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.10,
    saturation: 0.02,
    vibrance: 0.14,
    temperature: -0.10,
    tint: -0.04,
  ),
  // 16. 金色假日
  FilterPreset(
    id: 'film_金色假日',
    name: '金色假日',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.12,
    saturation: -0.02,
    vibrance: 0.10,
    temperature: 0.18,
    splitAmount: 0.12,
    splitBalance: 0.10,
  ),
  // 17. 冷青胶片
  FilterPreset(
    id: 'film_冷青',
    name: '冷青',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.14,
    saturation: -0.04,
    vibrance: 0.10,
    temperature: -0.14,
    tealOrange: 0.16,
  ),
  // 18. 暗调质感
  FilterPreset(
    id: 'film_暗调',
    name: '暗调',
    cat: FilterCategory.film,
    curve: CurveType.film,
    exposureEv: -0.10,
    contrast: 0.16,
    saturation: -0.06,
    vibrance: 0.12,
    temperature: -0.04,
  ),
  // 19. 高对比经典
  FilterPreset(
    id: 'film_高对比',
    name: '高对比',
    cat: FilterCategory.film,
    curve: CurveType.film,
    contrast: 0.22,
    saturation: -0.02,
    vibrance: 0.10,
  ),
  // 20. 雅致柔色
  FilterPreset(
    id: 'film_雅致',
    name: '雅致',
    cat: FilterCategory.film,
    curve: CurveType.soft,
    contrast: -0.02,
    saturation: -0.04,
    vibrance: 0.12,
    temperature: 0.04,
    tint: -0.02,
  ),
];
