import 'dart:ui';

class MatchColorParams {
  final Image? reference;
  final double strength; // 0..1
  const MatchColorParams({this.reference, this.strength = 0});
  MatchColorParams copyWith({Image? reference,double? strength}) =>
      MatchColorParams(reference: reference ?? this.reference, strength: strength ?? this.strength);
}
