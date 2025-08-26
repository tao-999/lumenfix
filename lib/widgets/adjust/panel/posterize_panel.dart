// lib/widgets/adjust/panel/posterize_panel.dart
import 'package:flutter/material.dart';
import '../common.dart';
import '../params/posterize_params.dart';

class PosterizePanel extends StatelessWidget {
  const PosterizePanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final PosterizeParams value;
  final ValueChanged<PosterizeParams> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CommonSlider(
            label: '色阶',
            value: value.levels.toDouble(),
            min: 2,            // PS 是 2..255，这里常用到 2..64 足够预览
            max: 64,
            neutral: 4,        // PS 默认 4
            onChanged: (v) => onChanged(
              value.copyWith(levels: v.round().clamp(2, 255)),
            ),
            onCommit: onCommit,
          ),
        ],
      ),
    );
  }
}
