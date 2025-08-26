import 'dart:ui';

class LutParams {
  final Image? hald;      // HALD CLUT
  final double strength;  // 0..1
  const LutParams({this.hald, this.strength = 0});
  LutParams copyWith({Image? hald,double? strength}) => LutParams(hald: hald ?? this.hald, strength: strength ?? this.strength);
}
