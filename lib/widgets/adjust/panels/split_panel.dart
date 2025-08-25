import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class SplitPanel extends StatelessWidget {
  const SplitPanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final s = params.split;
    return CommonScroller(children: [
      const CommonSection('阴影'),
      CommonSlider(label:'色相（度）', value: s.sHue, min:-180, max:180, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..split=s.copyWith(sHue:v)), onCommit:onCommit),
      CommonSlider(label:'饱和', value: s.sSat, min:-100, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..split=s.copyWith(sSat:v)), onCommit:onCommit),

      const CommonSection('高光'),
      CommonSlider(label:'色相（度）', value: s.hHue, min:-180, max:180, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..split=s.copyWith(hHue:v)), onCommit:onCommit),
      CommonSlider(label:'饱和', value: s.hSat, min:-100, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..split=s.copyWith(hSat:v)), onCommit:onCommit),

      CommonSlider(label:'平衡', value: s.balance, min:-100, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..split=s.copyWith(balance:v)), onCommit:onCommit),
    ]);
  }
}
