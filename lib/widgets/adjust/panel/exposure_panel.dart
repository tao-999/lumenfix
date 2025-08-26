// lib/widgets/adjust/panel/exposure_panel.dart
import 'package:flutter/material.dart';
import '../common.dart';
import '../params/exposure_params.dart';

class ExposurePanel extends StatelessWidget {
  const ExposurePanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final ExposureParams value;
  final ValueChanged<ExposureParams> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 曝光度（EV）
          CommonSlider(
            label: '曝光度 (EV)',
            value: value.ev,
            min: -4.0, max: 4.0, neutral: 0.0,
            decimals: 2,
            onChanged: (v) => onChanged(value.copyWith(ev: v)),
            onCommit: onCommit,
          ),
          // 位移（加法偏移）
          CommonSlider(
            label: '位移',
            value: value.offset,
            min: -0.5, max: 0.5, neutral: 0.0,
            decimals: 3,
            onChanged: (v) => onChanged(value.copyWith(offset: v)),
            onCommit: onCommit,
          ),
          // 灰度系数（Gamma）
          CommonSlider(
            label: '灰度系数 (γ)',
            value: value.gamma,
            min: 0.10, max: 3.00, neutral: 1.00,
            decimals: 2,
            onChanged: (v) => onChanged(value.copyWith(gamma: v)),
            onCommit: onCommit,
          ),
        ],
      ),
    );
  }
}
