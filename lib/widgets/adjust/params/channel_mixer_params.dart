class ChannelMixerParams {
  final List<double> matrix; // 9
  final List<double> offset; // 3
  const ChannelMixerParams({this.matrix = const [1,0,0, 0,1,0, 0,0,1], this.offset = const [0,0,0]});
  ChannelMixerParams copyWith({List<double>? matrix,List<double>? offset}) =>
      ChannelMixerParams(matrix: matrix ?? this.matrix, offset: offset ?? this.offset);
}
