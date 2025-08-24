// 📄 lib/widgets/beautify/beautify_bottom_bar.dart
import 'package:flutter/material.dart';

enum BeautifyMenu {
  autoEnhance,
  filter,
  adjust,
  crop,
  bokeh,
  mosaic,
  doodle,
  blemish,
  restore,
  sharpen,
  denoise,
  grain,
  vignette,
  perspective,
  straighten,
}

class BeautifyBottomBar extends StatefulWidget {
  const BeautifyBottomBar({
    super.key,
    required this.enabled,
    required this.onSelect,
    this.selected,           // null=未选中，上半区不显示
    this.detail,             // 上半区内容（未选中时忽略）
    this.detailHeight = 140,
  });

  final bool enabled;
  final ValueChanged<BeautifyMenu> onSelect;
  final BeautifyMenu? selected;
  final Widget? detail;
  final double detailHeight;

  @override
  State<BeautifyBottomBar> createState() => _BeautifyBottomBarState();
}

class _BeautifyBottomBarState extends State<BeautifyBottomBar> {
  BeautifyMenu? _current;

  @override
  void initState() {
    super.initState();
    _current = widget.selected;
  }

  @override
  void didUpdateWidget(covariant BeautifyBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _current = widget.selected;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final showDetail = widget.enabled && _current != null && widget.detail != null;

    return Material(
      color: cs.surface,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDetail)
                Container(
                  width: double.infinity,
                  height: widget.detailHeight,
                  alignment: Alignment.center,
                  child: widget.detail!,
                ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: _items.map((it) {
                      final selected = _current == it.id;
                      final enabled = widget.enabled;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _MinimalItem(
                          icon: it.icon,
                          label: it.label,
                          selected: selected,
                          enabled: enabled,
                          onTap: enabled
                              ? () {
                            setState(() => _current = it.id);
                            widget.onSelect(it.id);
                          }
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimalItem extends StatelessWidget {
  const _MinimalItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    final Color iconColor = !enabled
        ? t.disabledColor
        : selected
        ? cs.primary
        : cs.onSurfaceVariant;

    final Color textColor = !enabled
        ? t.disabledColor
        : selected
        ? cs.primary
        : cs.onSurfaceVariant;

    return InkResponse(
      onTap: onTap,
      radius: 36,
      highlightShape: BoxShape.rectangle,
      containedInkWell: false,
      child: SizedBox(
        width: 84,
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                height: 1.05,
                color: textColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // 细小指示条（无边框、无卡片）
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              width: selected ? 20 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: selected ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.id, this.icon, this.label);
  final BeautifyMenu id;
  final IconData icon;
  final String label;
}

final List<_MenuItem> _items = [
  _MenuItem(BeautifyMenu.autoEnhance, Icons.auto_awesome, '一键美化'),
  _MenuItem(BeautifyMenu.filter, Icons.auto_fix_high, '滤镜'),
  _MenuItem(BeautifyMenu.adjust, Icons.tune, '调整'),
  _MenuItem(BeautifyMenu.crop, Icons.crop, '裁剪'),
  _MenuItem(BeautifyMenu.bokeh, Icons.blur_on, '背景虚化'),
  _MenuItem(BeautifyMenu.mosaic, Icons.grid_on, '马赛克'),
  _MenuItem(BeautifyMenu.doodle, Icons.brush, '涂鸦'),
  _MenuItem(BeautifyMenu.blemish, Icons.healing, '去瑕疵'),
  _MenuItem(BeautifyMenu.restore, Icons.high_quality, '画质修复'),
  _MenuItem(BeautifyMenu.sharpen, Icons.shutter_speed, '清晰'),
  _MenuItem(BeautifyMenu.denoise, Icons.blur_circular, '去噪点'),
  _MenuItem(BeautifyMenu.grain, Icons.grain, '颗粒感'),
  _MenuItem(BeautifyMenu.vignette, Icons.brightness_3, '边缘变暗'),
  _MenuItem(BeautifyMenu.perspective, Icons.crop_rotate, '形状纠正'),
  _MenuItem(BeautifyMenu.straighten, Icons.straighten, '拉直'),
];
