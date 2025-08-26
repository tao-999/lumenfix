// lib/widgets/adjust/common.dart
import 'package:flutter/material.dart';

/// 通用滚动容器：塞一堆 section/slider 的列表（更紧凑）
class CommonScroller extends StatelessWidget {
  final List<Widget> children;
  const CommonScroller({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6), // 8 -> 6 更紧凑
      itemBuilder: (_, i) => children[i],
    );
  }
}

/// 小节标题（提亮）
class CommonSection extends StatelessWidget {
  final String title;
  const CommonSection(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white, // 提亮
        ),
      ),
    );
  }
}

/// 通用滑杆：更紧凑 + 标签提亮 + 去掉中立竖线
class CommonSlider extends StatefulWidget {
  const CommonSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onCommit,
    this.neutral,
    this.decimals = 0,
    this.enabled = true,
    this.dense = true,           // 紧凑模式（默认开）
    this.showReset = true,       // 是否显示“复位”
    this.suffixBuilder,          // ✅ 新增：自定义数值显示（如 "80%"）
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double? neutral;                 // 中立/默认值（用于“复位”）
  final int decimals;                    // 展示小数位
  final bool enabled;
  final bool dense;
  final bool showReset;
  final String Function(double v)? suffixBuilder; // ✅ 可选显示格式化
  final ValueChanged<double> onChanged;
  final VoidCallback onCommit;

  @override
  State<CommonSlider> createState() => _CommonSliderState();
}

class _CommonSliderState extends State<CommonSlider> {
  late double _v;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
  }

  @override
  void didUpdateWidget(covariant CommonSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _v = widget.value;
  }

  String _fmt(double v) {
    return widget.decimals <= 0
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(widget.decimals);
  }

  @override
  Widget build(BuildContext context) {
    final dis = !widget.enabled;
    final theme = Theme.of(context);
    final vPad = widget.dense ? 2.0 : 6.0; // 垂直间距更小
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.white,                    // 标签提亮
      fontSize: widget.dense ? 13 : 14,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = theme.textTheme.labelLarge?.copyWith(
      color: Colors.white,                    // 数值提亮
      fontWeight: FontWeight.w600,
    );

    // ✅ 用 suffixBuilder 自定义显示（比如 80%），否则用默认格式
    final valueText = widget.suffixBuilder?.call(_v) ?? _fmt(_v);

    return Opacity(
      opacity: dis ? 0.5 : 1,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: vPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题 + 数值 + 复位
            Row(
              children: [
                Expanded(child: Text(widget.label, style: labelStyle)),
                const SizedBox(width: 8),
                Text(valueText, style: valueStyle), // ✅
                if (widget.neutral != null && widget.showReset) ...[
                  const SizedBox(width: 6),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact, // 更紧凑
                    ),
                    onPressed: dis ? null : () {
                      setState(() => _v = widget.neutral!);
                      widget.onChanged(_v);
                      widget.onCommit();
                    },
                    child: const Text('复位'),
                  ),
                ]
              ],
            ),

            // Slider（去掉中间竖线；收紧可视高度）
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2, // 压低轨道高度
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 0), // 取消放大圈
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _v.clamp(widget.min, widget.max),
                min: widget.min, max: widget.max,
                onChanged: dis ? null : (v) {
                  setState(() => _v = v);
                  widget.onChanged(v);
                },
                onChangeEnd: dis ? null : (_) => widget.onCommit(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// —— 可复用：小 Chip —— //
class CommonChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  const CommonChip({super.key, required this.text, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => onTap?.call(),
    );
  }
}

/// —— 可复用：子标签行（把一组 Chip 平铺）—— //
class CommonSubTabs extends StatelessWidget {
  final Iterable<Widget> tabs;
  const CommonSubTabs({super.key, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: tabs.toList(),
    );
  }
}
