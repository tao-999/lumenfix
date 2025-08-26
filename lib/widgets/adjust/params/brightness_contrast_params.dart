import 'package:flutter/foundation.dart';

class BrightnessContrast {
  final double brightness; // -100..100 (%)
  final double contrast;   // -100..100 (%)
  const BrightnessContrast({this.brightness = 0, this.contrast = 0});
  BrightnessContrast copyWith({double? brightness, double? contrast}) =>
      BrightnessContrast(brightness: brightness ?? this.brightness, contrast: contrast ?? this.contrast);
}
