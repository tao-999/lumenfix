import 'package:flutter/material.dart';

class IconPen extends CustomPainter {
  const IconPen();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(6, s.height * .7)
      ..quadraticBezierTo(s.width * .4, s.height * .15, s.width - 6, s.height * .35);
    c.drawPath(path, p);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class IconMarker extends CustomPainter {
  const IconMarker();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, s.height*0.2, s.width-16, s.height*0.6),
        const Radius.circular(6),
      ),
      p,
    );
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class IconHighlighter extends CustomPainter {
  const IconHighlighter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white.withOpacity(.4);
    c.drawRect(Rect.fromLTWH(6, s.height*0.35, s.width-12, s.height*0.3), p);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class IconNeon extends CustomPainter {
  const IconNeon();
  @override
  void paint(Canvas c, Size s) {
    final glow = Paint()
      ..color = Colors.white.withOpacity(.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final core = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(6, s.height * .65)
      ..quadraticBezierTo(s.width * .45, s.height * .15, s.width - 6, s.height * .4);
    c.drawPath(path, glow);
    c.drawPath(path, core);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class IconEraser extends CustomPainter {
  const IconEraser();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, s.height*0.25, s.width-16, s.height*0.5),
        const Radius.circular(6),
      ),
      p,
    );
    c.drawRect(Rect.fromLTWH(6, s.height*0.7, s.width-12, 3), Paint()..color = Colors.white54);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
