class VibranceParams {
  final double vibrance;   // -100..100
  final double saturation; // -100..100
  const VibranceParams({this.vibrance = 0, this.saturation = 0});
  VibranceParams copyWith({double? vibrance,double? saturation}) =>
      VibranceParams(vibrance: vibrance ?? this.vibrance, saturation: saturation ?? this.saturation);
}
