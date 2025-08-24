// lib/services/gallery_picker.dart
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart' as wechat;
import 'package:photo_manager/photo_manager.dart';

class GalleryPicker {
  /// 单选：相册（内置相册网格 UI）
  static Future<Uint8List?> pickOneBytes(BuildContext context) async {
    final res = await wechat.AssetPicker.pickAssets(
      context,
      pickerConfig: wechat.AssetPickerConfig(
        maxAssets: 1,
        requestType: wechat.RequestType.image,
        sortPathDelegate: wechat.SortPathDelegate.common,
        textDelegate: const wechat.AssetPickerTextDelegate(), // 固定简中；要繁中换成 TraditionalChineseAssetPickerTextDelegate
      ),
    );
    if (res == null || res.isEmpty) return null;
    final a = res.first;
    return await a.originBytes ??
        await a.thumbnailDataWithSize(const wechat.ThumbnailSize(2048, 2048), quality: 95);
  }

  /// 多选：相册
  static Future<List<Uint8List>> pickMultiBytes(BuildContext context, {int maxAssets = 9}) async {
    final res = await wechat.AssetPicker.pickAssets(
      context,
      pickerConfig: wechat.AssetPickerConfig(
        maxAssets: maxAssets,
        requestType: wechat.RequestType.image,
        sortPathDelegate: wechat.SortPathDelegate.common,
        textDelegate: const wechat.AssetPickerTextDelegate(),
      ),
    );
    if (res == null || res.isEmpty) return <Uint8List>[];
    final out = <Uint8List>[];
    for (final a in res) {
      final b = await a.originBytes ??
          await a.thumbnailDataWithSize(const wechat.ThumbnailSize(2048, 2048), quality: 95);
      if (b != null) out.add(b);
    }
    return out;
  }

  /// iOS 14+：弹出系统“编辑允许访问的照片”面板（Limited Library Picker）
  static Future<bool> presentLimitedEditor() async {
    if (!Platform.isIOS) return false;        // 仅 iOS 有这个系统面板
    try {
      await PhotoManager.presentLimited();    // 调起系统编辑面板
      return true;
    } catch (_) {
      return false;
    }
  }
}
