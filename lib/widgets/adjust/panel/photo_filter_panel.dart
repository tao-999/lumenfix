// lib/widgets/adjust/panel/photo_filter_panel.dart
import 'package:flutter/material.dart';
import '../common.dart';
import '../params/photo_filter_params.dart';
import '../widgets/color_picker_dialog.dart';

class PhotoFilterPanel extends StatelessWidget {
  const PhotoFilterPanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final PhotoFilterParams value;
  final ValueChanged<PhotoFilterParams> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：颜色方块（点击弹拾色器）
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () async {
                final picked = await showBwTintColorPicker(context, value.color);
                if (picked != null) {
                  onChanged(value.copyWith(color: picked));
                  onCommit();
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 28, height: 20,
                decoration: BoxDecoration(
                  color: value.color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white38),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 密度：0..100%
          CommonSlider(
            label: '密度:',
            value: value.density * 100.0,
            min: 0, max: 100, neutral: 25,
            suffixBuilder: (v) => '${v.round()}%',
            onChanged: (v) => onChanged(value.copyWith(density: (v / 100.0).clamp(0.0, 1.0))),
            onCommit: onCommit,
          ),

          const SizedBox(height: 6),
          Row(
            children: [
              Checkbox(
                value: value.preserveLum,
                onChanged: (on) => onChanged(value.copyWith(preserveLum: on ?? true)),
              ),
              const Text('保留明度', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}
