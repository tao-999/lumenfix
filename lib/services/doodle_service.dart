// lib/services/doodle_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/doodle/doodle_editor_sheet.dart';

enum DoodleBrushType { pen, marker, highlighter, neon, eraser }

class DoodleService {
  static Future<Uint8List?> openEditor(
      BuildContext context,
      Uint8List imageBytes, {
        DoodleBrushType initial = DoodleBrushType.pen,
      }) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => DoodleEditorSheet(
        imageBytes: imageBytes,
        initialBrush: initial,
      ),
    );
  }
}
