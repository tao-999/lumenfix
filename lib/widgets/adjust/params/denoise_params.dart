// 独立的降噪参数
enum DenoiseMode { bilateral, wavelet, nlmLite, median }

class DenoiseParams {
  final bool enabled;
  final DenoiseMode mode;
  /// 0..100 总强度
  final double strength;
  /// 0..100 彩色降噪强度（主要作用于 Cb/Cr）
  final double chroma;
  /// 细节保护（0..100，越大越保边）
  final double edge;
  /// 半径（1..3）
  final int radius;

  const DenoiseParams({
    this.enabled = false,
    this.mode = DenoiseMode.bilateral,
    this.strength = 30,
    this.chroma = 50,
    this.edge = 60,
    this.radius = 2,
  });

  bool get isNeutral => !enabled || (strength <= 0 && chroma <= 0);

  DenoiseParams copyWith({
    bool? enabled,
    DenoiseMode? mode,
    double? strength,
    double? chroma,
    double? edge,
    int? radius,
  }) {
    return DenoiseParams(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      strength: strength ?? this.strength,
      chroma: chroma ?? this.chroma,
      edge: edge ?? this.edge,
      radius: radius ?? this.radius,
    );
  }
}
