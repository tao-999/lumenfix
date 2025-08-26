// lib/widgets/adjust/params/channel_mixer_params.dart
class ChannelMixerParams {
  /// 3x3 矩阵 + 偏置，范围推荐 -2..+2（= -200%..+200%）
  /// 按行存： [r.r, r.g, r.b,  g.r, g.g, g.b,  b.r, b.g, b.b]
  final List<double> matrix;
  /// 偏置/常量：[rOff, gOff, bOff]
  final List<double> offset;

  /// 单色（Monochrome）：用一组 RGB 系数合成灰度，再赋给三个通道
  final bool monochrome;

  const ChannelMixerParams({
    this.matrix = const [1,0,0, 0,1,0, 0,0,1],
    this.offset = const [0,0,0],
    this.monochrome = false,
  });

  ChannelMixerParams copyWith({
    List<double>? matrix,
    List<double>? offset,
    bool? monochrome,
  }) => ChannelMixerParams(
    matrix: matrix ?? this.matrix,
    offset: offset ?? this.offset,
    monochrome: monochrome ?? this.monochrome,
  );

  /// —— 小工具：读/写某一系数 —— //
  double coef(int out, int comp) => matrix[out * 3 + comp];
  ChannelMixerParams setCoef(int out, int comp, double v) {
    final m = List<double>.from(matrix);
    m[out * 3 + comp] = v;
    return copyWith(matrix: m);
  }
  double bias(int out) => offset[out];
  ChannelMixerParams setBias(int out, double v) {
    final o = List<double>.from(offset)..[out] = v;
    return copyWith(offset: o);
  }
}
