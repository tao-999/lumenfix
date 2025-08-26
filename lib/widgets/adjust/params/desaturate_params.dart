class DesaturateParams {
  final bool enabled;
  const DesaturateParams({this.enabled = false});
  DesaturateParams copyWith({bool? enabled}) =>
      DesaturateParams(enabled: enabled ?? this.enabled);
}
