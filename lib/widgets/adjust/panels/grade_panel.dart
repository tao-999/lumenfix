import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class GradePanel extends StatelessWidget {
  const GradePanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final g = params.grade;
    GradeWheel _sw(GradeWheel w,{double? h,double? s,double? l}) =>
        GradeWheel(hue: h??w.hue, sat: s??w.sat, lum: l??w.lum);

    return CommonScroller(children: [
      const CommonSection('阴影'),
      CommonSlider(label:'色相（度）', value: g.shadows.hue, min:-180, max:180, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(shadows:_sw(g.shadows,h:v))), onCommit:onCommit),
      CommonSlider(label:'饱和', value: g.shadows.sat, min:-100, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(shadows:_sw(g.shadows,s:v))), onCommit:onCommit),
      CommonSlider(label:'亮度', value: g.shadows.lum, min:-100, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(shadows:_sw(g.shadows,l:v))), onCommit:onCommit),

      const CommonSection('中间'),
      CommonSlider(label:'色相（度）', value: g.mids.hue, min:-180, max:180, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(mids:_sw(g.mids,h:v))), onCommit:onCommit),
      CommonSlider(label:'饱和', value: g.mids.sat, min:-100, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(mids:_sw(g.mids,s:v))), onCommit:onCommit),
      CommonSlider(label:'亮度', value: g.mids.lum, min:-100, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(mids:_sw(g.mids,l:v))), onCommit:onCommit),

      const CommonSection('高光'),
      CommonSlider(label:'色相（度）', value: g.highs.hue, min:-180, max:180, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(highs:_sw(g.highs,h:v))), onCommit:onCommit),
      CommonSlider(label:'饱和', value: g.highs.sat, min:-100, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(highs:_sw(g.highs,s:v))), onCommit:onCommit),
      CommonSlider(label:'亮度', value: g.highs.lum, min:-100, max:100, neutral:0,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(highs:_sw(g.highs,l:v))), onCommit:onCommit),

      const CommonSection('范围'),
      CommonSlider(label:'阴影枢轴', value: g.shadowPivot, min:0.0, max:0.5, neutral:0.25,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(sp:v)), decimals:2, onCommit:onCommit),
      CommonSlider(label:'高光枢轴', value: g.highPivot, min:0.5, max:1.0, neutral:0.75,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(hp:v)), decimals:2, onCommit:onCommit),
      CommonSlider(label:'软化', value: g.softness, min:0.05, max:0.5, neutral:0.2,
          onChanged:(v)=> onChanged(params.clone()..grade=g.copyWith(sf:v)), decimals:2, onCommit:onCommit),
    ]);
  }
}
