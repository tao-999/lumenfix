class PosterizeParams {
  final int levels; // 2..255
  const PosterizeParams({this.levels = 4});
  PosterizeParams copyWith({int? levels}) => PosterizeParams(levels: levels ?? this.levels);
}
