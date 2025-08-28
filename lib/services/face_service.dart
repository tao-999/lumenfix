// lib/pages/services/face_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../widgets/face/face_editor_sheet.dart';

/// 人脸美容 Service（Sheet 入口，Live 同源）
/// 页面不写逻辑，保持与 FilterService.openEditorLive 一致的调用方式。
class FaceService {
  /// 打开人脸美容编辑器（与页面共享同一张图）
  static Future<void> openEditorLive(
      BuildContext context,
      ValueNotifier<Uint8List> binding,
      ) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,        // ✅ 顶部安全区域，防刘海
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => FaceEditorSheet(
        binding: binding,       // 只传同源 binding，其他不掺和
      ),
    );
  }
}
