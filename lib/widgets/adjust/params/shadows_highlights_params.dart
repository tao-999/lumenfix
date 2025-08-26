class ShadowsHighlightsParams {
  final double shAmount, shTone, shRadius;
  final double hiAmount, hiTone, hiRadius;
  final double color; // -100..100
  const ShadowsHighlightsParams({
    this.shAmount = 0, this.shTone = 25, this.shRadius = 12,
    this.hiAmount = 0, this.hiTone = 25, this.hiRadius = 12,
    this.color = 0,
  });
  ShadowsHighlightsParams copyWith({
    double? shAmount,double? shTone,double? shRadius,
    double? hiAmount,double? hiTone,double? hiRadius,
    double? color,
  }) => ShadowsHighlightsParams(
    shAmount: shAmount ?? this.shAmount, shTone: shTone ?? this.shTone, shRadius: shRadius ?? this.shRadius,
    hiAmount: hiAmount ?? this.hiAmount, hiTone: hiTone ?? this.hiTone, hiRadius: hiRadius ?? this.hiRadius,
    color: color ?? this.color,
  );
}
