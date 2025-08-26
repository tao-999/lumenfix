import 'package:flutter/material.dart';
import '../common.dart';
import '../params/posterize_params.dart';

class PosterizePanel extends StatelessWidget {
  const PosterizePanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final PosterizeParams value;
  final ValueChanged<PosterizeParams> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ✅ 启用/关闭（点文字也能切）
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
              GestureDetector(
                onTap: () {
                  onChanged(value.copyWith(enabled: !value.enabled));
                  onCommit();
                },
                child: const Text('启用色调分离', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ✅ 滑杆：未启用时禁用
          CommonSlider(
            label: '色阶',
            value: value.levels.toDouble(),
            min: 2,           // PS 是 2..255；预览用 2..64 也够，但这儿保留 2..64 的交互
            max: 64,
            neutral: 4,       // PS 默认 4
            enabled: value.enabled, // ✅
            onChanged: (v) => onChanged(
              value.copyWith(levels: v.round().clamp(2, 255)),
            ),
            onCommit: onCommit,
          ),
        ],
      ),
    );
  }
}
