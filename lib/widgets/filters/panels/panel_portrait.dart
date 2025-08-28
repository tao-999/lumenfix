// lib/widgets/filters/panels/panel_portrait.dart
//
// ✅ 人像面板：本地 20 种人像预设 + 专用引擎（engine_portrait）
// - 正方形缩略图，右下角勾选（来自 panel_common）
// - 缩略图使用低分辨率基底（panel_common 已做 192px）
// - 通过 compute(enginePortraitIsolate) 后台渲染

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../presets.dart';
import 'panel_common.dart';
import '../engine/engine_portrait.dart';

class PanelPortrait extends StatelessWidget {
  const PanelPortrait({
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
    final items = _portraitPresets;
    return PanelGrid<FilterPreset>(
      img: img,
      items: items,
      selectedId: selectedId,
      idOf: (p) => p.id,
      onPick: onPick,
      renderRgba: (base, w, h, p) async {
        // 交给人像引擎的 isolate 版本（带人像 heuristics）
        return compute<Map<String, dynamic>, Uint8List>(
          enginePortraitIsolate,
          {'rgba': Uint8List.fromList(base), 'w': w, 'h': h, 'spec': p.toMap()},
        );
      },
    );
  }
}

// ===== 20 个「人像」预设（差异明显，全中文） =====
const List<FilterPreset> _portraitPresets = [
  FilterPreset(
    id: 'portrait_柔肤',
    name: '柔肤',
    cat: FilterCategory.portrait,
    curve: CurveType.soft,
    contrast: -0.04,
    saturation: -0.08,
    vibrance: 0.14,
    temperature: 0.08,
  ),
  FilterPreset(
    id: 'portrait_暖肤',
    name: '暖肤',
    cat: FilterCategory.portrait,
    curve: CurveType.soft,
    temperature: 0.18,
    vibrance: 0.10,
    saturation: -0.06,
  ),
  FilterPreset(
    id: 'portrait_清透',
    name: '清透',
    cat: FilterCategory.portrait,
    contrast: 0.04,
    vibrance: 0.16,
    saturation: -0.02,
    temperature: -0.02,
  ),
  FilterPreset(
    id: 'portrait_奶感',
    name: '奶感',
    cat: FilterCategory.portrait,
    curve: CurveType.matte,
    matte: 0.14,
    contrast: -0.08,
    saturation: -0.12,
    vibrance: 0.08,
  ),
  FilterPreset(
    id: 'portrait_通透暖',
    name: '通透暖',
    cat: FilterCategory.portrait,
    curve: CurveType.soft,
    contrast: 0.08,
    temperature: 0.12,
    vibrance: 0.12,
  ),
  FilterPreset(
    id: 'portrait_轻冷',
    name: '轻冷',
    cat: FilterCategory.portrait,
    curve: CurveType.soft,
    temperature: -0.10,
    vibrance: 0.10,
    saturation: -0.04,
  ),
  FilterPreset(
    id: 'portrait_高键',
    name: '高键',
    cat: FilterCategory.portrait,
    exposureEv: 0.25,
    contrast: -0.06,
    vibrance: 0.10,
    temperature: 0.06,
    curve: CurveType.soft,
  ),
  FilterPreset(
    id: 'portrait_低键',
    name: '低键',
    cat: FilterCategory.portrait,
    exposureEv: -0.20,
    contrast: 0.12,
    matte: 0.06,
    temperature: -0.06,
    curve: CurveType.matte,
  ),
  FilterPreset(
    id: 'portrait_蜜桃',
    name: '蜜桃',
    cat: FilterCategory.portrait,
    hueShift: 4.0,
    temperature: 0.16,
    vibrance: 0.12,
    saturation: -0.06,
    splitAmount: 0.10,
    splitHighlight: Color(0xFFEFB48A),
    splitShadow: Color(0xFF285B6A),
    curve: CurveType.soft,
  ),
  FilterPreset(
    id: 'portrait_玫调',
    name: '玫调',
    cat: FilterCategory.portrait,
    hueShift: 8.0,
    saturation: -0.08,
    vibrance: 0.16,
    temperature: 0.06,
    splitAmount: 0.08,
    splitHighlight: Color(0xFFE7A6B8),
    splitShadow: Color(0xFF2A5866),
    curve: CurveType.matte,
  ),
  FilterPreset(
    id: 'portrait_暖金',
    name: '暖金',
    cat: FilterCategory.portrait,
    temperature: 0.22,
    vibrance: 0.08,
    saturation: -0.04,
    splitAmount: 0.12,
    splitHighlight: Color(0xFFE6B477),
    splitShadow: Color(0xFF2B5E6C),
    curve: CurveType.soft,
  ),
  FilterPreset(
    id: 'portrait_清晨',
    name: '清晨',
    cat: FilterCategory.portrait,
    exposureEv: 0.12,
    temperature: -0.04,
    vibrance: 0.14,
    saturation: -0.04,
    curve: CurveType.film,
  ),
  FilterPreset(
    id: 'portrait_夜暖',
    name: '夜暖',
    cat: FilterCategory.portrait,
    exposureEv: -0.10,
    temperature: 0.18,
    contrast: 0.06,
    vibrance: 0.10,
    curve: CurveType.soft,
  ),
  FilterPreset(
    id: 'portrait_轻雾',
    name: '轻雾',
    cat: FilterCategory.portrait,
    matte: 0.12,
    contrast: -0.06,
    temperature: 0.04,
    saturation: -0.08,
    vibrance: 0.12,
    curve: CurveType.matte,
  ),
  FilterPreset(
    id: 'portrait_通透冷',
    name: '通透冷',
    cat: FilterCategory.portrait,
    contrast: 0.08,
    temperature: -0.14,
    vibrance: 0.12,
    saturation: -0.04,
    curve: CurveType.hard,
  ),
  FilterPreset(
    id: 'portrait_胶片肤',
    name: '胶片肤',
    cat: FilterCategory.portrait,
    curve: CurveType.film,
    saturation: -0.06,
    vibrance: 0.14,
    temperature: 0.08,
    splitAmount: 0.10,
    splitBalance: 0.12,
    splitShadow: Color(0xFF2F5E73),
    splitHighlight: Color(0xFFECCB9A),
  ),
  FilterPreset(
    id: 'portrait_奶油',
    name: '奶油',
    cat: FilterCategory.portrait,
    curve: CurveType.matte,
    matte: 0.16,
    contrast: -0.10,
    saturation: -0.12,
    vibrance: 0.10,
  ),
  FilterPreset(
    id: 'portrait_暖阳',
    name: '暖阳',
    cat: FilterCategory.portrait,
    exposureEv: 0.10,
    temperature: 0.22,
    vibrance: 0.10,
    saturation: -0.04,
    curve: CurveType.soft,
  ),
  FilterPreset(
    id: 'portrait_冷冽',
    name: '冷冽',
    cat: FilterCategory.portrait,
    temperature: -0.20,
    contrast: 0.10,
    vibrance: 0.08,
    hueShift: -4.0,
    curve: CurveType.hard,
  ),
  FilterPreset(
    id: 'portrait_通透中性',
    name: '通透中性',
    cat: FilterCategory.portrait,
    contrast: 0.06,
    vibrance: 0.12,
    saturation: -0.04,
    temperature: 0.02,
    curve: CurveType.soft,
  ),
];
