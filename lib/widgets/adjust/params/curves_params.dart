import 'dart:ui';

class CurveChannel {
  final List<Offset> points; // 0..1 归一化
  const CurveChannel(this.points);
  CurveChannel copyWith({List<Offset>? points}) => CurveChannel(points ?? this.points);
}
class CurvesParams {
  final CurveChannel master, r, g, b;
  const CurvesParams({
    this.master = const CurveChannel([Offset(0,0), Offset(1,1)]),
    this.r = const CurveChannel([Offset(0,0), Offset(1,1)]),
    this.g = const CurveChannel([Offset(0,0), Offset(1,1)]),
    this.b = const CurveChannel([Offset(0,0), Offset(1,1)]),
  });
  CurvesParams copyWith({CurveChannel? master, CurveChannel? r, CurveChannel? g, CurveChannel? b}) =>
      CurvesParams(master: master ?? this.master, r: r ?? this.r, g: g ?? this.g, b: b ?? this.b);
}
