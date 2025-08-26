class PosterizeParams {
  final bool enabled;     // ✅ 新增：启用/关闭
  final int levels;       // 2..255

  const PosterizeParams({
    this.enabled = false, // ✅ 默认关闭
    this.levels = 4,      // PS 默认 4
  });

  // 未启用视为“中性” → 管线里不会应用
  bool get isNeutral => !enabled;

  PosterizeParams copyWith({bool? enabled, int? levels}) =>
      PosterizeParams(
        enabled: enabled ?? this.enabled,
        levels: levels ?? this.levels,
      );
}
