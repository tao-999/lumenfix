// lib/widgets/adjust/panel/denoise_panel.dart
import 'package:flutter/material.dart';
import '../common.dart';                    // ✅ 统一滑条样式
import '../../adjust/params/params.dart';

class DenoisePanel extends StatelessWidget {
  const DenoisePanel({
    super.key,
    required this.value,
    required this.onChanged,
    this.onCommit,
  });

  final DenoiseParams value;
  final ValueChanged<DenoiseParams> onChanged;
  final VoidCallback? onCommit;

  @override
  Widget build(BuildContext context) {
    final enabled = value.enabled;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // —— 顶部：勾选启用（label 可点） + 模式选择 —— //
          Row(
            children: [
              _CheckWithLabel(
                value: enabled,
                label: '启用降噪',
                onChanged: (en) {
                  onChanged(value.copyWith(enabled: en));
                  onCommit?.call();
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<DenoiseMode>(
                  isExpanded: true,
                  value: value.mode,
                  dropdownColor: const Color(0xFF121212),
                  style: const TextStyle(color: Colors.white), // 选中项颜色
                  items: DenoiseMode.values
                      .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(
                      _modeLabel(m),
                      style: const TextStyle(color: Colors.white), // 列表项颜色
                    ),
                  ))
                      .toList(),
                  onChanged: enabled
                      ? (m) {
                    if (m == null) return;
                    onChanged(value.copyWith(enabled: true, mode: m));
                    onCommit?.call();
                  }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // —— 滑条统一用 CommonSlider —— //
          CommonSlider(
            label: '强度',
            value: value.strength,
            min: 0,
            max: 100,
            neutral: 0,
            enabled: enabled,
            onChanged: (v) => onChanged(value.copyWith(strength: v)),
            onCommit: onCommit ?? () {},
          ),
          const SizedBox(height: 4),

          CommonSlider(
            label: '色彩降噪',
            value: value.chroma,
            min: 0,
            max: 100,
            neutral: 0,
            enabled: enabled,
            onChanged: (v) => onChanged(value.copyWith(chroma: v)),
            onCommit: onCommit ?? () {},
          ),
          const SizedBox(height: 4),

          if (value.mode == DenoiseMode.bilateral ||
              value.mode == DenoiseMode.nlmLite)
            CommonSlider(
              label: '细节保护',
              value: value.edge,
              min: 0,
              max: 100,
              neutral: 0,
              enabled: enabled,
              onChanged: (v) => onChanged(value.copyWith(edge: v)),
              onCommit: onCommit ?? () {},
            ),

          const SizedBox(height: 4),

          // —— 半径：label 白色，宽度 72 与滑条标签对齐 —— //
          Opacity(
            opacity: enabled ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: !enabled,
              child: Row(
                children: [
                  const SizedBox(
                    width: 72,
                    child: Text('半径', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: value.radius,
                    dropdownColor: const Color(0xFF121212),
                    style: const TextStyle(color: Colors.white), // 选中项颜色
                    items: const [1, 2, 3]
                        .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        'x${2 * e + 1}',
                        style: const TextStyle(color: Colors.white), // 列表项颜色
                      ),
                    ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      onChanged(value.copyWith(radius: v));
                      onCommit?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(DenoiseMode m) {
    switch (m) {
      case DenoiseMode.bilateral: return '双边（保边）';
      case DenoiseMode.wavelet:   return '小波软阈值';
      case DenoiseMode.nlmLite:   return 'NLM-Lite';
      case DenoiseMode.median:    return '中值（椒盐）';
    }
  }
}

/// 勾选 + 文本整块可点
class _CheckWithLabel extends StatelessWidget {
  const _CheckWithLabel({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
          ),
          const SizedBox(width: 4),
          const SizedBox.shrink(),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
