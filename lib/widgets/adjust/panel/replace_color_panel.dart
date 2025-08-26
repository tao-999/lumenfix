import 'package:flutter/material.dart';
import '../common.dart';
import '../params/replace_color_params.dart';
import '../widgets/color_picker_dialog.dart';

class ReplaceColorPanel extends StatelessWidget {
  const ReplaceColorPanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final ReplaceColorParams value;
  final ValueChanged<ReplaceColorParams> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部：启用 + 颜色样本（仅样本可点开拾色器）
          Row(
            children: [
              Checkbox(
                value: value.enabled,
                onChanged: (on) {
                  onChanged(value.copyWith(enabled: on ?? false));
                  onCommit();
                },
              ),
              const SizedBox(width: 6),
              // 点击文字只切换启用，不弹拾色器
              GestureDetector(
                onTap: () {
                  onChanged(value.copyWith(enabled: !value.enabled));
                  onCommit();
                },
                child: const Text('替换颜色', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 10),

              // 只有颜色方块可打开拾色器
              InkWell(
                onTap: value.enabled
                    ? () async {
                  final c = await showBwTintColorPicker(
                    context,
                    value.sampleColor,
                  );
                  if (c != null) {
                    onChanged(value.copyWith(
                      enabled: true,
                      sampleColor: c,
                    ));
                    onCommit();
                  }
                }
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 22,
                  height: 16,
                  decoration: BoxDecoration(
                    color: value.sampleColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text('取色', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),

          // 颜色容差
          CommonSlider(
            label: '颜色容差',
            value: value.tolerance,
            min: 0, max: 100, neutral: 50,
            onChanged: (v) =>
                onChanged(value.copyWith(enabled: true, tolerance: v)),
            onCommit: onCommit,
          ),

          // H/S/L 偏移
          CommonSlider(
            label: '色相',
            value: value.hueShift,
            min: -180, max: 180, neutral: 0,
            onChanged: (v) =>
                onChanged(value.copyWith(enabled: true, hueShift: v)),
            onCommit: onCommit,
          ),
          CommonSlider(
            label: '饱和度',
            value: value.satShift,
            min: -100, max: 100, neutral: 0,
            onChanged: (v) =>
                onChanged(value.copyWith(enabled: true, satShift: v)),
            onCommit: onCommit,
          ),
          CommonSlider(
            label: '明度',
            value: value.lightShift,
            min: -100, max: 100, neutral: 0,
            onChanged: (v) =>
                onChanged(value.copyWith(enabled: true, lightShift: v)),
            onCommit: onCommit,
          ),
        ],
      ),
    );
  }
}
