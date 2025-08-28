// lib/pages/beautify_page.dart
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../services/gallery_picker.dart';
import '../../services/photo_saver.dart';
import '../../services/whiten_service.dart';

import '../services/adjust_service.dart';
import '../services/bokeh_service.dart';
import '../services/crop_service.dart';
import '../services/doodle_service.dart';
import '../services/filter_service.dart';
import '../services/mosaic_service.dart';
import '../services/face_service.dart'; // ✅ 人脸美容 Service
import '../widgets/beautify/beautify_bottom_bar.dart';
import '../widgets/common/empty_pick_image.dart';

class BeautifyPage extends StatefulWidget {
  const BeautifyPage({super.key});

  @override
  State<BeautifyPage> createState() => _BeautifyPageState();
}

class _BeautifyPageState extends State<BeautifyPage> {
  ValueNotifier<Uint8List>? _image; // ⭐ 唯一数据源
  BeautifyMenu? _selected;
  bool _busy = false;

  // ============================== 选图 ==============================
  Future<void> _pickImage() async {
    final bytes = await GalleryPicker.pickOneBytes(context);
    if (!mounted || bytes == null) return;

    setState(() {
      _image = ValueNotifier<Uint8List>(bytes); // 立刻回显
      _selected = null;
    });

    // 下一帧转 WebP（平台线程）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _image == null) return;
      setState(() => _busy = true);
      try {
        final optimized = await _toWebp(_image!.value, quality: 80);
        if (!mounted || _image == null) return;
        _image!.value = optimized; // 不换引用，仍然同一个 notifier
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    });
  }

  void _notReady() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('先添加一张图片')));
  }

  // ============================== 保存 ==============================
  Future<void> _saveCurrent() async {
    final bytes = _image?.value;
    if (bytes == null) return;

    var ok = await PhotoSaver.saveToAlbum(bytes, album: 'LumenFix');

    if (!ok && _isWebp(bytes)) {
      final jpg = await compute(_anyToJpegIsolate, _IsoAnyArg(bytes, 90));
      ok = await PhotoSaver.saveToAlbum(jpg, album: 'LumenFix');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(ok ? '已保存到相册' : '保存失败')));
  }

  Future<void> _editAllowedPhotos() async {
    final ok = await GalleryPicker.presentLimitedEditor();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前系统不支持“编辑允许访问的照片”。')),
      );
    }
  }

  // =========================== 一键美化 ===========================
  Future<void> _runSmartEnhance() async {
    if (_image == null) return _notReady();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final enhanced = await WhitenService.whiten(
        _image!.value,
        strength: 0.4,
        jpegQuality: 95,
      );
      final optimized = await _toWebp(enhanced, quality: 80);
      if (!mounted || _image == null) return;
      _image!.value = optimized;
      setState(() => _selected = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('一键美化失败：$e')));
    } finally {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  // ============================== UI ==============================
  @override
  Widget build(BuildContext context) {
    final hasImage = _image != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('图片美化'),
        actions: [
          IconButton(
            onPressed: hasImage ? _saveCurrent : null,
            icon: const Icon(Icons.save_alt),
            tooltip: '保存',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => hasImage ? null : _pickImage(),
                  child: Container(
                    alignment: Alignment.center,
                    child: hasImage
                        ? ValueListenableBuilder<Uint8List>(
                      valueListenable: _image!,
                      builder: (_, bytes, __) => InteractiveViewer(
                        maxScale: 5,
                        minScale: 0.5,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Image.memory(bytes),
                        ),
                      ),
                    )
                        : EmptyPickImage(
                      onPick: _pickImage,
                      onEditAllowed:
                      Platform.isIOS ? _editAllowedPhotos : null,
                    ),
                  ),
                ),
              ),
              BeautifyBottomBar(
                enabled: hasImage,
                selected: _selected,
                onSelect: (m) async {
                  if (!hasImage) return _notReady();

                  Future<void> _applyAndUniform(Uint8List? out) async {
                    if (out == null) return;
                    setState(() => _busy = true);
                    try {
                      final optimized = await _toWebp(out, quality: 80);
                      if (!mounted || _image == null) return;
                      _image!.value = optimized;
                      setState(() => _selected = null);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  }

                  switch (m) {
                    case BeautifyMenu.autoEnhance:
                      await _runSmartEnhance();
                      return;

                    case BeautifyMenu.filter:
                    // ⭐ Live：页面与弹框共享同一份变量
                      await FilterService.openEditorLive(context, _image!);
                      return;

                    case BeautifyMenu.face:
                    // ✅ 与其它 Live 菜单一致：只调用 Service
                      await FaceService.openEditorLive(context, _image!);
                      return;

                    case BeautifyMenu.crop:
                      await _applyAndUniform(
                        await CropService.openEditor(context, _image!.value),
                      );
                      return;
                    case BeautifyMenu.mosaic:
                      await _applyAndUniform(
                        await MosaicService.openEditor(context, _image!.value),
                      );
                      return;
                    case BeautifyMenu.doodle:
                      await _applyAndUniform(
                        await DoodleService.openEditor(context, _image!.value),
                      );
                      return;
                    case BeautifyMenu.bokeh:
                      await _applyAndUniform(
                        await BokehService.openEditor(context, _image!.value),
                      );
                      return;
                    case BeautifyMenu.adjust:
                      await _applyAndUniform(
                        await AdjustService.openEditor(context, _image!.value),
                      );
                      return;
                    default:
                      setState(() => _selected = m);
                  }
                },
                detail: (hasImage && _selected != null)
                    ? const SizedBox.shrink()
                    : null,
                detailHeight: 140,
              ),
            ],
          ),

          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  // ====================== WebP 统一转码（主 isolate） ======================
  Future<Uint8List> _toWebp(Uint8List input, {int quality = 80}) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        input,
        format: CompressFormat.webp,
        quality: quality,
        keepExif: true,
        autoCorrectionAngle: true,
      );
      if (out.isNotEmpty) return out;
    } catch (_) {}
    return compute(_anyToJpegIsolate, _IsoAnyArg(input, quality));
  }
}

// ======================= 顶层 Isolate 方法（回退用） =======================
class _IsoAnyArg {
  final Uint8List bytes;
  final int quality;
  const _IsoAnyArg(this.bytes, this.quality);
}

Uint8List _anyToJpegIsolate(_IsoAnyArg arg) {
  try {
    final im = img.decodeImage(arg.bytes);
    if (im == null) return arg.bytes;
    img.Image baked;
    try { baked = img.bakeOrientation(im); } catch (_) { baked = im; }
    final out = img.encodeJpg(baked, quality: arg.quality);
    return Uint8List.fromList(out);
  } catch (_) {
    return arg.bytes;
  }
}

bool _isWebp(Uint8List b) {
  if (b.length < 12) return false;
  return b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
      b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50;
}
