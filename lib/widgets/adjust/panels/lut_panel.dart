import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class LutPanel extends StatefulWidget {
  const LutPanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;
  @override State<LutPanel> createState() => _LutPanelState();
}

class _LutPanelState extends State<LutPanel> {
  late final TextEditingController _ctrl;
  @override void initState(){ super.initState(); _ctrl = TextEditingController(text: widget.params.lut.id); }
  @override void didUpdateWidget(covariant LutPanel old){ super.didUpdateWidget(old);
  if (old.params.lut.id != widget.params.lut.id) _ctrl.text = widget.params.lut.id; }
  @override void dispose(){ _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.params.lut;
    return CommonScroller(children: [
      Row(children: [
        const SizedBox(width: 92, child: Text('LUT ID', style: TextStyle(color: Colors.white70))),
        Expanded(child: TextField(
          controller: _ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            hintText: '内置/外部 LUT 标识',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true, fillColor: Colors.white12,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onChanged: (s)=> widget.onChanged(widget.params.clone()..lut = cfg.copyWith(id: s)),
          onEditingComplete: widget.onCommit,
        )),
      ]),
      CommonSlider(label:'强度', value: cfg.strength, min:0.0, max:1.0, neutral:0.0,
          onChanged:(v)=> widget.onChanged(widget.params.clone()..lut = cfg.copyWith(strength:v)),
          decimals: 2, onCommit: widget.onCommit),
    ]);
  }
}
