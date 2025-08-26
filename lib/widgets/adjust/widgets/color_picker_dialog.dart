// lib/widgets/adjust/widgets/color_picker_dialog.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 调用：final c = await showBwTintColorPicker(context, initialColor);
Future<Color?> showBwTintColorPicker(
    BuildContext context,
    Color initial, {
      List<Color>? presets,
    }) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(
      initial: initial,
      presets: presets ??
          const [
            Color(0xFF000000), Color(0xFFFFFFFF),
            Color(0xFFFF3B30), Color(0xFFFFCC00),
            Color(0xFF34C759), Color(0xFF007AFF),
            Color(0xFF5856D6), Color(0xFFFF2D55),
            Color(0xFF2399CF), Color(0xFFFF9800),
          ],
    ),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial, required this.presets});
  final Color initial;
  final List<Color> presets;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      surfaceTintColor: Colors.transparent,
      title: const Text('拾色器', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        height: 320, // 只固定高度，宽度让对话框自己给
        child: Row(
          children: [
            // === 左：SV 方块（可伸缩） ===
            Expanded(
              child: _SvSquare(
                hue: _hsv.hue,
                s: _hsv.saturation,
                v: _hsv.value,
                onChanged: (s, v) => setState(() => _hsv = _hsv.withSaturation(s).withValue(v)),
              ),
            ),
            const SizedBox(width: 12),

            // === 中：Hue 竖条（固定 22px） ===
            SizedBox(
              width: 22,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HueBar(
                    hue: _hsv.hue,
                    onChanged: (h) => setState(() => _hsv = _hsv.withHue(h)),
                    height: 220,
                    width: 22,
                  ),
                  const SizedBox(height: 10),
                  _Swatch(color: _hsv.toColor(), size: const Size(56, 28)),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // 右：信息/预设面板（可压缩 + 可滚动）
            Flexible(
              flex: 3,
              child: SingleChildScrollView( // ⬅️ 关键：避免 Column 超高溢出
                padding: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 120),
                  child: DefaultTextStyle(
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kv('H', '${_hsv.hue.round()}°'),
                        _kv('S', '${(_hsv.saturation * 100).round()}%'),
                        _kv('B', '${(_hsv.value * 100).round()}%'),
                        const SizedBox(height: 6),
                        ..._rgbRows(_hsv.toColor()),
                        const SizedBox(height: 6),
                        _kv('#', _hex(_hsv.toColor())),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.presets.map((c) => GestureDetector(
                            onTap: () => setState(() => _hsv = HSVColor.fromColor(c)),
                            child: _Swatch(color: c),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        // 用 styleFrom 保守兼容
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _color,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('确定'),
        ),
      ],
    );
  }

  // ---- 小工具们 ----

  // 数值行：左 label 右等宽 value
  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 18, child: Text(k, style: const TextStyle(color: Colors.white70))),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(v, textAlign: TextAlign.right),
            ),
          ),
        ],
      ),
    );
  }

  // 兼容性最好的取 RGB：位运算
  List<Widget> _rgbRows(Color c) {
    final v = c.value;
    final r = (v >> 16) & 0xFF;
    final g = (v >> 8)  & 0xFF;
    final b = (v      ) & 0xFF;
    return [
      _kv('R', r.toString()),
      _kv('G', g.toString()),
      _kv('B', b.toString()),
    ];
  }

  static String _hex(Color c) =>
      c.value.toRadixString(16).padLeft(8, '0').substring(2).toLowerCase();
}

class _SvSquare extends StatelessWidget {
  const _SvSquare({required this.hue, required this.s, required this.v, required this.onChanged});
  final double hue; // 0..360
  final double s;   // 0..1
  final double v;   // 0..1
  final void Function(double s, double v) onChanged;

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth, h = c.maxHeight;
        final pos = Offset(s * w, (1 - v) * h);
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition, w, h),
          onPanUpdate: (d) => _update(d.localPosition, w, h),
          child: Stack(
            children: [
              // 白->色 再叠加黑
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, hueColor],
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                  ),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              CustomPaint(size: Size.infinite, painter: _CursorPainter(pos)),
            ],
          ),
        );
      },
    );
  }

  void _update(Offset p, double w, double h) {
    final s = (p.dx / w).clamp(0.0, 1.0);
    final v = (1 - p.dy / h).clamp(0.0, 1.0);
    onChanged(s, v);
  }
}

class _HueBar extends StatelessWidget {
  const _HueBar({required this.hue, required this.onChanged, this.height = 220, this.width = 22});
  final double hue; // 0..360
  final double height, width;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _update(d.localPosition.dy),
      onPanUpdate: (d) => _update(d.localPosition.dy),
      child: CustomPaint(
        size: Size(width, height),
        painter: _HueBarPainter(hue: hue),
      ),
    );
  }

  void _update(double y) {
    final t = y.clamp(0.0, height) / height; // 0..1
    onChanged(t * 360.0);
  }
}

class _HueBarPainter extends CustomPainter {
  _HueBarPainter({required this.hue});
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFF0000), Color(0xFFFFFF00),
          Color(0xFF00FF00), Color(0xFF00FFFF),
          Color(0xFF0000FF), Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);

    // 光标线
    final y = hue / 360.0 * size.height;
    final white = Paint()..color = Colors.white..strokeWidth = 2;
    final black = Paint()..color = Colors.black54..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), white);
    canvas.drawLine(Offset(0, y + 1), Offset(size.width, y + 1), black);
  }

  @override
  bool shouldRepaint(covariant _HueBarPainter old) => old.hue != hue;
}

class _CursorPainter extends CustomPainter {
  const _CursorPainter(this.pos);
  final Offset pos;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Offset(
      pos.dx.clamp(0, size.width),
      pos.dy.clamp(0, size.height),
    );
    final outer = Paint()..style = PaintingStyle.stroke..color = Colors.black..strokeWidth = 3;
    final inner = Paint()..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = 2;
    canvas.drawCircle(p, 8, outer);
    canvas.drawCircle(p, 8, inner);
  }

  @override
  bool shouldRepaint(covariant _CursorPainter old) => old.pos != pos;
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.size = const Size(24, 18)});
  final Color color;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width, height: size.height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white38),
      ),
    );
  }
}

extension on HSVColor {
  HSVColor withHue(double h) => HSVColor.fromAHSV(alpha, (h % 360 + 360) % 360, saturation, value);
  HSVColor withSaturation(double s) => HSVColor.fromAHSV(alpha, hue, s.clamp(0.0, 1.0), value);
  HSVColor withValue(double v) => HSVColor.fromAHSV(alpha, hue, saturation, v.clamp(0.0, 1.0));
}
