// lib/widgets/filters/panels/panel_duotone.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../presets.dart';
import 'panel_common.dart';
import '../engine/engine_duotone.dart';

class PanelDuotone extends StatelessWidget {
  const PanelDuotone({
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
      items: _duoPresets,
      selectedId: selectedId,
      idOf: (p) => p.id,
      onPick: onPick,
      renderRgba: (base, w, h, p) => engineDuotone(
        Uint8List.fromList(base), w, h, p,
      ),
    );
  }
}

// ===== 20 个双色调预设（差异明显，色相跨度大，强度/曲线各不同） =====
final List<FilterPreset> _duoPresets = [
  const FilterPreset( // 1
    id: 'duo_青橙',
    name: '青橙',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF0BA3A3), duoB: Color(0xFFE48A3C),
    duoAmount: 0.28, curve: CurveType.soft, contrast: 0.06,
  ),
  const FilterPreset( // 2
    id: 'duo_紫金',
    name: '紫金',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF6A4C93), duoB: Color(0xFFF2A65A),
    duoAmount: 0.26, curve: CurveType.matte, matte: 0.08,
  ),
  const FilterPreset( // 3
    id: 'duo_蓝粉',
    name: '蓝粉',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF1E88E5), duoB: Color(0xFFF06292),
    duoAmount: 0.30, curve: CurveType.soft,
  ),
  const FilterPreset( // 4
    id: 'duo_绿洋红',
    name: '绿洋红',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF43A047), duoB: Color(0xFFD81B60),
    duoAmount: 0.26, curve: CurveType.film, contrast: 0.06,
  ),
  const FilterPreset( // 5
    id: 'duo_青黄',
    name: '青黄',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF00BCD4), duoB: Color(0xFFFFC107),
    duoAmount: 0.24, curve: CurveType.soft,
  ),
  const FilterPreset( // 6
    id: 'duo_青紫',
    name: '青紫',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF009688), duoB: Color(0xFF9C27B0),
    duoAmount: 0.26, curve: CurveType.hard, contrast: 0.10,
  ),
  const FilterPreset( // 7
    id: 'duo_海盐',
    name: '海盐',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF0E7C86), duoB: Color(0xFFB2EBF2),
    duoAmount: 0.22, curve: CurveType.matte, matte: 0.10,
  ),
  const FilterPreset( // 8
    id: 'duo_夜铜',
    name: '夜铜',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF0D1B2A), duoB: Color(0xFFEDB458),
    duoAmount: 0.32, curve: CurveType.hard, contrast: 0.12,
  ),
  const FilterPreset( // 9
    id: 'duo_奶茶',
    name: '奶茶',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF4E342E), duoB: Color(0xFFD7CCC8),
    duoAmount: 0.22, curve: CurveType.matte, matte: 0.12,
  ),
  const FilterPreset( // 10
    id: 'duo_冰蓝',
    name: '冰蓝',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF16324F), duoB: Color(0xFFE3F2FD),
    duoAmount: 0.28, curve: CurveType.soft,
  ),
  const FilterPreset( // 11
    id: 'duo_玫金',
    name: '玫金',
    cat: FilterCategory.duotone,
    duoA: Color(0xFFAD1457), duoB: Color(0xFFF8BBD0),
    duoAmount: 0.26, curve: CurveType.film, contrast: 0.06,
  ),
  const FilterPreset( // 12
    id: 'duo_松绿',
    name: '松绿',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF1B5E20), duoB: Color(0xFFA5D6A7),
    duoAmount: 0.24, curve: CurveType.matte, matte: 0.08,
  ),
  const FilterPreset( // 13
    id: 'duo_火铜',
    name: '火铜',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF8E0000), duoB: Color(0xFFFFAB91),
    duoAmount: 0.30, curve: CurveType.hard, contrast: 0.12,
  ),
  const FilterPreset( // 14
    id: 'duo_银紫',
    name: '银紫',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF37474F), duoB: Color(0xFFE1BEE7),
    duoAmount: 0.22, curve: CurveType.soft,
  ),
  const FilterPreset( // 15
    id: 'duo_琥珀',
    name: '琥珀',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF1A5F7A), duoB: Color(0xFFFFB74D),
    duoAmount: 0.30, curve: CurveType.film, contrast: 0.08,
  ),
  const FilterPreset( // 16
    id: 'duo_霓虹',
    name: '霓虹',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF00BCD4), duoB: Color(0xFFE91E63),
    duoAmount: 0.32, curve: CurveType.hard, contrast: 0.14,
  ),
  const FilterPreset( // 17
    id: 'duo_烟灰',
    name: '烟灰',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF2E2E2E), duoB: Color(0xFFE0E0E0),
    duoAmount: 0.20, curve: CurveType.matte, matte: 0.14,
  ),
  const FilterPreset( // 18
    id: 'duo_森雾',
    name: '森雾',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF2E7D32), duoB: Color(0xFFE8F5E9),
    duoAmount: 0.24, curve: CurveType.soft,
  ),
  const FilterPreset( // 19
    id: 'duo_暮蓝',
    name: '暮蓝',
    cat: FilterCategory.duotone,
    duoA: Color(0xFF1A237E), duoB: Color(0xFFFFCCBC),
    duoAmount: 0.28, curve: CurveType.film, contrast: 0.06,
  ),
  const FilterPreset( // 20
    id: 'duo_朝霞',
    name: '朝霞',
    cat: FilterCategory.duotone,
    duoA: Color(0xFFB71C1C), duoB: Color(0xFFFFD54F),
    duoAmount: 0.32, curve: CurveType.hard, contrast: 0.14,
  ),
];
