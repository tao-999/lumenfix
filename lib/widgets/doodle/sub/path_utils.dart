import 'package:flutter/material.dart';

/// 将散点平滑成二次贝塞尔曲线，减少锯齿 & 抖动
Path buildSmoothPath(List<Offset> pts) {
  final path = Path();
  if (pts.isEmpty) return path;
  if (pts.length < 3) {
    path.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }

  path.moveTo(pts[0].dx, pts[0].dy);
  for (int i = 1; i < pts.length - 1; i++) {
    final p0 = pts[i];
    final p1 = pts[i + 1];
    final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
  }
  // 尾点
  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}
