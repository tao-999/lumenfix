// lib/widgets/filters/panels/panel_distort.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'panel_common.dart';
import '../engine/engine_distort.dart';

class PanelDistort extends StatelessWidget {
  const PanelDistort({
    super.key,
    required this.img,
    required this.selectedId,
    required this.onPick, // 回传 EffectHandle（不再有全局 effect 组件）
  });

  final ui.Image img;
  final String? selectedId;
  final void Function(EffectHandle) onPick;

  @override
  Widget build(BuildContext context) {
    return PanelGrid<DistortSpec>(
      img: img,
      items: _distort20,
      selectedId: selectedId,
      idOf: (e) => e.id,
      // 渲染缩略：直接调本引擎
      renderRgba: (base, w, h, e) => engineDistort(base, w, h, e),
      onPick: (e) => onPick(
        EffectHandle(
          e.id,
          // 预览/导出用同一逻辑
              (rgba, w, h) => engineDistort(Uint8List.fromList(rgba), w, h, e),
        ),
      ),
    );
  }
}

// ===== 20 个“扭曲”预设（差异明显，全中文名）=====
const List<DistortSpec> _distort20 = [
  DistortSpec(id: 'dist_桶形_轻',   name: '桶形·轻',   type: 'barrel',     amount: 0.20, radius: 1.10),
  DistortSpec(id: 'dist_桶形_重',   name: '桶形·重',   type: 'barrel',     amount: 0.60, radius: 1.10),
  DistortSpec(id: 'dist_枕形_轻',   name: '枕形·轻',   type: 'pincushion', amount: 0.22, radius: 1.10),
  DistortSpec(id: 'dist_枕形_重',   name: '枕形·重',   type: 'pincushion', amount: 0.65, radius: 1.10),
  DistortSpec(id: 'dist_鼓包_中心', name: '鼓包·中心', type: 'bulge',       amount: 0.55, radius: 0.85),
  DistortSpec(id: 'dist_鼓包_小半径',name: '鼓包·小半径', type: 'bulge',     amount: 0.75, radius: 0.45),
  DistortSpec(id: 'dist_内凹_中心', name: '内凹·中心', type: 'pinch',       amount: 0.50, radius: 0.90),
  DistortSpec(id: 'dist_内凹_强烈', name: '内凹·强烈', type: 'pinch',       amount: 0.80, radius: 0.70),
  DistortSpec(id: 'dist_旋涡_小角', name: '旋涡·小角', type: 'swirl',       amount: 0.80, angle: 25, radius: 1.00),
  DistortSpec(id: 'dist_旋涡_大角', name: '旋涡·大角', type: 'swirl',       amount: 1.00, angle: 60, radius: 1.00),
  DistortSpec(id: 'dist_旋涡_偏左上',name: '旋涡·偏左上', type: 'swirl',     amount: 0.90, angle: 45, radius: 0.85, cx: .38, cy: .38),
  DistortSpec(id: 'dist_波纹_细',   name: '波纹·细',   type: 'ripple',     freq: 12, amp: 6,  amount: 1.0, radius: 1.00),
  DistortSpec(id: 'dist_波纹_粗',   name: '波纹·粗',   type: 'ripple',     freq: 6,  amp: 12, amount: 1.0, radius: 1.00),
  DistortSpec(id: 'dist_横波',     name: '横波',     type: 'waveX',      freq: 10, amp: 8,  amount: 1.0, phase: 0.0),
  DistortSpec(id: 'dist_横波_强',   name: '横波·强',   type: 'waveX',      freq: 16, amp: 14, amount: 1.0, phase: 0.6),
  DistortSpec(id: 'dist_竖波',     name: '竖波',     type: 'waveY',      freq: 10, amp: 8,  amount: 1.0, phase: 0.0),
  DistortSpec(id: 'dist_竖波_强',   name: '竖波·强',   type: 'waveY',      freq: 16, amp: 14, amount: 1.0, phase: 0.6),
  DistortSpec(id: 'dist_球化',     name: '球化',     type: 'spherize',   amount: 0.60, radius: 0.85),
  DistortSpec(id: 'dist_鱼眼_轻',   name: '鱼眼·轻',   type: 'fisheye',    amount: 0.30, radius: 0.95),
  DistortSpec(id: 'dist_鱼眼_重',   name: '鱼眼·重',   type: 'fisheye',    amount: 0.85, radius: 0.85),
];
