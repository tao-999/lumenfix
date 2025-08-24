// lib/services/crop_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/crop/cropper_sheet.dart';

class CropService {
  /// 打开裁剪器并返回裁剪后的字节；null 表示取消
  static Future<Uint8List?> openEditor(
      BuildContext context,
      Uint8List imageBytes, {
        double? aspectRatio, // null=自由
      }) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => CropperSheet(
        image: imageBytes,
        initialAspectRatio: aspectRatio,
      ),
    );
  }
}
