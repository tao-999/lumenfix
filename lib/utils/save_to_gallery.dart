import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';

class GallerySaverLite {
  static Future<void> savePngBytes(Uint8List pngBytes, {String album = 'LumenFix'}) async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      await PhotoManager.openSetting();
      throw Exception('未授权访问相册');
    }

    final fileName = 'LumenFix_${DateTime.now().millisecondsSinceEpoch}.png';

    final asset = await PhotoManager.editor.saveImage(
      pngBytes,
      filename: fileName,       // ✅ 必填：文件名要带扩展名
      relativePath: album,      // ✅ 建议：指定相册/目录（Android: Pictures/album；iOS: 自动建相册）
    );

    if (asset == null) {
      throw Exception('保存失败');
    }
  }
}
