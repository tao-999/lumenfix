import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'panel_common.dart';
import '../engine/engine_stylize.dart';

class PanelStylize extends StatelessWidget {
  const PanelStylize({
    super.key,
    required this.img,
    required this.selectedId,
    required this.onPick,
  });

  final ui.Image img;
  final String? selectedId;
  final void Function(EffectHandle) onPick;

  @override
  Widget build(BuildContext context) {
    final items = _stylizeItems;
    return PanelGrid<EffectHandle>(
      img: img,
      items: items,
      selectedId: selectedId,
      idOf: (e) => e.id,
      onPick: onPick,
      renderRgba: (base, w, h, e) => e.render(base, w, h), // ✅ 统一用 render
    );
  }
}

final List<EffectHandle> _stylizeItems = [
  EffectHandle('风格_卡通',               (b,w,h) => stylizeCartoon(b,w,h)),
  EffectHandle('风格_卡通厚描',           (b,w,h) => stylizeCartoonBold(b,w,h)),
  EffectHandle('风格_彩绘水彩',           (b,w,h) => stylizeWatercolor(b,w,h)),
  EffectHandle('风格_水粉',               (b,w,h) => stylizeGouache(b,w,h)),
  EffectHandle('风格_油画',               (b,w,h) => stylizeOil(b,w,h)),
  EffectHandle('风格_粉彩',               (b,w,h) => stylizePastel(b,w,h)),
  EffectHandle('风格_彩铅素描',           (b,w,h) => stylizeSketchColor(b,w,h)),
  EffectHandle('风格_铅笔黑白',           (b,w,h) => stylizeSketchBW(b,w,h)),
  EffectHandle('风格_木炭',               (b,w,h) => stylizeCharcoal(b,w,h)),
  EffectHandle('风格_墨线',               (b,w,h) => stylizeInk(b,w,h)),
  EffectHandle('风格_雕塑',               (b,w,h) => stylizeSculpt(b,w,h)),
  EffectHandle('风格_浮雕',               (b,w,h) => stylizeRelief(b,w,h)),
  EffectHandle('风格_霓虹',               (b,w,h) => stylizeNeon(b,w,h)),
  EffectHandle('风格_荧光描边',           (b,w,h) => stylizeGlowEdge(b,w,h)),
  EffectHandle('风格_点彩',               (b,w,h) => stylizePointillism(b,w,h)),
  EffectHandle('风格_马赛克彩绘',         (b,w,h) => stylizeMosaicPaint(b,w,h)),
  EffectHandle('风格_强海报',             (b,w,h) => stylizePoster(b,w,h)),
  EffectHandle('风格_赛璐璐',             (b,w,h) => stylizeFlat(b,w,h)),
  EffectHandle('风格_波普',               (b,w,h) => stylizePopArt(b,w,h)),
  EffectHandle('风格_复古彩绘',           (b,w,h) => stylizeSepiaPaint(b,w,h)),
  EffectHandle('风格_蜡笔',               (b,w,h) => stylizeCrayon(b,w,h)),
];
