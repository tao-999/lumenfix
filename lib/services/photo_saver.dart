// lib/services/photo_saver.dart
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:photo_manager/photo_manager.dart';

class PhotoSaver {
  /// 保存图片字节到系统相册（Android: Pictures/<album> 或 DCIM/<album>；iOS: 相册分组）
  /// 返回 true 表示保存成功
  static Future<bool> saveToAlbum(
      Uint8List bytes, {
        String album = 'LumenFix',
        String? filename,
        bool openSettingWhenDenied = true,
      }) async {
    // 1) 权限
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      if (openSettingWhenDenied) {
        await PhotoManager.openSetting();
      }
      return false;
    }

    // 2) 文件名
    final ext = _detectExt(bytes);
    final name = filename ?? 'LumenFix_${DateTime.now().millisecondsSinceEpoch}.$ext';

    // 3) Android 必须放到允许的主目录：Pictures 或 DCIM
    String rp = album;
    if (Platform.isAndroid) {
      rp = 'Pictures/$album'; // ✅ 首选 Pictures/album
    }

    // 4) 尝试保存；如果 Android 报“Primary directory not allowed”，自动兜底
    try {
      final asset = await PhotoManager.editor.saveImage(
        bytes,
        filename: name,
        relativePath: rp,
      );
      return asset != null;
    } catch (e) {
      if (Platform.isAndroid) {
        // 兜底 1：放到 Pictures 根目录
        try {
          final asset = await PhotoManager.editor.saveImage(
            bytes,
            filename: name,
            relativePath: 'Pictures', // ✅ 系统允许
          );
          if (asset != null) return true;
        } catch (_) {}
        // 兜底 2：放到 DCIM/album
        try {
          final asset = await PhotoManager.editor.saveImage(
            bytes,
            filename: name,
            relativePath: 'DCIM/$album',
          );
          if (asset != null) return true;
        } catch (_) {}
      }
      return false;
    }
  }

  // —— 简易格式嗅探：仅用于命名 —— //
  static String _detectExt(Uint8List d) {
    if (d.length >= 8 &&
        d[0] == 0x89 && d[1] == 0x50 && d[2] == 0x4E && d[3] == 0x47) {
      return 'png';
    }
    if (d.length >= 3 &&
        d[0] == 0xFF && d[1] == 0xD8 && d[2] == 0xFF) {
      return 'jpg';
    }
    if (d.length >= 12 &&
        d[0] == 0x52 && d[1] == 0x49 && d[2] == 0x46 && d[3] == 0x46 &&
        d[8] == 0x57 && d[9] == 0x45 && d[10] == 0x42 && d[11] == 0x50) {
      return 'webp';
    }
    if (d.length >= 12 &&
        d[4] == 0x66 && d[5] == 0x74 && d[6] == 0x79 && d[7] == 0x70) {
      final brand = String.fromCharCodes(d.sublist(8, 12));
      if (brand.startsWith('heic') ||
          brand.startsWith('heix') ||
          brand.startsWith('hevc') ||
          brand.startsWith('heif')) {
        return 'heic';
      }
    }
    return 'jpg';
  }
}
