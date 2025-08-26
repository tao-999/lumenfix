class ShadowsHighlightsParams {
  final bool enabled;        // ✅ 新增：启用/关闭
  // 阴影
  final double shAmount, shTone, shRadius;
  // 高光
  final double hiAmount, hiTone, hiRadius;
  // 调整
  final double color; // -100..100

  const ShadowsHighlightsParams({
    this.enabled = false,        // ✅ 默认关闭
    this.shAmount = 0, this.shTone = 25, this.shRadius = 12,
    this.hiAmount = 0, this.hiTone = 25, this.hiRadius = 12,
    this.color = 0,
  });

  /// ✅ 未启用视为“中性”，或参数全在默认位也视为“中性”
  bool get isNeutral =>
      !enabled ||
          (shAmount == 0 && hiAmount == 0 && color == 0 &&
              shTone == 25 && hiTone == 25 && shRadius == 12 && hiRadius == 12);

  ShadowsHighlightsParams copyWith({
    bool? enabled,
    double? shAmount, double? shTone, double? shRadius,
    double? hiAmount, double? hiTone, double? hiRadius,
    double? color,
  }) => ShadowsHighlightsParams(
    enabled: enabled ?? this.enabled,               // ✅
    shAmount: shAmount ?? this.shAmount,
    shTone:   shTone   ?? this.shTone,
    shRadius: shRadius ?? this.shRadius,
    hiAmount: hiAmount ?? this.hiAmount,
    hiTone:   hiTone   ?? this.hiTone,
    hiRadius: hiRadius ?? this.hiRadius,
    color:    color    ?? this.color,
  );
}
