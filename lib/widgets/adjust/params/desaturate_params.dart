class DesaturateParams {
  final bool enabled; // 勾选=去色
  const DesaturateParams({this.enabled = false});

  DesaturateParams copyWith({bool? enabled})
  => DesaturateParams(enabled: enabled ?? this.enabled);

  bool get isNeutral => !enabled;
}
