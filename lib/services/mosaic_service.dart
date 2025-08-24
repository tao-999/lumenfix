// lib/services/mosaic_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/mosaic/mosaic_types.dart';
import '../widgets/mosaic/mosaic_editor_sheet.dart';

class MosaicService {
  static Future<Uint8List?> openEditor(
      BuildContext context,
      Uint8List imageBytes, {
        MosaicBrushType initial = MosaicBrushType.pixel,
      }) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => MosaicEditorSheet(
        image: imageBytes,
        initialBrush: initial,
      ),
    );
  }
}
