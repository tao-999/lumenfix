// lib/widgets/filters/panels/panel_pixelate.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'panel_common.dart';
import '../engine/engine_pixelate.dart';

class PanelPixelate extends StatelessWidget {
  const PanelPixelate({
    super.key,
    required this.img,
    required this.selectedId,
    required this.onPick, // 回传 EffectHandle
  });

  final ui.Image img;
  final String? selectedId;
  final void Function(EffectHandle) onPick;

  @override
  Widget build(BuildContext context) {
    return PanelGrid<PixelateSpec>(
      img: img,
      items: _pxPresets20,
      selectedId: selectedId,
      idOf: (e) => e.id,
      renderRgba: (base, w, h, e) => enginePixelate(base, w, h, e),
      onPick: (e) => onPick(
        EffectHandle(
          e.id,
              (rgba, w, h) => enginePixelate(Uint8List.fromList(rgba), w, h, e),
        ),
      ),
    );
  }
}

// ===== 20 个像素化预设（差异明显）=====
const List<PixelateSpec> _pxPresets20 = [
  PixelateSpec(id: 'px_细_4',   name: '细·4px',    size: 4,  levels: 0,  centerSample: false),
  PixelateSpec(id: 'px_细_6',   name: '细·6px',    size: 6,  levels: 0,  centerSample: false),
  PixelateSpec(id: 'px_细_8',   name: '细·8px',    size: 8,  levels: 0,  centerSample: false),
  PixelateSpec(id: 'px_中_10',  name: '中·10px',   size: 10, levels: 0,  centerSample: false),
  PixelateSpec(id: 'px_中_12',  name: '中·12px',   size: 12, levels: 0,  centerSample: false),
  PixelateSpec(id: 'px_中_14',  name: '中·14px',   size: 14, levels: 0,  centerSample: false),
  PixelateSpec(id: 'px_粗_16',  name: '粗·16px',   size: 16, levels: 0,  centerSample: false),
  PixelateSpec(id: 'px_粗_20',  name: '粗·20px',   size: 20, levels: 0,  centerSample: false),
  PixelateSpec(id: 'px_粗_24',  name: '粗·24px',   size: 24, levels: 0,  centerSample: false),
  PixelateSpec(id: 'px_巨_32',  name: '巨·32px',   size: 32, levels: 0,  centerSample: false),

  // 低级量化（复古 8-bit 味）
  PixelateSpec(id: 'px_复古_32级_6',  name: '复古·32级(6px)', size: 6,  levels: 32, centerSample: false),
  PixelateSpec(id: 'px_复古_16级_8',  name: '复古·16级(8px)', size: 8,  levels: 16, centerSample: false),
  PixelateSpec(id: 'px_复古_12级_10', name: '复古·12级(10px)',size: 10, levels: 12, centerSample: false),
  PixelateSpec(id: 'px_8位_8级_12',   name: '8位·8级(12px)', size: 12, levels: 8,  centerSample: false),
  PixelateSpec(id: 'px_8位_6级_14',   name: '8位·6级(14px)', size: 14, levels: 6,  centerSample: false),
  PixelateSpec(id: 'px_8位_5级_16',   name: '8位·5级(16px)', size: 16, levels: 5,  centerSample: false),
  PixelateSpec(id: 'px_8位_4级_20',   name: '8位·4级(20px)', size: 20, levels: 4,  centerSample: false),
  PixelateSpec(id: 'px_极简_3级_24',  name: '极简·3级(24px)',size: 24, levels: 3,  centerSample: false),
  PixelateSpec(id: 'px_双色块_28',    name: '双色块(28px)',  size: 28, levels: 2,  centerSample: false),

  // 自适应网格数（根据宽度划分），中心采样风格更“颗粒”
  PixelateSpec(id: 'px_格60_中心',    name: '格60·中心',    gridX: 60, levels: 0, centerSample: true),
];
