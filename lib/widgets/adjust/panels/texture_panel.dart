import 'package:flutter/material.dart';
import '../adjust_params.dart';
import 'common.dart';

class TexturePanel extends StatelessWidget {
  const TexturePanel({super.key, required this.params, required this.onChanged, required this.onCommit});
  final AdjustParams params; final ValueChanged<AdjustParams> onChanged; final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) => CommonScroller(children: [
    CommonSlider(label:'纹理', value: params.texture, min:-100, max:100, neutral:0,
        onChanged:(v)=> onChanged(params.clone()..texture=v), onCommit:onCommit),
    CommonSlider(label:'清晰度', value: params.clarity, min:-100, max:100, neutral:0,
        onChanged:(v)=> onChanged(params.clone()..clarity=v), onCommit:onCommit),
  ]);
}
