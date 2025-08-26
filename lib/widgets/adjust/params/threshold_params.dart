class ThresholdParams {
  final int level; // 0..255
  const ThresholdParams({this.level = 128});
  ThresholdParams copyWith({int? level}) => ThresholdParams(level: level ?? this.level);
}
