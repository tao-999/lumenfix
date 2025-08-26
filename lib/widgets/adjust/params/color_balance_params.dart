import 'package:flutter/material.dart';

/// 单个轮：青<->红、品红<->绿、黄<->蓝（-100..100）
class ColorBalanceWheel {
  final double cr; // Cyan(-) <-> Red(+)
  final double mg; // Magenta(-) <-> Green(+)
  final double yb; // Yellow(-) <-> Blue(+)

  const ColorBalanceWheel({this.cr = 0, this.mg = 0, this.yb = 0});

  ColorBalanceWheel copyWith({double? cr, double? mg, double? yb}) =>
      ColorBalanceWheel(cr: cr ?? this.cr, mg: mg ?? this.mg, yb: yb ?? this.yb);

  bool get isNeutral => cr == 0 && mg == 0 && yb == 0;
}

/// 色彩平衡总参数
class ColorBalanceParams {
  final ColorBalanceWheel shadows;
  final ColorBalanceWheel mids;
  final ColorBalanceWheel highs;
  final bool preserveLuminosity; // ✅ 保留明度（亮度整体不变）

  const ColorBalanceParams({
    this.shadows = const ColorBalanceWheel(),
    this.mids = const ColorBalanceWheel(),
    this.highs = const ColorBalanceWheel(),
    this.preserveLuminosity = true,
  });

  ColorBalanceParams copyWith({
    ColorBalanceWheel? shadows,
    ColorBalanceWheel? mids,
    ColorBalanceWheel? highs,
    bool? preserveLuminosity,
  }) =>
      ColorBalanceParams(
        shadows: shadows ?? this.shadows,
        mids: mids ?? this.mids,
        highs: highs ?? this.highs,
        preserveLuminosity: preserveLuminosity ?? this.preserveLuminosity,
      );

  bool get isNeutral =>
      shadows.isNeutral && mids.isNeutral && highs.isNeutral;
}
