// lib/pages/beautify_page.dart
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute; // 💡 后台 Isolate
import 'package:image/image.dart' as img;

import '../../services/gallery_picker.dart';
import '../../services/photo_saver.dart';
import '../../services/whiten_service.dart';

import '../services/adjust_service.dart';
import '../services/bokeh_service.dart';
import '../services/crop_service.dart';
import '../services/doodle_service.dart';
import '../services/mosaic_service.dart';
import '../widgets/beautify/beautify_bottom_bar.dart';
import '../widgets/common/empty_pick_image.dart';

class BeautifyPage extends StatefulWidget {
  const BeautifyPage({super.key});

  @override
  State<BeautifyPage> createState() => _BeautifyPageState();
}

class _BeautifyPageState extends State<BeautifyPage> {
  Uint8List? _imageBytes;
  BeautifyMenu? _selected;

  bool _busy = false; // 转码中遮罩

  /// 选图（相册）
  Future<void> _pickImage() async {
    final bytes = await GalleryPicker.pickOneBytes(context);
    if (!mounted || bytes == null) return;

    // 1) 先即时回显，保证相册路由动画丝滑退场
    setState(() {
      _imageBytes = bytes;
      _selected = null;
    });

    // 2) 待本帧提交后，把重活丢后台 Isolate
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _busy = true);
      try {
        final optimized = await _optimizeInBackground(bytes, quality: 80);
        if (!mounted) return;
        setState(() => _imageBytes = optimized);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    });
  }

  void _notReady() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('先添加一张图片')),
    );
  }

  /// 保存当前图片
  Future<void> _saveCurrent() async {
    final bytes = _imageBytes;
    if (bytes == null) return;
    final ok = await PhotoSaver.saveToAlbum(bytes, album: 'LumenFix');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已保存到相册' : '保存失败')),
    );
  }

  /// iOS 14+ 打开系统“编辑允许访问的照片”
  Future<void> _editAllowedPhotos() async {
    final ok = await GalleryPicker.presentLimitedEditor();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前系统不支持“编辑允许访问的照片”。')),
      );
    }
  }

  /// 智能一键美化
  Future<void> _runSmartEnhance() async {
    if (_imageBytes == null) return _notReady();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
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
                        ? InteractiveViewer(
                      maxScale: 5,
                      minScale: 0.5,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Image.memory(_imageBytes!),
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

                  if (m == BeautifyMenu.autoEnhance) {
                    await _runSmartEnhance();
                    return;
                  }
                  if (m == BeautifyMenu.crop) {
                    final out =
                    await CropService.openEditor(context, _imageBytes!);
                    if (out != null) {
                      setState(() {
                        _imageBytes = out;
                        _selected = null;
                      });
                    }
                    return;
                  }
                  if (m == BeautifyMenu.mosaic) {
                    final out =
                    await MosaicService.openEditor(context, _imageBytes!);
                    if (out != null) {
                      setState(() {
                        _imageBytes = out;
                        _selected = null;
                      });
                    }
                    return;
                  }
                  if (m == BeautifyMenu.doodle) {
                    final out =
                    await DoodleService.openEditor(context, _imageBytes!);
                    if (out != null) {
                      setState(() {
                        _imageBytes = out;
                        _selected = null;
                      });
                    }
                    return;
                  }
                  if (m == BeautifyMenu.bokeh) {
                    final out =
                    await BokehService.openEditor(context, _imageBytes!);
                    if (out != null) {
                      setState(() {
                        _imageBytes = out;
                        _selected = null;
                      });
                    }
                    return;
                  }
                  if (m == BeautifyMenu.adjust) {
                    final out =
                    await AdjustService.openEditor(context, _imageBytes!);
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
                detail: (hasImage && _selected != null)
                    ? const SizedBox.shrink()
                    : null,
                detailHeight: 140,
              ),
            ],
          ),

          // 轻量遮罩（后台转码中）
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

  // =========================================================
  // 后台优化：所有格式统一转 JPEG(quality)，避免阻塞 UI
  // =========================================================
  Future<Uint8List> _optimizeInBackground(
      Uint8List input, {
        int quality = 80,
      }) async {
    // JPG：最稳的路径，纯 CPU，放后台 Isolate
    if (_isJpeg(input)) {
      return compute(_jpeg80Isolate, _IsoJpegArg(input, quality));
    }

    // 其它常见格式：尝试 image 包（PNG/WebP/GIF 首帧...）
    final any = await compute(_anyToJpeg80Isolate, _IsoAnyArg(input, quality));
    if (any.isNotEmpty) return any;

    // HEIC/极少数：走 UI 解码兜底（此时相册路由已退场，不会卡）
    return _transcodeWithUi(input, quality: quality);
  }

  // UI 兜底（HEIC 等）：白底合成 → RGBA → image.encodeJpg
  Future<Uint8List> _transcodeWithUi(
      Uint8List inputBytes, {
        int quality = 80,
      }) async {
    try {
      final codec = await ui.instantiateImageCodec(inputBytes);
      final frame = await codec.getNextFrame();
      final src = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final rect =
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble());
      canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFFFF)); // 白底
      canvas.drawImageRect(src, rect, rect, Paint()); // SrcOver
      final flattened =
      await recorder.endRecording().toImage(src.width, src.height);

      ByteData? bd =
      await flattened.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      bd ??= await flattened.toByteData(format: ui.ImageByteFormat.rawRgba);

      final im4 = img.Image.fromBytes(
        width: flattened.width,
        height: flattened.height,
        bytes: bd!.buffer, // ByteBuffer
        rowStride: flattened.width * 4,
        order: img.ChannelOrder.rgba,
      );
      final out = img.encodeJpg(im4, quality: quality);
      return Uint8List.fromList(out);
    } catch (_) {
      // 真不行就原样返回，宁可不转码也别卡/白片
      return inputBytes;
    }
  }
}

// ======================= 顶层 Isolate 方法 =======================
// —— 注意：必须是顶层或静态，compute 才能调用 —— //

class _IsoJpegArg {
  final Uint8List bytes;
  final int quality;
  const _IsoJpegArg(this.bytes, this.quality);
}

Uint8List _jpeg80Isolate(_IsoJpegArg arg) {
  try {
    final im = img.decodeJpg(arg.bytes);
    if (im == null) return arg.bytes;
    img.Image baked;
    try {
      baked = img.bakeOrientation(im); // 有些版本可能没有，catch 即可
    } catch (_) {
      baked = im;
    }
    final out = img.encodeJpg(baked, quality: arg.quality);
    return Uint8List.fromList(out);
  } catch (_) {
    return arg.bytes;
  }
}

class _IsoAnyArg {
  final Uint8List bytes;
  final int quality;
  const _IsoAnyArg(this.bytes, this.quality);
}

Uint8List _anyToJpeg80Isolate(_IsoAnyArg arg) {
  try {
    final im = img.decodeImage(arg.bytes); // 尽量吃 PNG/WebP/GIF…
    if (im == null) return Uint8List(0);   // 返回空，让主流程走 UI 兜底
    img.Image baked;
    try {
      baked = img.bakeOrientation(im);
    } catch (_) {
      baked = im;
    }
    final out = img.encodeJpg(baked, quality: arg.quality);
    return Uint8List.fromList(out);
  } catch (_) {
    return Uint8List(0);
  }
}

bool _isJpeg(Uint8List b) =>
    b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;
