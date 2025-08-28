// lib/pages/services/filter_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/filters/filter_editor_sheet.dart';

class FilterService {
  /// 旧版：弹框里点“完成”后，返回一份新字节（会产生第二份变量）
  static Future<Uint8List?> openEditor(
      BuildContext context,
      Uint8List imageBytes,
      ) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => FilterEditorSheet.bytes(imageBytes: imageBytes),
    );
  }

  /// 新版 Live：弹框与页面共享同一个 ValueNotifier<Uint8List>（只有一份变量）
  static Future<void> openEditorLive(
      BuildContext context,
      ValueNotifier<Uint8List> imageBinding,
      ) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => FilterEditorSheet.live(binding: imageBinding),
    );
  }
}
