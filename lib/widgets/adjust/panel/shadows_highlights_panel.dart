import 'package:flutter/material.dart';
import '../common.dart';
import '../params/shadows_highlights_params.dart';

class ShadowsHighlightsPanel extends StatelessWidget {
  const ShadowsHighlightsPanel({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ShadowsHighlightsParams value;
  final ValueChanged<ShadowsHighlightsParams> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CommonSection('阴影'),
          CommonSlider(
            label: '数量',
            value: value.shAmount, min: -100, max: 100, neutral: 0,
            onChanged: (v) => onChanged(value.copyWith(shAmount: v)),
            onCommit: () {},
          ),
          CommonSlider(
            label: 'Tone',
            value: value.shTone, min: 0, max: 100, neutral: 25,
            onChanged: (v) => onChanged(value.copyWith(shTone: v)),
            onCommit: () {},
          ),
          CommonSlider(
            label: '半径（px）',
            value: value.shRadius, min: 0, max: 200, neutral: 12, decimals: 0,
            onChanged: (v) => onChanged(value.copyWith(shRadius: v)),
            onCommit: () {},
          ),

          const SizedBox(height: 8),
          const CommonSection('高光'),
          CommonSlider(
            label: '数量',
            value: value.hiAmount, min: -100, max: 100, neutral: 0,
            onChanged: (v) => onChanged(value.copyWith(hiAmount: v)),
            onCommit: () {},
          ),
          CommonSlider(
            label: 'Tone',
            value: value.hiTone, min: 0, max: 100, neutral: 25,
            onChanged: (v) => onChanged(value.copyWith(hiTone: v)),
            onCommit: () {},
          ),
          CommonSlider(
            label: '半径（px）',
            value: value.hiRadius, min: 0, max: 200, neutral: 12, decimals: 0,
            onChanged: (v) => onChanged(value.copyWith(hiRadius: v)),
            onCommit: () {},
          ),

          const SizedBox(height: 8),
          const CommonSection('调整'),
          CommonSlider(
            label: '颜色',
            value: value.color, min: -100, max: 100, neutral: 0,
            onChanged: (v) => onChanged(value.copyWith(color: v)),
            onCommit: () {},
          ),
        ],
      ),
    );
  }
}
