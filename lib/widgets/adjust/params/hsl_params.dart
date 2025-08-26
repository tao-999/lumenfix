import 'package:flutter/foundation.dart';
import 'dart:math' as math;

enum HslBand { master, red, yellow, green, cyan, blue, magenta }

@immutable
class HslBandAdjust {
  final double hueDeg;       // -180..180
  final double satPercent;   // -100..100
  final double lightPercent; // -100..100
  const HslBandAdjust({this.hueDeg = 0, this.satPercent = 0, this.lightPercent = 0});
  HslBandAdjust copyWith({double? hueDeg,double? satPercent,double? lightPercent}) =>
      HslBandAdjust(hueDeg: hueDeg ?? this.hueDeg, satPercent: satPercent ?? this.satPercent, lightPercent: lightPercent ?? this.lightPercent);
  bool get isNeutral => hueDeg == 0 && satPercent == 0 && lightPercent == 0;
}

@immutable
class HslParams {
  final Map<HslBand, HslBandAdjust> bands;
  final bool colorize;
  final double colorizeHueDeg;        // 0..360
  final double colorizeSatPercent;    // 0..100
  final double colorizeLightPercent;  // -100..100
  final double featherDeg;            // 0..90
  const HslParams({
    required this.bands,
    this.colorize = false,
    this.colorizeHueDeg = 0,
    this.colorizeSatPercent = 25,
    this.colorizeLightPercent = 0,
    this.featherDeg = 30,
  });
  HslParams copyWith({
    Map<HslBand, HslBandAdjust>? bands,bool? colorize,
    double? colorizeHueDeg,double? colorizeSatPercent,double? colorizeLightPercent,
    double? featherDeg,
  }) => HslParams(
    bands: bands ?? this.bands,
    colorize: colorize ?? this.colorize,
    colorizeHueDeg: colorizeHueDeg ?? this.colorizeHueDeg,
    colorizeSatPercent: colorizeSatPercent ?? this.colorizeSatPercent,
    colorizeLightPercent: colorizeLightPercent ?? this.colorizeLightPercent,
    featherDeg: featherDeg ?? this.featherDeg,
  );
}

const Map<HslBand, double> kBandCentersDeg = {
  HslBand.master: double.nan,
  HslBand.red: 0, HslBand.yellow: 60, HslBand.green: 120,
  HslBand.cyan: 180, HslBand.blue: 240, HslBand.magenta: 300,
};

double circularDistDeg(double a, double b) {
  double wrap(double d){ d%=360; return d<0?d+360:d; }
  final diff = (wrap(a)-wrap(b)).abs();
  return math.min(diff, 360-diff);
}

// ✅ 中性默认，供 AdjustParams const 使用
const HslParams kHslNeutral = HslParams(
  bands: {
    HslBand.master:  HslBandAdjust(),
    HslBand.red:     HslBandAdjust(),
    HslBand.yellow:  HslBandAdjust(),
    HslBand.green:   HslBandAdjust(),
    HslBand.cyan:    HslBandAdjust(),
    HslBand.blue:    HslBandAdjust(),
    HslBand.magenta: HslBandAdjust(),
  },
  colorize: false,
  colorizeHueDeg: 0,
  colorizeSatPercent: 25,
  colorizeLightPercent: 0,
  featherDeg: 30,
);

// 🔁 兼容旧代码（可等整体替换后删除）
typedef HueSaturationParams = HslParams;
