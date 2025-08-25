import 'package:flutter/material.dart';

class SVSquare extends StatefulWidget {
  const SVSquare({
    super.key,
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;        // 0..360
  final double saturation; // 0..1
  final double value;      // 0..1
  final void Function(double s, double v) onChanged;

  @override
  State<SVSquare> createState() => _SVSquareState();
}

class _SVSquareState extends State<SVSquare> {
  late double _s, _v;

  @override
  void initState() {
    super.initState();
    _s = widget.saturation;
    _v = widget.value;
  }

  @override
  void didUpdateWidget(covariant SVSquare oldWidget) {
    super.didUpdateWidget(oldWidget);
    _s = widget.saturation;
    _v = widget.value;
  }

  void _handle(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = 1.0 - (local.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      _s = s;
      _v = v;
    });
    widget.onChanged(s, v);
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, widget.hue, 1, 1).toColor();

    return LayoutBuilder(
      builder: (_, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final knob = Offset(_s * size.width, (1 - _v) * size.height);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,        // 关键：透明也吃手势
          onPanDown: (d) => _handle(d.localPosition, size),
          onPanUpdate: (d) => _handle(d.localPosition, size),
          child: CustomPaint(
            painter: _SVPainter(hueColor),
            foregroundPainter: _KnobPainter(knob),
          ),
        );
      },
    );
  }
}

class _SVPainter extends CustomPainter {
  _SVPainter(this.hueColor);
  final Color hueColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 横向：白 -> hueColor（饱和度）
    final sat = LinearGradient(
      colors: [Colors.white, hueColor],
    ).createShader(rect);
    // 纵向：透明 -> 黑（明度）
    final val = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    ).createShader(rect);

    final p1 = Paint()..shader = sat;
    final p2 = Paint()..shader = val;
    canvas.drawRect(rect, p1);
    canvas.drawRect(rect, p2);
  }

  @override
  bool shouldRepaint(covariant _SVPainter oldDelegate) =>
      oldDelegate.hueColor != hueColor;
}

class _KnobPainter extends CustomPainter {
  _KnobPainter(this.center);
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final r = 8.0;
    canvas.drawCircle(center, r + 2, Paint()..color = Colors.black54);
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) =>
      oldDelegate.center != center;
}
