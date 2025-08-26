// lib/widgets/adjust/panel/black_white_panel.dart
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
          // —— 顶部：只有一个勾选框：着色 —— //
          Row(
            children: [
              Checkbox(
                value: value.tintEnable,
                onChanged: (on) {
                  final enableTint = on ?? false;
                  onChanged(
                    value.copyWith(
                      tintEnable: enableTint,
                      // 关键：关掉“着色”时，同步关掉黑白效果；勾上则启用
                      enabled: enableTint ? true : false,
                    ),
                  );
                  onCommit();
                },
              ),
              const Text('着色', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              // 颜色块（只有在勾选着色时可点击）
              InkWell(
                onTap: value.tintEnable
                    ? () async {
                  final picked =
                  await showBwTintColorPicker(context, value.tintColor);
                  if (picked != null) {
                    onChanged(value.copyWith(
                      enabled: true,
                      tintColor: picked,
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
                    color: value.tintEnable ? value.tintColor : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white38),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),

          // —— 六色权重（移动即自动启用黑白） —— //
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
