import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class OpticsPanel extends StatelessWidget {
  const OpticsPanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final l = params.lens;
    return CommonScroller(children: [
      CommonSlider(label:'畸变', value: l.distortion, min:-100, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..lens=l.copyWith(distortion:v)), onCommit:onCommit),
      CommonSlider(label:'边角补偿', value: l.vignettingComp, min:-100, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..lens=l.copyWith(vignettingComp:v)), onCommit:onCommit),
      CommonSlider(label:'红色差（px）', value: l.caRed, min:-5, max:5, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..lens=l.copyWith(caRed:v)), onCommit:onCommit),
      CommonSlider(label:'蓝色差（px）', value: l.caBlue, min:-5, max:5, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..lens=l.copyWith(caBlue:v)), onCommit:onCommit),
    ]);
  }
}
