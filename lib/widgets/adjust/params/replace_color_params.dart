import 'dart:ui';

class ReplaceColorParams {
  final Color from, to;
  final double fuzziness; // 0..1
  final double strength;  // 0..1
  const ReplaceColorParams({this.from = const Color(0xFFFF0000), this.to = const Color(0xFF00FF00), this.fuzziness = 0.1, this.strength = 1.0});
  ReplaceColorParams copyWith({Color? from,Color? to,double? fuzziness,double? strength}) =>
      ReplaceColorParams(from: from ?? this.from, to: to ?? this.to, fuzziness: fuzziness ?? this.fuzziness, strength: strength ?? this.strength);
}
