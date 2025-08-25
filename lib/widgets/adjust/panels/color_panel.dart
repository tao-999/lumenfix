import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class ColorPanel extends StatelessWidget {
  const ColorPanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) => CommonScroller(children: [
    CommonSlider(label: '饱和度', value: params.saturation, min: -100, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..saturation=v), onCommit: onCommit),
    CommonSlider(label: '鲜艳度', value: params.vibrance, min: -100, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..vibrance=v), onCommit: onCommit),
    CommonSlider(label: '色温', value: params.temperature, min: -100, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..temperature=v), onCommit: onCommit),
    CommonSlider(label: '色调', value: params.tint, min: -100, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..tint=v), onCommit: onCommit),
  ]);
}
