// lib/pages/beautify_page.dart
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';

import '../../services/gallery_picker.dart';              // 相册选择（WeChat Picker 封装）
import '../../services/photo_saver.dart';                // ✅ 保存到相册（封装）
import '../../services/whiten_service.dart';      // ✅ 智能一键美化（封装）

import '../services/crop_service.dart';
import '../services/mosaic_service.dart';
import '../widgets/beautify/beautify_bottom_bar.dart';   // 纯工具底栏（不含“添加图片”）
import '../widgets/common/empty_pick_image.dart';        // ✅ 空态组件

class BeautifyPage extends StatefulWidget {
  const BeautifyPage({super.key});

  @override
  State<BeautifyPage> createState() => _BeautifyPageState();
}

class _BeautifyPageState extends State<BeautifyPage> {
  Uint8List? _imageBytes;
  BeautifyMenu? _selected;

  /// 选图（相册）—— 走 GalleryPicker 封装
  Future<void> _pickImage() async {
    final bytes = await GalleryPicker.pickOneBytes(context);
    if (!mounted || bytes == null) return;
    setState(() {
      _imageBytes = bytes;
      _selected = null;
    });
  }

  void _notReady() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('先添加一张图片')),
    );
  }

  /// 保存当前图片（走 PhotoSaver 封装）
  Future<void> _saveCurrent() async {
    final bytes = _imageBytes;
    if (bytes == null) return;
    final ok = await PhotoSaver.saveToAlbum(bytes, album: 'LumenFix');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已保存到相册' : '保存失败')),
    );
  }

  /// iOS 14+ 打开系统“编辑允许访问的照片”面板
  Future<void> _editAllowedPhotos() async {
    final ok = await GalleryPicker.presentLimitedEditor();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前系统不支持“编辑允许访问的照片”。')),
      );
    }
  }

  /// 运行智能一键美化
  Future<void> _runSmartEnhance() async {
    if (_imageBytes == null) return _notReady();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 主打美白：strength 0.6~0.8 更自然
      final enhanced = await WhitenService.whiten(
        _imageBytes!,
        strength: 0.4,
        jpegQuality: 95,
      );
      if (!mounted) return;
      setState(() {
        _imageBytes = enhanced;
        _selected = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('一键美化失败：$e')),
      );
    } finally {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageBytes != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('图片美化'),
        actions: [
          IconButton(
            onPressed: hasImage ? _saveCurrent : null,   // ✅ 封装后的保存
            icon: const Icon(Icons.save_alt),
            tooltip: '保存',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => hasImage ? null : _pickImage(),  // 空态点击添加
              child: Container(
                alignment: Alignment.center,
                child: hasImage
                    ? InteractiveViewer(
                  maxScale: 5,
                  minScale: 0.5,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.memory(_imageBytes!),
                  ),
                )
                    : EmptyPickImage(                         // ✅ 复用空态组件
                  onPick: _pickImage,
                  onEditAllowed: Platform.isIOS ? _editAllowedPhotos : null,
                ),
              ),
            ),
          ),
          BeautifyBottomBar(
            enabled: hasImage,
            selected: _selected,
            onSelect: (m) async {
              if (!hasImage) return _notReady();

              if (m == BeautifyMenu.autoEnhance) {
                await _runSmartEnhance();                    // ✅ 智能一键美化
                return;
              }
              if (m == BeautifyMenu.crop) {
                final out = await CropService.openEditor(context, _imageBytes!);
                if (out != null) {
                  setState(() {
                    _imageBytes = out;
                    _selected = null;
                  });
                }
                return;
              }
              if (m == BeautifyMenu.mosaic) {
                final out = await MosaicService.openEditor(context, _imageBytes!);
                if (out != null) {
                  setState(() {
                    _imageBytes = out;
                    _selected = null;
                  });
                }
                return;
              }
              // 其它工具保持原逻辑
              setState(() => _selected = m);
            },
            detail: (hasImage && _selected != null) ? const SizedBox.shrink() : null,
            detailHeight: 140,
          ),
        ],
      ),
    );
  }
}
