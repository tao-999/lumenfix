// lib/widgets/adjust/params/invert_params.dart
class InvertParams {
  final bool enabled; // 勾上就反相
  const InvertParams({this.enabled = false});

  InvertParams copyWith({bool? enabled}) =>
      InvertParams(enabled: enabled ?? this.enabled);

  bool get isNeutral => !enabled;
}
