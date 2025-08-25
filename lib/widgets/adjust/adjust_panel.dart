import 'package:flutter/material.dart';
import 'adjust_params.dart';

import 'panels/common.dart';
import 'panels/tone_panel.dart';
import 'panels/color_panel.dart';
import 'panels/presence_panel.dart';
import 'panels/hsl_panel.dart';
import 'panels/curves_panel.dart';
import 'panels/split_panel.dart';
import 'panels/texture_panel.dart';
import 'panels/sharpen_panel.dart';
import 'panels/denoise_panel.dart';
import 'panels/bloom_panel.dart';
import 'panels/vignette_panel.dart';
import 'panels/grain_panel.dart';
import 'panels/optics_panel.dart';
import 'panels/geometry_panel.dart';
import 'panels/lut_panel.dart';

enum AdjustGroup {
  tone, color, presence,
  hsl, curves, split,
  texture, sharpen, denoise,
  bloom, vignette, grain,
  optics, geometry, lut,
}

class AdjustPanel extends StatelessWidget {
  const AdjustPanel({
    super.key,
    required this.params,
    required this.onChanged,
    required this.onChangeEnd,
    required this.group,
    required this.onGroupChange,
    required this.onReset, // 不在这里渲染
    required this.rebuilding,
  });

  final AdjustParams params;
  final ValueChanged<AdjustParams> onChanged;
  final ValueChanged<AdjustParams> onChangeEnd;
  final AdjustGroup group;
  final ValueChanged<AdjustGroup> onGroupChange;
  final VoidCallback onReset;
  final bool rebuilding;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height / 3.0;

    Widget body = switch (group) {
      AdjustGroup.tone     => TonePanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.color    => ColorPanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.presence => PresencePanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.hsl      => HslPanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.curves   => CurvesPanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.split    => SplitPanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.texture  => TexturePanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.sharpen  => SharpenPanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.denoise  => DenoisePanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.bloom    => BloomPanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.vignette => VignettePanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.grain    => GrainPanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.optics   => OpticsPanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.geometry => GeometryPanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
      AdjustGroup.lut      => LutPanel(params: params, onChanged: onChanged, onCommit: ()=>onChangeEnd(params)),
    };

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.85),
          border: const Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 38,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(children: [
                        _tab('色调', AdjustGroup.tone),
                        _tab('颜色', AdjustGroup.color),
                        _tab('质感', AdjustGroup.presence),
                        _tab('HSL', AdjustGroup.hsl),
                        _tab('曲线', AdjustGroup.curves),
                        _tab('分离色调', AdjustGroup.split),
                        _tab('纹理', AdjustGroup.texture),
                        _tab('锐化', AdjustGroup.sharpen),
                        _tab('降噪', AdjustGroup.denoise),
                        _tab('Bloom', AdjustGroup.bloom),
                        _tab('暗角', AdjustGroup.vignette),
                        _tab('颗粒', AdjustGroup.grain),
                        _tab('光学', AdjustGroup.optics),
                        _tab('LUT', AdjustGroup.lut),
                      ].map((w)=>Padding(padding: const EdgeInsets.only(right:8), child:w)).toList()),
                    ),
                  ),
                  if (rebuilding)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _tab(String text, AdjustGroup g) =>
      CommonChip(text: text, selected: group == g, onTap: () => onGroupChange(g));
}
