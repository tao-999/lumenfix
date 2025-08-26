class SelectiveColorParams {
  final double targetHue; // 0..360
  final double range;     // 5..90
  final double cyan, magenta, yellow, black; // -100..100
  const SelectiveColorParams({this.targetHue = 0, this.range = 30, this.cyan = 0, this.magenta = 0, this.yellow = 0, this.black = 0});
  SelectiveColorParams copyWith({double? targetHue,double? range,double? cyan,double? magenta,double? yellow,double? black}) =>
      SelectiveColorParams(targetHue: targetHue ?? this.targetHue, range: range ?? this.range, cyan: cyan ?? this.cyan, magenta: magenta ?? this.magenta, yellow: yellow ?? this.yellow, black: black ?? this.black);
}
