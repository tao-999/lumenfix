// lib/widgets/adjust/params/black_white_params.dart
import 'dart:ui';

class BlackWhiteParams {
  final double r, g, b;       // 通道权重
  final bool tintEnable;
  final Color tintColor;
  final double tintStrength;  // 0..1

  const BlackWhiteParams({
    this.r = 0.3,
    this.g = 0.59,
    this.b = 0.11,
    this.tintEnable = false,
    this.tintColor = const Color(0xFFFFE0B2),
    this.tintStrength = 0.0, // ✅ 正确字段名
  });

  BlackWhiteParams copyWith({
    double? r,
    double? g,
    double? b,
    bool? tintEnable,
    Color? tintColor,
    double? tintStrength,
  }) =>
      BlackWhiteParams(
        r: r ?? this.r,
        g: g ?? this.g,
        b: b ?? this.b,
        tintEnable: tintEnable ?? this.tintEnable,
        tintColor: tintColor ?? this.tintColor,
        tintStrength: tintStrength ?? this.tintStrength, // ✅
      );
}
