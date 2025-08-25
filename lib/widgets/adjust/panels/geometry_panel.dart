import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class GeometryPanel extends StatelessWidget {
  const GeometryPanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final g = params.geo;
    return CommonScroller(children: [
      CommonSlider(label:'旋转（°）', value: g.rotate, min:-360, max:360, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..geo=g.copyWith(rotate:v)), onCommit:onCommit),
      CommonSlider(label:'水平透视', value: g.perspX, min:-1.0, max:1.0, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..geo=g.copyWith(perspX:v)), decimals:2, onCommit:onCommit),
      CommonSlider(label:'垂直透视', value: g.perspY, min:-1.0, max:1.0, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..geo=g.copyWith(perspY:v)), decimals:2, onCommit:onCommit),
      CommonSlider(label:'缩放', value: g.scale, min:0.5, max:2.0, neutral:1.0,
          onChanged:(v)=> onChanged(params.clone()..geo=g.copyWith(scale:v)), decimals:2, onCommit:onCommit),
    ]);
  }
}
