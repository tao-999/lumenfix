import 'package:flutter/material.dart';

/// 黑白（B&W）参数
/// - 六色权重：对不同色相的亮度缩放（0..255，128为中性）
/// - enabled：是否启用黑白；默认关闭（防止一上来就变灰）
/// - 着色：可选上色，强度 0..1
class BlackWhiteParams {
  final bool enabled;

  final int reds;     // 0..255 (128中性)
  final int yellows;  // 0..255
  final int greens;   // 0..255
  final int cyans;    // 0..255
  final int blues;    // 0..255
  final int magentas; // 0..255

  final bool tintEnable;
  final Color tintColor;
  final double tintStrength; // 0..1

  const BlackWhiteParams({
    this.enabled = false,
    // 对齐 PS/Photopea 的常见默认（观感较舒服）
    this.reds = 40,
    this.yellows = 60,
    this.greens = 40,
    this.cyans = 60,
    this.blues = 20,
    this.magentas = 80,
    this.tintEnable = false,
    this.tintColor = const Color(0xFF2399CF), // 截图里的默认蓝
    this.tintStrength = 0.35,
  });

  BlackWhiteParams copyWith({
    bool? enabled,
    int? reds, int? yellows, int? greens, int? cyans, int? blues, int? magentas,
    bool? tintEnable, Color? tintColor, double? tintStrength,
  }) => BlackWhiteParams(
    enabled: enabled ?? this.enabled,
    reds: reds ?? this.reds,
    yellows: yellows ?? this.yellows,
    greens: greens ?? this.greens,
    cyans: cyans ?? this.cyans,
    blues: blues ?? this.blues,
    magentas: magentas ?? this.magentas,
    tintEnable: tintEnable ?? this.tintEnable,
    tintColor: tintColor ?? this.tintColor,
    tintStrength: tintStrength ?? this.tintStrength,
  );
}
