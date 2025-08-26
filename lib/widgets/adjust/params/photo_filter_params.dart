import 'package:flutter/material.dart';

class PhotoFilterParams {
  final bool enabled;       // ✅ 新增：启用/关闭
  final Color color;
  final double density;     // 0..1
  final bool preserveLum;

  const PhotoFilterParams({
    this.enabled = false,                   // ✅ 默认关闭
    this.color = const Color(0xFFFF8A00),
    this.density = 0.25,
    this.preserveLum = true,
  });

  /// ✅ 未启用或密度为 0 视为“中性”，管线里就不应用
  bool get isNeutral => !enabled || density <= 0.0;

  PhotoFilterParams copyWith({
    bool? enabled,
    Color? color,
    double? density,
    bool? preserveLum,
  }) => PhotoFilterParams(
    enabled: enabled ?? this.enabled,
    color: color ?? this.color,
    density: density ?? this.density,
    preserveLum: preserveLum ?? this.preserveLum,
  );
}
