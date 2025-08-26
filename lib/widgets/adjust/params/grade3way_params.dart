class GradeWheel {
  final double hue, sat, lum; // -180..180 / -100..100 / -100..100
  const GradeWheel({this.hue = 0, this.sat = 0, this.lum = 0});
  GradeWheel copyWith({double? hue,double? sat,double? lum}) => GradeWheel(hue: hue ?? this.hue, sat: sat ?? this.sat, lum: lum ?? this.lum);
}
class Grade3WayParams {
  final GradeWheel shadows, mids, highs;
  final double shadowPivot, highPivot, softness; // pivots: [0..1], softness: 0.05..0.5
  const Grade3WayParams({this.shadows = const GradeWheel(), this.mids = const GradeWheel(), this.highs = const GradeWheel(), this.shadowPivot = 0.25, this.highPivot = 0.75, this.softness = 0.2});
  Grade3WayParams copyWith({GradeWheel? shadows,GradeWheel? mids,GradeWheel? highs,double? shadowPivot,double? highPivot,double? softness}) =>
      Grade3WayParams(shadows: shadows ?? this.shadows, mids: mids ?? this.mids, highs: highs ?? this.highs, shadowPivot: shadowPivot ?? this.shadowPivot, highPivot: highPivot ?? this.highPivot, softness: softness ?? this.softness);
}
