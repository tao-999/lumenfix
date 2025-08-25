import 'package:flutter/material.dart';

enum BokehMode { ellipse, lasso }

class EllipseParams {
  Offset center; // 屏幕坐标
  double rx;     // 半轴（像素）
  double ry;
  double angle;  // 弧度

  EllipseParams({
    required this.center,
    required this.rx,
    required this.ry,
    required this.angle,
  });

  EllipseParams copy() =>
      EllipseParams(center: center, rx: rx, ry: ry, angle: angle);
}
