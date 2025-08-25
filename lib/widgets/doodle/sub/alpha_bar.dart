// lib/widgets/doodle/sub/color_picker/alpha_bar.dart
import 'package:flutter/material.dart';

class AlphaBar extends StatefulWidget {
  const AlphaBar({
    super.key,
    required this.color,  // 基色（无透明）
    required this.alpha,  // 0..1
    required this.onChanged,
  });

  final Color color;
  final double alpha;
  final ValueChanged<double> onChanged;

  @override
  State<AlphaBar> createState() => _AlphaBarState();
}

class _AlphaBarState extends State<AlphaBar> {
  late double _a;

  @override
  void initState() {
    super.initState();
    _a = widget.alpha;
  }

  @override
  void didUpdateWidget(covariant AlphaBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _a = widget.alpha;
  }

  void _handle(Offset local, Size size) {
    final ratio = (local.dx / size.width).clamp(0.0, 1.0);
    setState(() => _a = ratio);
    widget.onChanged(ratio);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: LayoutBuilder(
        builder: (_, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          final pos = _a * size.width;
          final c0 = widget.color.withOpacity(0);
          final c1 = widget.color.withOpacity(1);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _handle(d.localPosition, size),
            onPanUpdate: (d) => _handle(d.localPosition, size),
            child: CustomPaint(
              painter: _AlphaPainter(c0, c1),
              foregroundPainter: _TickPainter(pos),
            ),
          );
        },
      ),
    );
  }
}

class _AlphaPainter extends CustomPainter {
  _AlphaPainter(this.c0, this.c1);
  final Color c0, c1;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 棋盘格背景
    const cell = 6.0;
    final p1 = Paint()..color = const Color(0xFF555555);
    final p2 = Paint()..color = const Color(0xFF777777);
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final even = (((x / cell).floor() + (y / cell).floor()) % 2 == 0);
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), even ? p1 : p2);
      }
    }

    final shader = LinearGradient(colors: [c0, c1]).createShader(rect);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..shader = shader);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white24,
    );
  }

  @override
  bool shouldRepaint(covariant _AlphaPainter oldDelegate) =>
      oldDelegate.c0 != c0 || oldDelegate.c1 != c1;
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.x);
  final double x;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) => oldDelegate.x != x;
}
