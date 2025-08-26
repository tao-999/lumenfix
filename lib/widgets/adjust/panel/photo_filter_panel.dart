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
    final dis = !value.enabled;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ 顶部启用开关（点文字也能切）
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
                child: const Text('启用照片滤镜', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 10),
              // 颜色方块（点击弹拾色器；选择后自动设为启用）
              InkWell(
                onTap: () async {
                  final picked =
                  await showBwTintColorPicker(context, value.color);
                  if (picked != null) {
                    onChanged(value.copyWith(enabled: true, color: picked));
                    onCommit();
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 20,
                  decoration: BoxDecoration(
                    color: value.color,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white38),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 密度：0..100%（未启用时禁用）
          CommonSlider(
            label: '密度',
            value: value.density * 100.0,
            min: 0, max: 100, neutral: 25,
            enabled: !dis, // ✅
            // 如果你的 CommonSlider 支持 suffixBuilder，可放开下一行百分号展示
            // suffixBuilder: (v) => '${v.round()}%',
            onChanged: (v) => onChanged(
              value.copyWith(enabled: true, density: (v / 100.0).clamp(0.0, 1.0)),
            ),
            onCommit: onCommit,
          ),

          const SizedBox(height: 6),

          // 保留明度（未启用置灰；点一次自动启用）
          Opacity(
            opacity: dis ? 0.5 : 1,
            child: Row(
              children: [
                Checkbox(
                  value: value.preserveLum,
                  onChanged: dis
                      ? null
                      : (on) {
                    onChanged(value.copyWith(
                      enabled: true,
                      preserveLum: on ?? true,
                    ));
                    onCommit();
                  },
                ),
                const Text('保留明度', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
