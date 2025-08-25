import 'package:flutter/material.dart';
import '../../../services/doodle_service.dart';

class DoodleStroke {
  DoodleStroke({
    required this.brush,
    required this.color,
    required this.size,
  });

  final DoodleBrushType brush;
  final Color color;
  final double size;
  final List<Offset> points = [];
  Path? smoothedPath;
}
