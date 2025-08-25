import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class HslPanel extends StatefulWidget {
  const HslPanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;
  @override State<HslPanel> createState() => _HslPanelState();
}

class _HslPanelState extends State<HslPanel> {
  HslBand _band = HslBand.red;

  @override
  Widget build(BuildContext context) {
    final cur = widget.params.hsl.bands[_band]!;

    return CommonScroller(children: [
      CommonSlider(label:'色相（度）', value: cur.hue, min: -180, max: 180, neutral: 0,
          onChanged: (v){ final p=widget.params.clone(); final m=Map<HslBand,HslAdjust>.from(p.hsl.bands);
          m[_band]=HslAdjust(hue:v, sat:cur.sat, lum:cur.lum); p.hsl=HslTable(m); widget.onChanged(p); },
          onCommit: widget.onCommit),
      CommonSlider(label:'饱和', value: cur.sat, min: -100, max: 100, neutral: 0,
          onChanged: (v){ final p=widget.params.clone(); final m=Map<HslBand,HslAdjust>.from(p.hsl.bands);
          m[_band]=HslAdjust(hue:cur.hue, sat:v, lum:cur.lum); p.hsl=HslTable(m); widget.onChanged(p); },
          onCommit: widget.onCommit),
      CommonSlider(label:'亮度', value: cur.lum, min: -100, max: 100, neutral: 0,
          onChanged: (v){ final p=widget.params.clone(); final m=Map<HslBand,HslAdjust>.from(p.hsl.bands);
          m[_band]=HslAdjust(hue:cur.hue, sat:cur.sat, lum:v); p.hsl=HslTable(m); widget.onChanged(p); },
          onCommit: widget.onCommit),
    ]);
  }
}
