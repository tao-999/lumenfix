// lib/widgets/adjust/panel/brightness_contrast_panel.dart
import 'package:flutter/material.dart';
import '../common.dart';
import '../params/brightness_contrast_params.dart';

class BrightnessContrastPanel extends StatelessWidget {
  const BrightnessContrastPanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final BrightnessContrast value;
  final ValueChanged<BrightnessContrast> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommonSlider(
            label: '亮度',
            value: value.brightness,
            min: -100, max: 100, neutral: 0,
            onChanged: (v) => onChanged(value.copyWith(brightness: v)),
            onCommit: onCommit,
          ),
          CommonSlider(
            label: '对比度',
            value: value.contrast,
            min: -100, max: 100, neutral: 0,
            onChanged: (v) => onChanged(value.copyWith(contrast: v)),
            onCommit: onCommit,
          ),
        ],
      ),
    );
  }
}
