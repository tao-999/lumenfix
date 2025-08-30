// 📄 lib/widgets/face/panels/makeup_panel.dart
import 'package:flutter/material.dart';
import '../engine/face_regions.dart';
import 'panel_common.dart';
import 'lip_palette_sheet.dart'; // ✅ 你的颜色选择弹框

/// 上妆（只作用在唇部区域：outer - inner）
class MakeupPanel extends StatelessWidget {
  const MakeupPanel({
    super.key,
    required this.params,
    required this.onChanged,
    this.regions,
  });

  final FaceParams params;
  final ValueChanged<FaceParams> onChanged;
  final FaceRegions? regions;

  // 快捷常用色（粉/红系）
  static const _quickPresets = <Color>[
    Color(0xFFF28AA0),
    Color(0xFFE35D6A),
    Color(0xFFD94B69),
    Color(0xFFB83A5D),
    Color(0xFFA22052),
    Color(0xFF8E1D47),
  ];

  Future<void> _openAllPalette(BuildContext context) async {
    final chosen = await showModalBottomSheet<Color>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => LipPaletteSheet(initial: params.lipColor),
    );
    if (chosen != null) {
      // 选色即开启；若当前强度为0，给一个默认可见值 0.3
      final nextAlpha = params.lipAlpha > 0 ? params.lipAlpha : 0.3;
      onChanged(
        params.copyWith(
          lipColor: chosen,
          lipOn: true,
          lipAlpha: nextAlpha.clamp(0, 0.5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final noLips = (regions?.lipsOuterPath ??
        regions?.lipsInnerPath ??
        regions?.lipsPath) == null;
    final enableAlpha = params.lipOn && !noLips;

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        if (noLips)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: Text('未识别到唇部区域', style: TextStyle(color: Colors.white70)),
            ),
          ),

        // —— 颜色行：第一个是“全量颜色器”，后面是常用快捷色 —— //
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.color_lens, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              const Text('唇色', style: TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // 全量颜色器入口（第一个圆）
                      _PaletteOpener(onTap: () => _openAllPalette(context)),
                      const SizedBox(width: 10),

                      // 快捷色
                      ..._quickPresets.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _Swatch(
                          color: c,
                          selected: params.lipOn && c.value == params.lipColor.value,
                          onTap: () {
                            final nextAlpha = params.lipAlpha > 0 ? params.lipAlpha : 0.3;
                            onChanged(
                              params.copyWith(
                                lipColor: c,
                                lipOn: true,
                                lipAlpha: nextAlpha.clamp(0, 0.5),
                              ),
                            );
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 提示：未启用时先选色
        if (!enableAlpha)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('先选择唇色，再调强度', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),

        // 强度 0~0.5，未启用时禁用滑条
        SliderTile(
          icon: Icons.opacity,
          title: '唇彩强度',
          value: params.lipAlpha.clamp(0, 0.5),
          min: 0, max: 0.5, divisions: 50,
          onChanged: enableAlpha
              ? (v) => onChanged(params.copyWith(lipAlpha: v.clamp(0, 0.5)))
              : null,
        ),
      ],
    );
  }
}

class _PaletteOpener extends StatelessWidget {
  const _PaletteOpener({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white10,
          border: Border.all(color: Colors.white, width: 1.6),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.palette, size: 16, color: Colors.white),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0,1)),
          ],
        ),
      ),
    );
  }
}
