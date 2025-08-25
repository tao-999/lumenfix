import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/adjust/adjust_editor_sheet.dart';

class AdjustService {
  static Future<Uint8List?> openEditor(
      BuildContext context,
      Uint8List imageBytes,
      ) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => AdjustEditorSheet(imageBytes: imageBytes),
    );
  }
}
