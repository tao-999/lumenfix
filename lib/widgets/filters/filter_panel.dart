// lib/widgets/filters/filter_panel.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'presets.dart';

import 'panels/panel_cinematic.dart';
import 'panels/panel_film.dart';
import 'panels/panel_vintage.dart';
import 'panels/panel_portrait.dart';
import 'panels/panel_landscape.dart';
import 'panels/panel_night.dart';
import 'panels/panel_bw.dart';
import 'panels/panel_duotone.dart';

import 'panels/panel_common.dart';
import 'panels/panel_distort.dart';
import 'panels/panel_pixelate.dart';
import 'panels/panel_stylize.dart'; // “风格化/特效”类

typedef OnPickFilter = void Function(FilterPreset preset);
typedef OnPickEffect = void Function(EffectHandle handle);

class _Tab {
  final String name;
  /// 只读 selectedId；不再传 setSelected（全局单选由父级管理）
  final Widget Function(String? selectedId) builder;
  const _Tab(this.name, this.builder);
}

class FilterPanel extends StatefulWidget {
  const FilterPanel({
    super.key,
    required this.origImage,
    required this.onPick,
    this.onPickEffect,
    this.initialCategory = FilterCategory.cinematic,
    this.selectedPresetId, // 全局唯一选中 id（跨 Tab 单选）
  });

  final ui.Image origImage;
  final OnPickFilter onPick;
  final OnPickEffect? onPickEffect;
  final FilterCategory initialCategory;
  final String? selectedPresetId;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late final List<_Tab> _tabs;
  late int _index;

  int _catToIndex(FilterCategory c) {
    switch (c) {
      case FilterCategory.cinematic: return 0;
      case FilterCategory.film: return 1;
      case FilterCategory.vintage: return 2;
      case FilterCategory.portrait: return 3;
      case FilterCategory.landscape: return 4;
      case FilterCategory.night: return 5;
      case FilterCategory.bw: return 6;
      case FilterCategory.duotone: return 7;
    }
  }

  @override
  void initState() {
    super.initState();
    _index = _catToIndex(widget.initialCategory);

    // 受控：把父级传下来的 selectedPresetId 直接给各 Panel，用它来画勾选
    _tabs = [
      _Tab('电影感',   (sel) => PanelCinematic(img: widget.origImage, selectedId: sel, onPick: widget.onPick)),
      _Tab('胶片',     (sel) => PanelFilm(img: widget.origImage, selectedId: sel, onPick: widget.onPick)),
      _Tab('复古',     (sel) => PanelVintage(img: widget.origImage, selectedId: sel, onPick: widget.onPick)),
      _Tab('人像',     (sel) => PanelPortrait(img: widget.origImage, selectedId: sel, onPick: widget.onPick)),
      _Tab('风光',     (sel) => PanelLandscape(img: widget.origImage, selectedId: sel, onPick: widget.onPick)),
      _Tab('夜景',     (sel) => PanelNight(img: widget.origImage, selectedId: sel, onPick: widget.onPick)),
      _Tab('黑白',     (sel) => PanelBW(img: widget.origImage, selectedId: sel, onPick: widget.onPick)),
      _Tab('双色调',   (sel) => PanelDuotone(img: widget.origImage, selectedId: sel, onPick: widget.onPick)),
      // 特效类（EffectHandle）：同样用全局 selectedId 来显示勾选；选中时回调给父级
      _Tab('扭曲',     (sel) => PanelDistort(img: widget.origImage, selectedId: sel, onPick: (h){ (widget.onPickEffect ?? (_){ })(h); })),
      _Tab('像素化',   (sel) => PanelPixelate(img: widget.origImage, selectedId: sel, onPick: (h){ (widget.onPickEffect ?? (_){ })(h); })),
      _Tab('风格化',   (sel) => PanelStylize(img: widget.origImage, selectedId: sel, onPick: (h){ (widget.onPickEffect ?? (_){ })(h); })),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部 Tab 栏
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final sel = i == _index;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _index = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: sel ? const Color(0x22FFFFFF) : Colors.transparent,
                      border: Border.all(color: sel ? Colors.white : Colors.white24),
                    ),
                    child: Text(
                      _tabs[i].name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1, color: Colors.white10),

        // 面板区：用 IndexedStack，当前页显示其 builder；无需每页独立维护选中态
        Expanded(
          child: IndexedStack(
            index: _index,
            children: List.generate(
              _tabs.length,
                  (i) => _tabs[i].builder(widget.selectedPresetId),
            ),
          ),
        ),
      ],
    );
  }
}
