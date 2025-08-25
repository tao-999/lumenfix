import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class BloomPanel extends StatelessWidget {
  const BloomPanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final b = params.bloom;
    return CommonScroller(children: [
      CommonSlider(label:'阈值', value: b.threshold, min:0.0, max:1.0, neutral:.8,
          onChanged:(v)=> onChanged(params.clone()..bloom=b.copyWith(threshold:v)), decimals:2, onCommit:onCommit),
      CommonSlider(label:'强度', value: b.intensity, min:0, max:200, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..bloom=b.copyWith(intensity:v)), onCommit:onCommit),
      CommonSlider(label:'半径', value: b.radius.toDouble(), min:1, max:80, neutral:20,
          onChanged:(v)=> onChanged(params.clone()..bloom=b.copyWith(radius:v)), onCommit:onCommit),
    ]);
  }
}
