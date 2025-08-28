// lib/widgets/filters/panels/panel_landscape.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../presets.dart';
import 'panel_common.dart';
import '../engine/engine_landscape.dart';

class PanelLandscape extends StatelessWidget {
  const PanelLandscape({
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
      items: _landPresets,
      selectedId: selectedId,
      idOf: (p) => p.id,
      onPick: onPick,
      renderRgba: (base, w, h, p) => engineLandscape(
        Uint8List.fromList(base), w, h, p,
      ),
    );
  }
}

// ===== 20 个风光滤镜（区分明显，中文命名） =====
final List<FilterPreset> _landPresets = [
  // 1 苍翠（绿地增强 + 微青）
  FilterPreset(
    id: 'land_苍翠',
    name: '苍翠',
    cat: FilterCategory.landscape,
    curve: CurveType.soft,
    vibrance: 0.16,
    saturation: 0.04,
    tint: -0.04,
    temperature: -0.02,
    contrast: 0.06,
    tealOrange: 0.18,
  ),
  // 2 山岚（轻雾感 + 抬黑）
  FilterPreset(
    id: 'land_山岚',
    name: '山岚',
    cat: FilterCategory.landscape,
    curve: CurveType.matte,
    matte: 0.16,
    contrast: -0.06,
    vibrance: 0.06,
    temperature: -0.02,
  ),
  // 3 高原蓝（冷调通透）
  FilterPreset(
    id: 'land_高原蓝',
    name: '高原蓝',
    cat: FilterCategory.landscape,
    temperature: -0.16,
    vibrance: 0.12,
    contrast: 0.08,
    curve: CurveType.film,
  ),
  // 4 金色日落（暖高光 + 分离色调）
  FilterPreset(
    id: 'land_金色日落',
    name: '金色日落',
    cat: FilterCategory.landscape,
    temperature: 0.22,
    splitAmount: 0.24,
    splitBalance: 0.18,
    splitShadow: Color(0xFF154A60),
    splitHighlight: Color(0xFFF2B46A),
    curve: CurveType.film,
    vibrance: 0.08,
  ),
  // 5 暮光（蓝调时刻）
  FilterPreset(
    id: 'land_暮光',
    name: '暮光',
    cat: FilterCategory.landscape,
    temperature: -0.20,
    splitAmount: 0.16,
    splitBalance: -0.05,
    splitShadow: Color(0xFF0E3F6B),
    splitHighlight: Color(0xFFD0C3E8),
    vibrance: 0.10,
  ),
  // 6 清晰增强（对比与通透）
  FilterPreset(
    id: 'land_清晰增强',
    name: '清晰增强',
    cat: FilterCategory.landscape,
    curve: CurveType.hard,
    contrast: 0.18,
    vibrance: 0.14,
    saturation: 0.04,
  ),
  // 7 云卷（柔和但不灰）
  FilterPreset(
    id: 'land_云卷',
    name: '云卷',
    cat: FilterCategory.landscape,
    curve: CurveType.soft,
    contrast: -0.02,
    vibrance: 0.12,
    matte: 0.08,
    temperature: -0.04,
  ),
  // 8 森林深绿（偏绿与阴影冷）
  FilterPreset(
    id: 'land_森林深绿',
    name: '森林深绿',
    cat: FilterCategory.landscape,
    tint: -0.08,
    temperature: -0.06,
    vibrance: 0.14,
    contrast: 0.06,
    splitAmount: 0.10,
    splitShadow: Color(0xFF1A5B5B),
    splitHighlight: Color(0xFFE6D4B0),
  ),
  // 9 海岸（青橙海岸线）
  FilterPreset(
    id: 'land_海岸',
    name: '海岸',
    cat: FilterCategory.landscape,
    temperature: -0.08,
    tealOrange: 0.32,
    vibrance: 0.10,
    contrast: 0.08,
  ),
  // 10 沙漠（暖而不爆）
  FilterPreset(
    id: 'land_沙漠',
    name: '沙漠',
    cat: FilterCategory.landscape,
    temperature: 0.26,
    saturation: -0.06,
    vibrance: 0.06,
    curve: CurveType.film,
    splitAmount: 0.12,
    splitHighlight: Color(0xFFF4C27A),
    splitShadow: Color(0xFF6B3E18),
  ),
  // 11 雨后（冷湿低饱和）
  FilterPreset(
    id: 'land_雨后',
    name: '雨后',
    cat: FilterCategory.landscape,
    temperature: -0.14,
    saturation: -0.06,
    vibrance: 0.04,
    contrast: 0.10,
    curve: CurveType.soft,
  ),
  // 12 雾霭（更明显的雾面质感）
  FilterPreset(
    id: 'land_雾霭2',
    name: '雾霭2',
    cat: FilterCategory.landscape,
    curve: CurveType.matte,
    matte: 0.22,
    contrast: -0.10,
    saturation: -0.04,
    temperature: -0.06,
  ),
  // 13 秋韵（枫叶偏暖）
  FilterPreset(
    id: 'land_秋韵',
    name: '秋韵',
    cat: FilterCategory.landscape,
    temperature: 0.18,
    vibrance: 0.10,
    hueShift: 6.0,
    splitAmount: 0.14,
    splitHighlight: Color(0xFFF2A65A),
    splitShadow: Color(0xFF2F5E50),
    curve: CurveType.film,
  ),
  // 14 冰川（青蓝冰感）
  FilterPreset(
    id: 'land_冰川',
    name: '冰川',
    cat: FilterCategory.landscape,
    temperature: -0.22,
    vibrance: 0.08,
    splitAmount: 0.18,
    splitBalance: -0.08,
    splitShadow: Color(0xFF0F6E8C),
    splitHighlight: Color(0xFFE0F4FF),
  ),
  // 15 晴空（天更蓝，地更亮）
  FilterPreset(
    id: 'land_晴空',
    name: '晴空',
    cat: FilterCategory.landscape,
    saturation: 0.08,
    vibrance: 0.14,
    contrast: 0.06,
    temperature: -0.04,
    curve: CurveType.soft,
  ),
  // 16 庭园（绿意暖调）
  FilterPreset(
    id: 'land_庭园',
    name: '庭园',
    cat: FilterCategory.landscape,
    tint: -0.06,
    temperature: 0.06,
    vibrance: 0.12,
    contrast: 0.04,
  ),
  // 17 峡谷（硬朗暖色）
  FilterPreset(
    id: 'land_峡谷',
    name: '峡谷',
    cat: FilterCategory.landscape,
    curve: CurveType.hard,
    contrast: 0.18,
    temperature: 0.16,
    saturation: -0.02,
    vibrance: 0.08,
  ),
  // 18 风暴（冷峻高反差）
  FilterPreset(
    id: 'land_风暴',
    name: '风暴',
    cat: FilterCategory.landscape,
    temperature: -0.18,
    vibrance: -0.06,
    contrast: 0.20,
    curve: CurveType.hard,
  ),
  // 19 极光（高光偏洋红，阴影偏青）
  FilterPreset(
    id: 'land_极光',
    name: '极光',
    cat: FilterCategory.landscape,
    splitAmount: 0.22,
    splitBalance: 0.10,
    splitShadow: Color(0xFF0BA3A3),
    splitHighlight: Color(0xFFE08AD6),
    temperature: -0.06,
    vibrance: 0.12,
    curve: CurveType.film,
  ),
  // 20 自然（轻微修正，尽量真实）
  FilterPreset(
    id: 'land_自然',
    name: '自然',
    cat: FilterCategory.landscape,
    vibrance: 0.08,
    contrast: 0.04,
    temperature: 0.02,
    curve: CurveType.none,
  ),
];
