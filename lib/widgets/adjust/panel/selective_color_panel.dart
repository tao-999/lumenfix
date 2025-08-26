import 'package:flutter/material.dart';
import '../common.dart';
import '../params/selective_color_params.dart';

class SelectiveColorPanel extends StatelessWidget {
  const SelectiveColorPanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final SelectiveColorParams value;
  final ValueChanged<SelectiveColorParams> onChanged;
  final VoidCallback onCommit;

  static const Map<SelectiveColorTarget, String> _labels = {
    SelectiveColorTarget.reds:     '红色',
    SelectiveColorTarget.yellows:  '黄色',
    SelectiveColorTarget.greens:   '绿色',
    SelectiveColorTarget.cyans:    '青色',
    SelectiveColorTarget.blues:    '蓝色',
    SelectiveColorTarget.magentas: '洋红',
    SelectiveColorTarget.whites:   '白色',
    SelectiveColorTarget.neutrals: '中性色',
    SelectiveColorTarget.blacks:   '黑色',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCard(
            title: '色彩',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SelectiveColorTarget>(
                value: value.target,
                isExpanded: true,
                onChanged: (t) => onChanged(value.copyWith(target: t)),
                items: SelectiveColorTarget.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(_labels[t]!, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                dropdownColor: const Color(0xFF1E1E1E),
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: '调整',
            child: Column(
              children: [
                CommonSlider(
                  label: '青色',
                  value: value.cyan,
                  min: -100, max: 100, neutral: 0,
                  onChanged: (v) => onChanged(value.copyWith(cyan: v)),
                  onCommit: onCommit,
                ),
                CommonSlider(
                  label: '品红',
                  value: value.magenta,
                  min: -100, max: 100, neutral: 0,
                  onChanged: (v) => onChanged(value.copyWith(magenta: v)),
                  onCommit: onCommit,
                ),
                CommonSlider(
                  label: '黄色',
                  value: value.yellow,
                  min: -100, max: 100, neutral: 0,
                  onChanged: (v) => onChanged(value.copyWith(yellow: v)),
                  onCommit: onCommit,
                ),
                CommonSlider(
                  label: '黑色',
                  value: value.black,
                  min: -100, max: 100, neutral: 0,
                  onChanged: (v) => onChanged(value.copyWith(black: v)),
                  onCommit: onCommit,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Checkbox(
                value: value.absolute,
                onChanged: (on) => onChanged(value.copyWith(absolute: on ?? false)),
              ),
              const SizedBox(width: 6),
              const Text('绝对', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

/* ===== 小卡片 ===== */
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
