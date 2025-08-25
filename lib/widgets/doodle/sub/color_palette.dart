// lib/widgets/doodle/sub/color_palette.dart
import 'package:flutter/material.dart';
import 'full_color_picker.dart';

class ColorPalette extends StatelessWidget {
  const ColorPalette({
    super.key,
    required this.selected,
    required this.onSelect,
    this.allowAlpha = true, // 是否允许透明度
  });

  final Color selected;
  final ValueChanged<Color> onSelect;
  final bool allowAlpha;

  static const _colors = <Color>[
    Color(0xFFFFFFFF), Color(0xFF000000),
    Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFCC00),
    Color(0xFF34C759), Color(0xFF5AC8FA), Color(0xFF007AFF),
    Color(0xFFAF52DE), Color(0xFFFF2D55),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _colors.length + 1, // +1: 自定义颜色按钮
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          // ✅ 第一个就是“自定义颜色”入口
          if (i == 0) {
            return _CustomColorButton(
              onTap: () async {
                final picked = await FullColorPicker.show(
                  context,
                  initial: selected,
                  allowAlpha: allowAlpha,
                );
                if (picked != null) onSelect(picked);
              },
            );
          }

          // 其余为预设颜色（索引要 -1）
          final c = _colors[i - 1];
          final sel = c.value == selected.value;
          return GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c,
                border: Border.all(
                  color: sel ? Colors.white : Colors.white24,
                  width: sel ? 2 : 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  const _CustomColorButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: <Color>[
              Colors.red,
              Colors.yellow,
              Colors.green,
              Colors.cyan,
              Colors.blue,
              Color(0xFFFF00FF), // magenta
              Colors.red,
            ],
          ),
          border: Border.fromBorderSide(
            BorderSide(color: Colors.white, width: 1.2),
          ),
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
