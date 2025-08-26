import 'package:flutter/material.dart';

/// 再用 H/S/L 三个滑杆对匹配到的像素做偏移；支持软混合。
class ReplaceColorParams {
  final bool enabled;
  final Color sampleColor;
  final double tolerance; // 0..100
  final double hueShift;  // -180..180
  final double satShift;  // -100..100
  final double lightShift;// -100..100

  const ReplaceColorParams({
    this.enabled = false,
    this.sampleColor = const Color(0xFFFF0000),
    this.tolerance = 0,
    this.hueShift = 0,
    this.satShift = 0,
    this.lightShift = 0,
  });

  // 关键：未启用 => 直接视为“中性”
  bool get isNeutral =>
      !enabled ||
          (tolerance <= 0 && hueShift == 0 && satShift == 0 && lightShift == 0);

  ReplaceColorParams copyWith({
    bool? enabled,
    Color? sampleColor,
    double? tolerance,
    double? hueShift,
    double? satShift,
    double? lightShift,
  }) {
    return ReplaceColorParams(
      enabled: enabled ?? this.enabled,
      sampleColor: sampleColor ?? this.sampleColor,
      tolerance: tolerance ?? this.tolerance,
      hueShift: hueShift ?? this.hueShift,
      satShift: satShift ?? this.satShift,
      lightShift: lightShift ?? this.lightShift,
    );
  }
}

