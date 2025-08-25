// lib/widgets/doodle/sub/color_picker/hue_bar.dart
import 'package:flutter/material.dart';

class HueBar extends StatefulWidget {
  const HueBar({super.key, required this.hue, required this.onChanged});
  final double hue; // 0..360
  final ValueChanged<double> onChanged;

  @override
  State<HueBar> createState() => _HueBarState();
}

class _HueBarState extends State<HueBar> {
  late double _h;

  @override
  void initState() {
    super.initState();
    _h = widget.hue;
  }

  @override
  void didUpdateWidget(covariant HueBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _h = widget.hue;
  }

  void _handle(Offset local, Size size) {
    final ratio = (local.dx / size.width).clamp(0.0, 1.0);
    final h = ratio * 360.0;
    setState(() => _h = h);
    widget.onChanged(h);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32, // 给手势更大命中
      child: LayoutBuilder(
        builder: (_, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          final pos = (_h / 360.0) * size.width;

          return GestureDetector(
            behavior: HitTestBehavior.opaque, // 透明区域也吃手势
            onPanDown: (d) => _handle(d.localPosition, size),
            onPanUpdate: (d) => _handle(d.localPosition, size),
            child: CustomPaint(
              painter: _HuePainter(),
              foregroundPainter: _TickPainter(pos),
            ),
          );
        },
      ),
    );
  }
}

class _HuePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 7 段覆盖 0..360
    final shader = const LinearGradient(
      colors: <Color>[
        Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
        Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
        Color(0xFFFF0000),
      ],
    ).createShader(rect);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..shader = shader);
    // 边框更清晰
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white24,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
