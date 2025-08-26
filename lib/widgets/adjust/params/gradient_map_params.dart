import 'package:flutter/material.dart';

/// 渐变停靠点
class GradientStop {
  final Color color;
  final double pos; // 0..1
  const GradientStop({required this.color, required this.pos});
  GradientStop copyWith({Color? color, double? pos})
  => GradientStop(color: color ?? this.color, pos: pos ?? this.pos);
}

/// 渐变方法（补齐 5 种）
enum GradientMethod {
  perceptual,  // 感知均匀（Lab/Lch 思路）
  linear,      // 线性 RGB
  classic,     // 经典（sRGB 直插）
  smooth,      // 平滑（对 t 做 smoothstep）
  stripes,     // 条纹（量化成多段）
}

class GradientMapParams {
  final bool enabled;
  final bool dither;         // 仿色
  final bool reverse;        // 反向
  final double strength;     // 0..1
  final List<GradientStop> stops;
  final GradientMethod method;

  const GradientMapParams({
    this.enabled = false,
    this.dither = false,
    this.reverse = false,
    this.strength = 1.0,
    this.stops = const [
      GradientStop(color: Color(0xFF000000), pos: 0.0),
      GradientStop(color: Color(0xFFFFFFFF), pos: 1.0),
    ],
    this.method = GradientMethod.classic, // 默认 Classic（与截图一致）
  });

  GradientMapParams copyWith({
    bool? enabled,
    bool? dither,
    bool? reverse,
    double? strength,
    List<GradientStop>? stops,
    GradientMethod? method,
  }) => GradientMapParams(
    enabled:  enabled  ?? this.enabled,
    dither:   dither   ?? this.dither,
    reverse:  reverse  ?? this.reverse,
    strength: strength ?? this.strength,
    stops:    stops    ?? this.stops,
    method:   method   ?? this.method,
  );

  bool get isNeutral =>
      !enabled || strength == 0 || stops.length < 2;
}
