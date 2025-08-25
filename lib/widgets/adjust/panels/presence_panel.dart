import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class PresencePanel extends StatelessWidget {
  const PresencePanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) => CommonScroller(children: [
    CommonSlider(label: '清晰度', value: params.clarity, min: -100, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..clarity=v), onCommit: onCommit),
    CommonSlider(label: '锐化（旧）', value: params.sharpness, min: 0, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..sharpness=v), onCommit: onCommit),
    CommonSlider(label: '降噪（旧）', value: params.denoise, min: 0, max: 100, neutral: 0,
        onChanged: (v)=> onChanged(params.clone()..denoise=v), onCommit: onCommit),
  ]);
}
