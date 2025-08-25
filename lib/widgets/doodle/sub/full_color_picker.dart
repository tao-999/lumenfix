import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'hue_bar.dart';
import 'sv_square.dart';
import 'alpha_bar.dart';

class FullColorPicker extends StatefulWidget {
  const FullColorPicker({
    super.key,
    required this.initial,
    this.allowAlpha = true,
  });

  final Color initial;
  final bool allowAlpha;

  /// 用对话框弹出（非全屏 sheet），避免边缘拖拽冲突
  static Future<Color?> show(
      BuildContext context, {
        Color initial = Colors.white,
        bool allowAlpha = true,
      }) {
    return showDialog<Color>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: FullColorPicker(initial: initial, allowAlpha: allowAlpha),
      ),
    );
  }

  @override
  State<FullColorPicker> createState() => _FullColorPickerState();
}

class _FullColorPickerState extends State<FullColorPicker> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();

    // 面板目标宽度：居中 + 有左右留白，不触碰屏幕边缘
    final screenW = MediaQuery.of(context).size.width;
    double panelW = screenW * 0.86;
    panelW = panelW.clamp(280.0, 420.0);          // ✅ 统一宽度范围
    final barsW = math.max(panelW * 0.86, 240.0); // ✅ Hue/Alpha 条比面板窄

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: panelW + 24, // 外层卡片一点内边距
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶栏
                Row(
                  children: [
                    const Expanded(
                      child: Text('选择颜色',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(color),
                      child: const Text('完成'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 预览
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ✅ 颜色面板：严格正方形（不吃全屏高度）
                SizedBox(
                  width: panelW,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: SVSquare(
                      hue: _hsv.hue,
                      saturation: _hsv.saturation,
                      value: _hsv.value,
                      onChanged: (s, v) => setState(() {
                        _hsv = _hsv.withSaturation(s).withValue(v);
                      }),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ✅ Hue 条：比面板窄，避免边缘滑动触发返回
                SizedBox(
                  width: barsW,
                  child: HueBar(
                    hue: _hsv.hue,
                    onChanged: (h) => setState(() => _hsv = _hsv.withHue(h)),
                  ),
                ),

                if (widget.allowAlpha) ...[
                  const SizedBox(height: 10),
                  // ✅ Alpha 条：同样窄
                  SizedBox(
                    width: barsW,
                    child: AlphaBar(
                      color: _hsv.toColor().withOpacity(1),
                      alpha: _hsv.toColor().opacity,
                      onChanged: (a) => setState(() {
                        _hsv = HSVColor.fromAHSV(
                          a, _hsv.hue, _hsv.saturation, _hsv.value,
                        );
                      }),
                    ),
                  ),
                ],

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
