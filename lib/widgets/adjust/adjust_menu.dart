// lib/widgets/adjust/adjust_menu.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// —— 功能枚举 —— //
enum AdjustAction {
  brightnessContrast,
  levels,
  curves,
  exposure,
  vibrance,
  hsl,
  colorBalance,
  blackWhite,
  photoFilter,
  channelMixer,
  invert,
  posterize,
  threshold,
  gradientMap,
  selectiveColor,
  shadowsHighlights,
  desaturate,        // 去色
  replaceColor,
  denoise,
}

/// —— 文案 —— //
String labelForAdjustAction(AdjustAction a) {
  switch (a) {
    case AdjustAction.brightnessContrast: return '亮度/对比度';
    case AdjustAction.levels:             return '色阶';
    case AdjustAction.curves:             return '曲线';
    case AdjustAction.exposure:           return '曝光度';
    case AdjustAction.vibrance:           return '自然饱和度';
    case AdjustAction.hsl:                return '色相/饱和度';
    case AdjustAction.colorBalance:       return '色彩平衡';
    case AdjustAction.denoise:            return '图片降噪';
    case AdjustAction.blackWhite:         return '黑白';
    case AdjustAction.photoFilter:        return '照片滤镜';
    case AdjustAction.channelMixer:       return '通道混合器';
    case AdjustAction.invert:             return '反相';
    case AdjustAction.posterize:          return '色调分离';
    case AdjustAction.threshold:          return '阈值';
    case AdjustAction.gradientMap:        return '渐变映射';
    case AdjustAction.selectiveColor:     return '可选颜色';
    case AdjustAction.shadowsHighlights:  return '阴影/高光';
    case AdjustAction.desaturate:         return '去色';
    case AdjustAction.replaceColor:       return '替换颜色';
  }
}

/// —— 图标 —— //
IconData iconForAdjustAction(AdjustAction a) {
  switch (a) {
    case AdjustAction.brightnessContrast: return Icons.brightness_6_outlined;
    case AdjustAction.levels:             return Icons.stacked_line_chart;
    case AdjustAction.curves:             return Icons.show_chart;
    case AdjustAction.exposure:           return Icons.exposure_outlined;
    case AdjustAction.vibrance:           return Icons.color_lens_outlined;
    case AdjustAction.hsl:                return Icons.palette_outlined;
    case AdjustAction.colorBalance:       return Icons.colorize_outlined;
    case AdjustAction.denoise:            return Icons.noise_control_off;
    case AdjustAction.blackWhite:         return Icons.filter_b_and_w;
    case AdjustAction.photoFilter:        return Icons.photo_filter_outlined;
    case AdjustAction.channelMixer:       return Icons.grid_3x3_outlined;
    case AdjustAction.invert:             return Icons.invert_colors;
    case AdjustAction.posterize:          return Icons.filter_hdr_outlined;
    case AdjustAction.threshold:          return Icons.tonality;
    case AdjustAction.gradientMap:        return Icons.gradient_outlined;
    case AdjustAction.selectiveColor:     return Icons.colorize;
    case AdjustAction.shadowsHighlights:  return Icons.tonality_outlined;
    case AdjustAction.desaturate:         return Icons.water_drop_outlined;
    case AdjustAction.replaceColor:       return Icons.swap_horiz_outlined;
  }
}

/// —— 菜单顺序 —— //
const List<AdjustAction> kAllAdjustActions = [
  AdjustAction.brightnessContrast,
  AdjustAction.levels,
  AdjustAction.curves,
  AdjustAction.exposure,
  AdjustAction.vibrance,
  AdjustAction.hsl,
  AdjustAction.colorBalance,
  AdjustAction.denoise,
  AdjustAction.blackWhite,
  AdjustAction.photoFilter,
  AdjustAction.channelMixer,
  AdjustAction.invert,
  AdjustAction.posterize,
  AdjustAction.threshold,
  AdjustAction.gradientMap,
  AdjustAction.selectiveColor,
  AdjustAction.shadowsHighlights,
  AdjustAction.desaturate,
  AdjustAction.replaceColor,
];

/// ===============================
/// 横向菜单（Bokeh 风格 Chip，icon+文字）
/// ===============================
class AdjustMenu extends StatelessWidget {
  const AdjustMenu.flatRow({
    super.key,
    required this.enabled,
    required this.actions,
    required this.selected,
    required this.onSelect,
    this.rowHeight = 56,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
    this.spacing = 8,
    this.iconSize = 18,
    this.maxTextScale = 1.2,
  });

  final bool enabled;
  final List<AdjustAction> actions;
  final AdjustAction selected;
  final ValueChanged<AdjustAction> onSelect;
  final double rowHeight;
  final EdgeInsets padding;
  final double spacing;
  final double iconSize;
  final double maxTextScale;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final ts = math.min(mq.textScaleFactor, maxTextScale);

    return MediaQuery(
      data: mq.copyWith(textScaleFactor: ts),
      child: SizedBox(
        height: rowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padding,
          clipBehavior: Clip.none,
          separatorBuilder: (_, __) => SizedBox(width: spacing),
          itemCount: actions.length,
          itemBuilder: (_, i) {
            final a = actions[i];
            final sel = a == selected;
            return _IconTextChip(
              icon: iconForAdjustAction(a),
              text: labelForAdjustAction(a),
              selected: sel,
              enabled: enabled,
              iconSize: iconSize,
              onTap: () => onSelect(a),
            );
          },
        ),
      ),
    );
  }
}

class _IconTextChip extends StatelessWidget {
  const _IconTextChip({
    required this.icon,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.iconSize = 18,
  });

  final IconData icon;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.white12 : Colors.white10;
    final bd = selected ? Colors.white : Colors.white24;
    final bw = selected ? 2.0 : 1.0;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Align(
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: bd, width: bw),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: iconSize),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, height: 1.2),
                  strutStyle: const StrutStyle(forceStrutHeight: true, height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
