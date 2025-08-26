import 'package:flutter/material.dart';

/// 目标色域（对标 Photoshop）
enum SelectiveColorTarget {
  reds, yellows, greens, cyans, blues, magentas, whites, neutrals, blacks
}

class SelectiveColorParams {
  final SelectiveColorTarget target;
  // CMYK 风格百分比：-100..100
  final double cyan;
  final double magenta;
  final double yellow;
  final double black;
  // 绝对模式（不勾选为相对模式）
  final bool absolute;

  const SelectiveColorParams({
    this.target = SelectiveColorTarget.reds,
    this.cyan = 0,
    this.magenta = 0,
    this.yellow = 0,
    this.black = 0,
    this.absolute = false,
  });

  SelectiveColorParams copyWith({
    SelectiveColorTarget? target,
    double? cyan,
    double? magenta,
    double? yellow,
    double? black,
    bool? absolute,
  }) {
    return SelectiveColorParams(
      target: target ?? this.target,
      cyan: cyan ?? this.cyan,
      magenta: magenta ?? this.magenta,
      yellow: yellow ?? this.yellow,
      black: black ?? this.black,
      absolute: absolute ?? this.absolute,
    );
  }

  bool get isNeutral => cyan == 0 && magenta == 0 && yellow == 0 && black == 0;
}
