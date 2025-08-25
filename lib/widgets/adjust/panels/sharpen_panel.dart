import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class SharpenPanel extends StatelessWidget {
  const SharpenPanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final u = params.usm;
    return CommonScroller(children: [
      CommonSlider(label:'量', value: u.amount, min:0, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..usm=u.copyWith(amount:v)), onCommit:onCommit),
      CommonSlider(label:'半径', value: u.radius, min:.5, max:6.0, neutral:1.0,
          onChanged:(v)=> onChanged(params.clone()..usm=u.copyWith(radius:v)), decimals:2, onCommit:onCommit),
      CommonSlider(label:'阈值', value: u.threshold, min:0, max:255, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..usm=u.copyWith(threshold:v)), onCommit:onCommit),
    ]);
  }
}
