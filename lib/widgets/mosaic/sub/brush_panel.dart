import 'package:flutter/material.dart';
import '../mosaic_types.dart';
import 'brush_icons.dart';

class BrushPanel extends StatelessWidget {
  const BrushPanel({
    super.key,
    required this.selected,
    required this.strength,
    required this.busy,
    required this.onSelect,
    required this.onStrengthChange,  // 👈 滑动中，只改UI
    required this.onStrengthCommit,  // 👈 松手后，触发重建
  });

  final MosaicBrushType selected;
  final int strength;
  final bool busy;
  final ValueChanged<MosaicBrushType> onSelect;
  final ValueChanged<int> onStrengthChange;
  final ValueChanged<int> onStrengthCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.78),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 5 个图标（无文字）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BrushIcon(
                selected: selected == MosaicBrushType.pixel,
                painter: const IconPixel(),
                onTap: busy ? null : () => onSelect(MosaicBrushType.pixel),
              ),
              _BrushIcon(
                selected: selected == MosaicBrushType.blur,
                painter: const IconBlur(),
                onTap: busy ? null : () => onSelect(MosaicBrushType.blur),
              ),
              _BrushIcon(
                selected: selected == MosaicBrushType.hex,
                painter: const IconHex(),
                onTap: busy ? null : () => onSelect(MosaicBrushType.hex),
              ),
              _BrushIcon(
                selected: selected == MosaicBrushType.glass,
                painter: const IconGlass(),
                onTap: busy ? null : () => onSelect(MosaicBrushType.glass),
              ),
              _BrushIcon(
                selected: selected == MosaicBrushType.bars,
                painter: const IconBars(),
                onTap: busy ? null : () => onSelect(MosaicBrushType.bars),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: strength.toDouble(),
            min: 4,
            max: 64,
            divisions: 60,
            onChanged: busy ? null : (v) => onStrengthChange(v.round()),
            onChangeEnd: busy ? null : (v) => onStrengthCommit(v.round()),
          ),
        ],
      ),
    );
  }
}

class _BrushIcon extends StatelessWidget {
  const _BrushIcon({
    required this.selected,
    required this.painter,
    this.onTap,
  });

  final bool selected;
  final CustomPainter painter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? Colors.white : Colors.white24;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: selected ? 2 : 1),
        ),
        padding: const EdgeInsets.all(6),
        child: CustomPaint(painter: painter),
      ),
    );
  }
}
