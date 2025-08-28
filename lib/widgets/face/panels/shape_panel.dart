// lib/widgets/face/panels/shape_panel.dart
import 'package:flutter/material.dart';
import 'panel_common.dart';

/// 塑形面板
class ShapePanel extends StatelessWidget {
  const ShapePanel({
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
          icon: Icons.remove_red_eye,
          title: '眼睛放大',
          value: p.eyeScale, min: 0, max: 1, divisions: 100,
          onChanged: (v) => onChanged(p.copyWith(eyeScale: v)),
        ),
        SliderTile(
          icon: Icons.face_retouching_natural,
          title: '瘦脸',
          value: p.jawSlim, min: 0, max: 1, divisions: 100,
          onChanged: (v) => onChanged(p.copyWith(jawSlim: v)),
        ),
        SliderTile(
          icon: Icons.filter_center_focus,
          title: '瘦鼻',
          value: p.noseThin, min: 0, max: 1, divisions: 100,
          onChanged: (v) => onChanged(p.copyWith(noseThin: v)),
        ),
      ],
    );
  }
}
