import 'package:flutter/material.dart';
import '../common.dart';
import '../params/black_white_params.dart';
import '../widgets/color_picker_dialog.dart';

class BlackWhitePanel extends StatelessWidget {
  const BlackWhitePanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final BlackWhiteParams value;
  final ValueChanged<BlackWhiteParams> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // —— 顶部：启用开关 —— //
          Row(
            children: [
              Checkbox(
                value: value.enabled,
                onChanged: (on) => onChanged(value.copyWith(enabled: on ?? false)),
              ),
              const SizedBox(width: 6),
              const Text('启用黑白', style: TextStyle(color: Colors.white)),
              const Spacer(),
              // 着色
              Checkbox(
                value: value.tintEnable,
                onChanged: (on) => onChanged(value.copyWith(
                  enabled: true, // 勾选着色时顺便启用黑白
                  tintEnable: on ?? false,
                )),
              ),
              GestureDetector(
                onTap: value.tintEnable ? () async {
                  final picked = await showBwTintColorPicker(context, value.tintColor);
                  if (picked != null) {
                    onChanged(value.copyWith(enabled: true, tintColor: picked));
                    onCommit();
                  }
                } : null,
                child: Container(
                  width: 22, height: 16,
                  decoration: BoxDecoration(
                    color: value.tintEnable ? value.tintColor : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white38),
                  ),
                  margin: const EdgeInsets.only(right: 6),
                ),
              ),
              const Text('着色', style: TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),

          // —— 六色权重 —— //
          _bwSlider('红色',   value.reds,     (v) => onChanged(value.copyWith(enabled: true, reds: v))),
          _bwSlider('黄色',   value.yellows,  (v) => onChanged(value.copyWith(enabled: true, yellows: v))),
          _bwSlider('绿色',   value.greens,   (v) => onChanged(value.copyWith(enabled: true, greens: v))),
          _bwSlider('青色',   value.cyans,    (v) => onChanged(value.copyWith(enabled: true, cyans: v))),
          _bwSlider('蓝色',   value.blues,    (v) => onChanged(value.copyWith(enabled: true, blues: v))),
          _bwSlider('品红',   value.magentas, (v) => onChanged(value.copyWith(enabled: true, magentas: v))),
        ],
      ),
    );
  }

  Widget _bwSlider(String label, int val, ValueChanged<int> onChangedInt) {
    return CommonSlider(
      label: label,
      value: val.toDouble(),
      min: 0, max: 255, neutral: 128,
      onChanged: (v) => onChangedInt(v.round().clamp(0, 255)),
      onCommit: onCommit,
    );
  }
}

/// —— 简易调色板对话框 ——
/// （无第三方库，给你一组常用色可点选）
Future<Color?> _pickColor(BuildContext context, Color init) async {
  final List<Color> colors = [
    const Color(0xFF2399CF), const Color(0xFF4CAF50), const Color(0xFFFFC107),
    const Color(0xFFE91E63), const Color(0xFF3F51B5), const Color(0xFFFF5722),
    const Color(0xFF795548), const Color(0xFF9E9E9E),
  ];
  Color current = init;
  return showDialog<Color>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('选择着色颜色', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 300,
        child: Wrap(
          spacing: 10, runSpacing: 10,
          children: colors.map((c) {
            final sel = c.value == current.value;
            return GestureDetector(
              onTap: () { current = c; },
              child: Container(
                width: 32, height: 24,
                decoration: BoxDecoration(
                  color: c,
                  border: Border.all(color: sel ? Colors.white : Colors.white24, width: sel ? 2 : 1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(context, current), child: const Text('确定')),
      ],
    ),
  );
}
