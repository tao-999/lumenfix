// lib/widgets/filters/panels/panel_night.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../presets.dart';
import 'panel_common.dart';
import '../engine/engine_night.dart';

class PanelNight extends StatelessWidget {
  const PanelNight({
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
      items: _nightPresets,
      selectedId: selectedId,
      idOf: (p) => p.id,
      onPick: onPick,
      renderRgba: (base, w, h, p) => engineNight(
        Uint8List.fromList(base), w, h, p,
      ),
    );
  }
}

// ===== 20 个夜景滤镜（差异明显，中文命名，避免“发灰”） =====
final List<FilterPreset> _nightPresets = [
  // 1 霓虹蓝：冷调 + 青橙 + 对比
  FilterPreset(
    id: 'night_霓虹蓝',
    name: '霓虹蓝',
    cat: FilterCategory.night,
    temperature: -0.18,
    vibrance: 0.12,
    contrast: 0.14,
    curve: CurveType.film,
    tealOrange: 0.42,
    hueShift: -6.0,
  ),
  // 2 赛博紫：高光偏洋红，阴影偏蓝青
  FilterPreset(
    id: 'night_赛博紫',
    name: '赛博紫',
    cat: FilterCategory.night,
    temperature: -0.12,
    splitAmount: 0.22,
    splitBalance: 0.10,
    splitShadow: Color(0xFF145C8C),
    splitHighlight: Color(0xFFE08AD6),
    vibrance: 0.10,
    curve: CurveType.film,
  ),
  // 3 钠灯校正：强力去黄但保留暖感
  FilterPreset(
    id: 'night_钠灯校正',
    name: '钠灯校正',
    cat: FilterCategory.night,
    temperature: -0.24,
    vibrance: 0.08,
    contrast: 0.10,
    curve: CurveType.soft,
  ),
  // 4 冷街：冷峻高反差
  FilterPreset(
    id: 'night_冷街',
    name: '冷街',
    cat: FilterCategory.night,
    temperature: -0.20,
    contrast: 0.18,
    saturation: -0.06,
    curve: CurveType.hard,
  ),
  // 5 黑金夜：阴影偏蓝，高光偏金
  FilterPreset(
    id: 'night_黑金夜',
    name: '黑金夜',
    cat: FilterCategory.night,
    splitAmount: 0.24,
    splitBalance: 0.18,
    splitShadow: Color(0xFF0E3A6B),
    splitHighlight: Color(0xFFE2B55A),
    vibrance: 0.08,
    curve: CurveType.film,
  ),
  // 6 霓虹粉：街拍粉蓝
  FilterPreset(
    id: 'night_霓虹粉',
    name: '霓虹粉',
    cat: FilterCategory.night,
    splitAmount: 0.20,
    splitBalance: 0.06,
    splitShadow: Color(0xFF0E6E8A),
    splitHighlight: Color(0xFFF06292),
    temperature: -0.10,
    vibrance: 0.12,
  ),
  // 7 赛博蓝：蓝青倾向更强
  FilterPreset(
    id: 'night_赛博蓝2',
    name: '赛博蓝2',
    cat: FilterCategory.night,
    temperature: -0.22,
    vibrance: 0.10,
    curve: CurveType.hard,
    tealOrange: 0.30,
  ),
  // 8 夜色通透：适度提升自然饱和
  FilterPreset(
    id: 'night_夜色通透',
    name: '夜色通透',
    cat: FilterCategory.night,
    vibrance: 0.16,
    contrast: 0.10,
    curve: CurveType.soft,
    temperature: -0.06,
  ),
  // 9 蓝辉：带轻微双色调
  FilterPreset(
    id: 'night_蓝辉2',
    name: '蓝辉2',
    cat: FilterCategory.night,
    duoA: Color(0xFF101020),
    duoB: Color(0xFF18A0F0),
    duoAmount: 0.16,
    contrast: 0.08,
  ),
  // 10 夜黑白：硬朗黑白
  FilterPreset(
    id: 'night_夜黑白2',
    name: '夜黑白2',
    cat: FilterCategory.night,
    bw: true,
    curve: CurveType.hard,
    vibrance: -0.18,
  ),
  // 11 夜暖城：压黄到橙金
  FilterPreset(
    id: 'night_夜暖城',
    name: '夜暖城',
    cat: FilterCategory.night,
    temperature: 0.10,
    vibrance: 0.08,
    splitAmount: 0.14,
    splitShadow: Color(0xFF0B5B6B),
    splitHighlight: Color(0xFFE8AE66),
    curve: CurveType.film,
  ),
  // 12 反差夜：显著对比但不发灰
  FilterPreset(
    id: 'night_反差夜',
    name: '反差夜',
    cat: FilterCategory.night,
    contrast: 0.22,
    matte: 0.04,
    temperature: -0.10,
    saturation: -0.04,
    curve: CurveType.hard,
  ),
  // 13 暗紫夜：紫气东来
  FilterPreset(
    id: 'night_暗紫夜',
    name: '暗紫夜',
    cat: FilterCategory.night,
    hueShift: 6.0,
    splitAmount: 0.18,
    splitShadow: Color(0xFF142E6B),
    splitHighlight: Color(0xFFE0A0E8),
    temperature: -0.08,
  ),
  // 14 夜雾：少许雾面但仍通透
  FilterPreset(
    id: 'night_夜雾',
    name: '夜雾',
    cat: FilterCategory.night,
    curve: CurveType.matte,
    matte: 0.10,
    contrast: -0.02,
    temperature: -0.06,
    vibrance: 0.06,
  ),
  // 15 蓝橙街头：经典青橙夜
  FilterPreset(
    id: 'night_蓝橙街头',
    name: '蓝橙街头',
    cat: FilterCategory.night,
    tealOrange: 0.48,
    temperature: -0.12,
    vibrance: 0.12,
    curve: CurveType.film,
  ),
  // 16 影院夜：更电影味
  FilterPreset(
    id: 'night_影院夜',
    name: '影院夜',
    cat: FilterCategory.night,
    curve: CurveType.film,
    contrast: 0.12,
    matte: 0.06,
    saturation: -0.06,
    vibrance: 0.14,
    temperature: -0.08,
    splitAmount: 0.14,
    splitShadow: Color(0xFF0E6E7A),
    splitHighlight: Color(0xFFE7A35A),
  ),
  // 17 冰蓝霓虹：更冷更亮
  FilterPreset(
    id: 'night_冰蓝霓虹',
    name: '冰蓝霓虹',
    cat: FilterCategory.night,
    temperature: -0.26,
    vibrance: 0.10,
    contrast: 0.10,
    splitAmount: 0.12,
    splitShadow: Color(0xFF0F6E8C),
    splitHighlight: Color(0xFFE0F4FF),
  ),
  // 18 夜影：阴影加深
  FilterPreset(
    id: 'night_夜影',
    name: '夜影',
    cat: FilterCategory.night,
    contrast: 0.20,
    matte: 0.02,
    saturation: -0.08,
    curve: CurveType.hard,
  ),
  // 19 柔光夜：柔和高光
  FilterPreset(
    id: 'night_柔光夜',
    name: '柔光夜',
    cat: FilterCategory.night,
    curve: CurveType.soft,
    vibrance: 0.10,
    contrast: 0.06,
    temperature: -0.04,
  ),
  // 20 自然夜：轻修正，保留原味
  FilterPreset(
    id: 'night_自然夜',
    name: '自然夜',
    cat: FilterCategory.night,
    vibrance: 0.06,
    contrast: 0.04,
    temperature: -0.02,
    curve: CurveType.none,
  ),
];
