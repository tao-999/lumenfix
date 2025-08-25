import 'package:flutter/material.dart';
import '../../../services/doodle_service.dart';
import 'color_palette.dart';
import 'brush_icons.dart';

class BrushPanel extends StatelessWidget {
  const BrushPanel({
    super.key,
    required this.brush,
    required this.color,
    required this.size,
    required this.onBrushChange,
    required this.onColorChange,
    required this.onSizeChange,
  });

  final DoodleBrushType brush;
  final Color color;
  final double size;
  final ValueChanged<DoodleBrushType> onBrushChange;
  final ValueChanged<Color> onColorChange;
  final ValueChanged<double> onSizeChange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.78),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 笔刷选择（自绘图标）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BrushIcon(
                selected: brush == DoodleBrushType.pen,
                painter: const IconPen(),
                onTap: () => onBrushChange(DoodleBrushType.pen),
              ),
              _BrushIcon(
                selected: brush == DoodleBrushType.marker,
                painter: const IconMarker(),
                onTap: () => onBrushChange(DoodleBrushType.marker),
              ),
              _BrushIcon(
                selected: brush == DoodleBrushType.highlighter,
                painter: const IconHighlighter(),
                onTap: () => onBrushChange(DoodleBrushType.highlighter),
              ),
              _BrushIcon(
                selected: brush == DoodleBrushType.neon,
                painter: const IconNeon(),
                onTap: () => onBrushChange(DoodleBrushType.neon),
              ),
              _BrushIcon(
                selected: brush == DoodleBrushType.eraser,
                painter: const IconEraser(),
                onTap: () => onBrushChange(DoodleBrushType.eraser),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 颜色条（橡皮擦禁用颜色）
          Opacity(
            opacity: brush == DoodleBrushType.eraser ? .35 : 1,
            child: IgnorePointer(
              ignoring: brush == DoodleBrushType.eraser,
              child: ColorPalette(
                selected: color,
                onSelect: onColorChange,
              ),
            ),
          ),
          // 笔刷大小
          Row(
            children: [
              const SizedBox(width: 6),
              const Icon(Icons.brush, color: Colors.white70, size: 18),
              Expanded(
                child: Slider(
                  value: size,
                  min: 2,
                  max: 36,
                  divisions: 34,
                  label: size.toStringAsFixed(0),
                  onChanged: onSizeChange,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  size.toStringAsFixed(0),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
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
