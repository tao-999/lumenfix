// lib/widgets/filters/engine/engine_landscape.dart
import 'dart:typed_data';
import '../presets.dart';
import 'color_common.dart';

/// 风光专用引擎（此处保持轻量，直接按 spec 应用；复杂逻辑可后续加）
/// 缩略图已降采样，直接在 UI isolate 处理也能保持流畅。
Future<Uint8List> engineLandscape(
    Uint8List base,
    int w,
    int h,
    FilterPreset p,
    ) async {
  return colorApplyThumb(base, w, h, p.toMap());
}
