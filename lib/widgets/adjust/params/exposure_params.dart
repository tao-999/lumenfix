import 'package:flutter/foundation.dart';

class ExposureParams {
  final double ev;      // -4..+4
  final double offset;  // -0.5..+0.5
  final double gamma;   // 0.10..3.00
  const ExposureParams({this.ev = 0.0, this.offset = 0.0, this.gamma = 1.0});
  ExposureParams copyWith({double? ev, double? offset, double? gamma}) =>
      ExposureParams(ev: ev ?? this.ev, offset: offset ?? this.offset, gamma: gamma ?? this.gamma);
}
