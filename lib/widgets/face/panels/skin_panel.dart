// lib/widgets/face/panels/skin_panel.dart
import 'package:flutter/material.dart';
import 'panel_common.dart';

/// 美肤面板
class SkinPanel extends StatelessWidget {
  const SkinPanel({
    super.key,
    required this.params,
    required this.onChanged,
  });

  final FaceParams params;
  final ValueChanged<FaceParams> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = params;
    return ListView(
      children: [
        SliderTile(
          icon: Icons.auto_awesome,
          title: '磨皮',
          value: p.skinSmooth, min: 0, max: 1, divisions: 100,
          onChanged: (v) => onChanged(p.copyWith(skinSmooth: v)),
        ),
        SliderTile(
          icon: Icons.light_mode,
          title: '美白',
          value: p.whitening, min: 0, max: 1, divisions: 100,
          onChanged: (v) => onChanged(p.copyWith(whitening: v)),
        ),
        SliderTile(
          icon: Icons.tonality,
          title: '肤色（冷←→暖）',
          value: p.skinTone, min: -1, max: 1, divisions: 100,
          onChanged: (v) => onChanged(p.copyWith(skinTone: v)),
        ),
        const Divider(height: 16),
        SwitchTile(
          icon: Icons.healing,
          title: '祛痘模式（点按修复）',
          value: p.acneMode,
          onChanged: (v) => onChanged(p.copyWith(acneMode: v)),
        ),
        SliderTile(
          icon: Icons.adjust,
          title: '祛痘半径',
          value: p.acneSize, min: 6, max: 48, divisions: 42,
          onChanged: p.acneMode ? (v) => onChanged(p.copyWith(acneSize: v)) : null,
        ),
      ],
    );
  }
}
