import 'package:flutter/foundation.dart';

class LevelsParams {
  final int inBlack, inWhite, outBlack, outWhite; // 0..255
  final double gamma; // 0.10..3.0
  const LevelsParams({this.inBlack = 0, this.inWhite = 255, this.gamma = 1.0, this.outBlack = 0, this.outWhite = 255});
  LevelsParams copyWith({int? inBlack,int? inWhite,double? gamma,int? outBlack,int? outWhite}) =>
      LevelsParams(inBlack: inBlack ?? this.inBlack, inWhite: inWhite ?? this.inWhite, gamma: gamma ?? this.gamma,
          outBlack: outBlack ?? this.outBlack, outWhite: outWhite ?? this.outWhite);
}
