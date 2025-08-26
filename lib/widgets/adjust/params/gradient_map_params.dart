import 'dart:ui';

class GradientMapParams {
  final Color left, right;
  final double strength; // 0..1
  const GradientMapParams({this.left = const Color(0xFF000000), this.right = const Color(0xFFFFFFFF), this.strength = 1.0});
  GradientMapParams copyWith({Color? left,Color? right,double? strength}) =>
      GradientMapParams(left: left ?? this.left, right: right ?? this.right, strength: strength ?? this.strength);
}
