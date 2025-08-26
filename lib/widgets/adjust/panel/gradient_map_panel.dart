import 'package:flutter/material.dart';
import '../common.dart';
import '../params/gradient_map_params.dart';
import '../widgets/gradient_editor_dialog.dart';

class GradientMapPanel extends StatelessWidget {
  const GradientMapPanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final GradientMapParams value;
  final ValueChanged<GradientMapParams> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final swatch = _buildSwatch(value.stops, reverse: value.reverse);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：启用 + 渐变条（点开编辑器）
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  onChanged(value.copyWith(enabled: !value.enabled));
                  onCommit();
                },
                child: Row(children: [
                  Checkbox(
                    value: value.enabled,
                    onChanged: (on) {
                      onChanged(value.copyWith(enabled: on ?? false));
                      onCommit();
                    },
                  ),
                  const SizedBox(width: 6),
                  const Text('启用渐变映射', style: TextStyle(color: Colors.white)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: !value.enabled
                      ? null
                      : () async {
                    final res = await showGradientEditorDialog(
                      context: context,
                      init: value.stops,
                    );
                    if (res != null) {
                      onChanged(value.copyWith(enabled: true, stops: res));
                      onCommit();
                    }
                  },
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white30),
                      gradient: swatch,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 10),

          // ⬆️ 把强度滑杆提前，远离底部更好拖
          CommonSlider(
            label: '强度',
            value: value.strength * 100.0,
            min: 0,
            max: 100,
            neutral: 100,
            onChanged: (v) => onChanged(value.copyWith(strength: (v / 100.0))),
            onCommit: onCommit,
          ),
          const SizedBox(height: 4),

          // 其余开关 + Method（用 Wrap 防止横向溢出）
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _check(
                label: '仿色',
                value: value.dither,
                enabled: value.enabled,
                onChanged: (on) {
                  onChanged(value.copyWith(dither: on ?? false));
                  onCommit();
                },
              ),
              _check(
                label: '反向',
                value: value.reverse,
                enabled: value.enabled,
                onChanged: (on) {
                  onChanged(value.copyWith(reverse: on ?? false));
                  onCommit();
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Method：', style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 6),
                  DropdownButton<GradientMethod>(
                    value: value.method,
                    isDense: true,
                    dropdownColor: const Color(0xFF2C2C2C),
                    onChanged: !value.enabled
                        ? null
                        : (m) {
                      if (m != null) {
                        onChanged(value.copyWith(method: m));
                        onCommit();
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: GradientMethod.perceptual,
                        child: Text('Perceptual'),
                      ),
                      DropdownMenuItem(
                        value: GradientMethod.linear,
                        child: Text('Linear'),
                      ),
                      DropdownMenuItem(
                        value: GradientMethod.classic,
                        child: Text('Classic'),
                      ),
                      DropdownMenuItem(
                        value: GradientMethod.smooth,
                        child: Text('Smooth'),
                      ),
                      DropdownMenuItem(
                        value: GradientMethod.stripes,
                        child: Text('Stripes'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _check({
    required String label,
    required bool value,
    required bool enabled,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: value, onChanged: enabled ? onChanged : null),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  LinearGradient _buildSwatch(List<GradientStop> stops, {bool reverse = false}) {
    final ss = (reverse
        ? stops.map((e) => e.copyWith(pos: 1.0 - e.pos)).toList()
        : List<GradientStop>.from(stops))
      ..sort((a, b) => a.pos.compareTo(b.pos));

    return LinearGradient(
      colors: ss.map((e) => e.color).toList(),
      stops: ss.map((e) => e.pos.clamp(0.0, 1.0)).toList(),
    );
  }
}
