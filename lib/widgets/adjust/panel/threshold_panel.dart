// lib/widgets/adjust/panel/threshold_panel.dart
import 'package:flutter/material.dart';
import '../common.dart';
import '../params/threshold_params.dart';

class ThresholdPanel extends StatelessWidget {
  const ThresholdPanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final ThresholdParams value;
  final ValueChanged<ThresholdParams> onChanged;
  final VoidCallback onCommit;

  void _toggleEnable() {
    onChanged(value.copyWith(enabled: !value.enabled));
    onCommit();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // —— 顶部：启用勾选（整行可点）——
          InkWell(
            onTap: _toggleEnable,
            child: Row(
              children: [
                Checkbox(
                  value: value.enabled,
                  onChanged: (_) => _toggleEnable(),
                ),
                const SizedBox(width: 6),
                const Text('启用阈值', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // —— 阈值滑杆 ——（未启用时禁用交互/半透明）
          CommonSlider(
            label: '阈值',
            value: value.level.toDouble(),
            min: 1,
            max: 255,
            neutral: 128,
            enabled: value.enabled, // ✅ 跟随启用状态
            onChanged: (v) => onChanged(
              value.copyWith(
                enabled: true, // 拖动即自动启用
                level: v.round().clamp(1, 255),
              ),
            ),
            onCommit: onCommit,
          ),
        ],
      ),
    );
  }
}
