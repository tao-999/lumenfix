import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class DenoisePanel extends StatelessWidget {
  const DenoisePanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final d = params.denoiseAdv;
    return CommonScroller(children: [
      CommonSlider(label:'亮度', value: d.luma, min:0, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..denoiseAdv=d.copyWith(luma:v)), onCommit:onCommit),
      CommonSlider(label:'色度', value: d.chroma, min:0, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..denoiseAdv=d.copyWith(chroma:v)), onCommit:onCommit),
    ]);
  }
}
