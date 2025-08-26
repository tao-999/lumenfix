// lib/widgets/adjust/params/photo_filter_params.dart
import 'package:flutter/material.dart';

class PhotoFilterParams {
  final Color color;
  final double density; // 0..1
  final bool preserveLum;
  const PhotoFilterParams({
    this.color = const Color(0xFFFF8A00),
    this.density = 0.25,
    this.preserveLum = true,
  });
  PhotoFilterParams copyWith({Color? color, double? density, bool? preserveLum})
  => PhotoFilterParams(
    color: color ?? this.color,
    density: density ?? this.density,
    preserveLum: preserveLum ?? this.preserveLum,
  );
}
