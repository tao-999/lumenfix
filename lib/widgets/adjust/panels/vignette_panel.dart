import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class VignettePanel extends StatelessWidget {
  const VignettePanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final v = params.vignette;
    return CommonScroller(children: [
      CommonSlider(label:'强度', value: v.amount, min:-100, max:100, neutral:0,
          onChanged:(x)=> onChanged(params.clone()..vignette=v.copyWith(amount:x)), onCommit:onCommit),
      CommonSlider(label:'半径', value: v.radius, min:.1, max:1.0, neutral:.75,
          onChanged:(x)=> onChanged(params.clone()..vignette=v.copyWith(radius:x)), decimals:2, onCommit:onCommit),
      CommonSlider(label:'圆角', value: v.roundness, min:0, max:1, neutral:0,
          onChanged:(x)=> onChanged(params.clone()..vignette=v.copyWith(roundness:x)), decimals:2, onCommit:onCommit),
      CommonSlider(label:'羽化', value: v.feather, min:.05, max:1.0, neutral:.5,
          onChanged:(x)=> onChanged(params.clone()..vignette=v.copyWith(feather:x)), decimals:2, onCommit:onCommit),
      CommonSlider(label:'中心X', value: v.cx, min:-1, max:1, neutral:0,
          onChanged:(x)=> onChanged(params.clone()..vignette=v.copyWith(cx:x)), decimals:2, onCommit:onCommit),
      CommonSlider(label:'中心Y', value: v.cy, min:-1, max:1, neutral:0,
          onChanged:(x)=> onChanged(params.clone()..vignette=v.copyWith(cy:x)), decimals:2, onCommit:onCommit),
    ]);
  }
}
