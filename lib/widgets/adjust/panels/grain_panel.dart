import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class GrainPanel extends StatelessWidget {
  const GrainPanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final g = params.grain;
    return CommonScroller(children: [
      CommonSlider(label:'强度', value: g.amount, min:0, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..grain=g.copyWith(amount:v)), onCommit:onCommit),
      CommonSlider(label:'粒径', value: g.size, min:.5, max:8.0, neutral:1.0,
          onChanged:(v)=> onChanged(params.clone()..grain=g.copyWith(size:v)), decimals:2, onCommit:onCommit),
      CommonSlider(label:'粗糙', value: g.roughness, min:0, max:1.0, neutral:.5,
          onChanged:(v)=> onChanged(params.clone()..grain=g.copyWith(roughness:v)), decimals:2, onCommit:onCommit),
    ]);
  }
}
