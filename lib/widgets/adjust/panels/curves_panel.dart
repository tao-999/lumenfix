import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

enum _CurveChan { luma, r, g, b }

class CurvesPanel extends StatefulWidget {
  const CurvesPanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;
  @override State<CurvesPanel> createState() => _CurvesPanelState();
}

class _CurvesPanelState extends State<CurvesPanel> {
  _CurveChan _chan = _CurveChan.luma;

  @override
  Widget build(BuildContext context) {
    final c = widget.params.curves;
    final pts = _chanPts(c, _chan);
    return CommonScroller(children: [
      CommonSubTabs(tabs: [
        CommonChip(text:'Luma', selected: _chan==_CurveChan.luma, onTap: ()=>setState(()=>_chan=_CurveChan.luma)),
        CommonChip(text:'R',    selected: _chan==_CurveChan.r,    onTap: ()=>setState(()=>_chan=_CurveChan.r)),
        CommonChip(text:'G',    selected: _chan==_CurveChan.g,    onTap: ()=>setState(()=>_chan=_CurveChan.g)),
        CommonChip(text:'B',    selected: _chan==_CurveChan.b,    onTap: ()=>setState(()=>_chan=_CurveChan.b)),
      ]),
      CommonSlider(label:'阴影', value: pts[0].y, min: 0, max: 1, neutral: 0,
          onChanged: (v)=> _setCurve(_chan, 0, v), onCommit: widget.onCommit, decimals: 2),
      CommonSlider(label:'中间', value: pts[1].y, min: 0, max: 1, neutral: .5,
          onChanged: (v)=> _setCurve(_chan, 1, v), onCommit: widget.onCommit, decimals: 2),
      CommonSlider(label:'高光', value: pts[2].y, min: 0, max: 1, neutral: 1,
          onChanged: (v)=> _setCurve(_chan, 2, v), onCommit: widget.onCommit, decimals: 2),
    ]);
  }

  List<CurvePt> _chanPts(ToneCurves c, _CurveChan ch){
    final src = switch(ch){ _CurveChan.luma=>c.luma, _CurveChan.r=>c.r, _CurveChan.g=>c.g, _CurveChan.b=>c.b };
    List<CurvePt> pts = src.isEmpty ? const [CurvePt(0,0), CurvePt(1,1)] : List<CurvePt>.from(src);
    double _getY(double x){
      for (int i=0;i<pts.length-1;i++){ final p0=pts[i], p1=pts[i+1];
      if (x>=p0.x && x<=p1.x){ final t=(x-p0.x)/(p1.x-p0.x); return p0.y*(1-t)+p1.y*t; } }
      return x<=pts.first.x?pts.first.y:pts.last.y;
    }
    return [0.25,0.5,0.75].map((x)=>CurvePt(x,_getY(x))).toList();
  }

  void _setCurve(_CurveChan ch, int idx, double y){
    final p = widget.params.clone();
    ToneCurves c = p.curves;
    double _pickY(List<CurvePt> src, double x){
      if (src.isEmpty) return x;
      final s=[...src]..sort((a,b)=>a.x.compareTo(b.x));
      for (int i=0;i<s.length-1;i++){ final p0=s[i], p1=s[i+1];
      if (x>=p0.x && x<=p1.x){ final t=(x-p0.x)/(p1.x-p0.x); return (p0.y*(1-t)+p1.y*t).clamp(0.0,1.0); } }
      return x;
    }
    List<CurvePt> _apply(List<CurvePt> src){
      return <CurvePt>[
        const CurvePt(0,0),
        CurvePt(.25, idx==0? y.clamp(0.0,1.0) : _pickY(src,.25)),
        CurvePt(.5 , idx==1? y.clamp(0.0,1.0) : _pickY(src,.5 )),
        CurvePt(.75, idx==2? y.clamp(0.0,1.0) : _pickY(src,.75)),
        const CurvePt(1,1),
      ];
    }
    switch(ch){
      case _CurveChan.luma: c=ToneCurves(_apply(c.luma), c.r, c.g, c.b); break;
      case _CurveChan.r:    c=ToneCurves(c.luma, _apply(c.r), c.g, c.b); break;
      case _CurveChan.g:    c=ToneCurves(c.luma, c.r, _apply(c.g), c.b); break;
      case _CurveChan.b:    c=ToneCurves(c.luma, c.r, c.g, _apply(c.b)); break;
    }
    p.curves=c; widget.onChanged(p);
  }
}
