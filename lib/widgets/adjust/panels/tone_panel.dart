import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class TonePanel extends StatelessWidget {
  const TonePanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params;
  final ValueChanged<AdjustParams> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) => CommonScroller(children: [
    CommonSlider(label: '曝光', value: params.exposure, min: -2, max: 2, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..exposure=v), onCommit: onCommit, decimals: 2),
    CommonSlider(label: '对比度', value: params.contrast, min: -100, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..contrast=v), onCommit: onCommit),
    CommonSlider(label: '高光', value: params.highlights, min: -100, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..highlights=v), onCommit: onCommit),
    CommonSlider(label: '阴影', value: params.shadows, min: -100, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..shadows=v), onCommit: onCommit),
    CommonSlider(label: '白场', value: params.whites, min: -100, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..whites=v), onCommit: onCommit),
    CommonSlider(label: '黑场', value: params.blacks, min: -100, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..blacks=v), onCommit: onCommit),
    CommonSlider(label: '伽马（中间调）', value: params.gamma, min: 0.5, max: 1.5, neutral: 1.0,
        onChanged: (v)=> onChanged(params.clone()..gamma=v), onCommit: onCommit, decimals: 2),
  ]);
}
