import 'package:flutter/material.dart';
import '../common.dart';
import '../params/vibrance_params.dart';

class VibrancePanel extends StatelessWidget {
  const VibrancePanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final VibranceParams value;
  final ValueChanged<VibranceParams> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommonSlider(
            label: '自然饱和度',
            value: value.vibrance,
            min: -100, max: 100, neutral: 0,
            onChanged: (v) => onChanged(value.copyWith(vibrance: v)),
            onCommit: onCommit,
          ),
          CommonSlider(
            label: '饱和度',
            value: value.saturation,
            min: -100, max: 100, neutral: 0,
            onChanged: (v) => onChanged(value.copyWith(saturation: v)),
            onCommit: onCommit,
          ),
        ],
      ),
    );
  }
}
