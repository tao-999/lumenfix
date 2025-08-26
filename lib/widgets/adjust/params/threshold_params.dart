// lib/widgets/adjust/params/threshold_params.dart
class ThresholdParams {
  /// 是否应用阈值（二值化）
  final bool enabled;

  /// 阈值等级 1..255（默认 128）
  final int level;

  const ThresholdParams({
    this.enabled = false,
    this.level = 128,
  });

  ThresholdParams copyWith({bool? enabled, int? level}) => ThresholdParams(
    enabled: enabled ?? this.enabled,
    level: level ?? this.level,
  );
}
