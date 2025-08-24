import 'dart:math' as math;
import 'package:flutter/material.dart';

class IconPixel extends CustomPainter {
  const IconPixel();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white;
    const n = 3;
    const g = 3.0;
    final cell = (s.shortestSide - g * (n - 1)) / n;
    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * (cell + g), y * (cell + g), cell, cell),
            const Radius.circular(2),
          ),
          p,
        );
      }
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class IconBlur extends CustomPainter {
  const IconBlur();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white70, Colors.white24],
      ).createShader(Offset.zero & s);
    c.drawCircle(Offset(s.width / 2, s.height / 2), s.shortestSide * 0.38, p);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class IconHex extends CustomPainter {
  const IconHex();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white;
    final r = s.shortestSide * 0.28;
    for (int i = 0; i < 3; i++) {
      final cx = s.width * (0.3 + 0.4 * (i % 2));
      final cy = s.height * (0.3 + 0.4 * (i ~/ 2));
      final path = Path();
      for (int k = 0; k < 6; k++) {
        final a = (k * 60.0 - 30.0) * math.pi / 180.0;
        final x = cx + r * math.cos(a);
        final y = cy + r * math.sin(a);
        if (k == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      path.close();
      c.drawPath(path, p);
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class IconGlass extends CustomPainter {
  const IconGlass();
  @override
  void paint(Canvas c, Size s) {
    final p1 = Paint()..color = Colors.white;
    final p2 = Paint()..color = Colors.white38;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 10, s.width - 8, s.height - 20),
      const Radius.circular(6),
    );
    c.drawRRect(r, p2);
    c.drawRect(Rect.fromLTWH(6, 12, s.width - 12, (s.height - 24) / 2), p1);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class IconBars extends CustomPainter {
  const IconBars();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white;
    final h = (s.height - 6) / 3;
    for (int i = 0; i < 3; i++) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(3, 3 + i * h, s.width - 6, h - 3),
          const Radius.circular(3),
        ),
        p,
      );
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
