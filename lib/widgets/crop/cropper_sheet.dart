// lib/widgets/crop/cropper_sheet.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image/image.dart' as img;

/// ---- isolate 顶层方法（compute 需要） ----
Uint8List _rotateLeftIso(Uint8List s) {
  final im = img.decodeImage(s)!;
  final rot = img.copyRotate(im, angle: -90);
  return Uint8List.fromList(img.encodeJpg(rot, quality: 95));
}

Uint8List _rotateRightIso(Uint8List s) {
  final im = img.decodeImage(s)!;
  final rot = img.copyRotate(im, angle: 90);
  return Uint8List.fromList(img.encodeJpg(rot, quality: 95));
}

Uint8List _flipHIso(Uint8List s) {
  final im = img.decodeImage(s)!;
  final w = im.width, h = im.height;
  final dst = img.Image(
    width: w, height: h,
    format: im.format, numChannels: im.numChannels,
  );
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      dst.setPixel(x, y, im.getPixel(w - 1 - x, y)); // 水平翻转
    }
  }
  return Uint8List.fromList(img.encodeJpg(dst, quality: 95));
}

Uint8List _flipVIso(Uint8List s) {
  final im = img.decodeImage(s)!;
  final w = im.width, h = im.height;
  final dst = img.Image(
    width: w, height: h,
    format: im.format, numChannels: im.numChannels,
  );
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      dst.setPixel(x, y, im.getPixel(x, h - 1 - y)); // 垂直翻转
    }
  }
  return Uint8List.fromList(img.encodeJpg(dst, quality: 95));
}

/// ---- 裁剪弹层 ----
class CropperSheet extends StatefulWidget {
  const CropperSheet({
    super.key,
    required this.image,
    this.initialAspectRatio,
  });

  final Uint8List image;
  /// null=自由；1.0/4/3/3/4/16/9/9/16...
  final double? initialAspectRatio;

  @override
  State<CropperSheet> createState() => _CropperSheetState();
}

class _CropperSheetState extends State<CropperSheet> {
  final _controller = CropController();
  double? _ratio;
  late Uint8List _working;   // 当前用于显示/裁剪的字节
  bool _busy = false;        // 旋转/镜像时遮罩
  bool _cropping = false;    // 防抖

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialAspectRatio;
    _working = widget.image;
  }

  Future<void> _applyBytes(Future<Uint8List> Function(Uint8List) op) async {
    setState(() => _busy = true);
    try {
      final out = await op(_working);
      if (!mounted) return;
      setState(() => _working = out); // 更新图片，Crop 会重建
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('裁剪'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: '左旋转',
            icon: const Icon(Icons.rotate_90_degrees_ccw),
            onPressed: _busy ? null : () => _applyBytes((s) => compute(_rotateLeftIso, s)),
          ),
          IconButton(
            tooltip: '右旋转',
            icon: const Icon(Icons.rotate_90_degrees_cw),
            onPressed: _busy ? null : () => _applyBytes((s) => compute(_rotateRightIso, s)),
          ),
          PopupMenuButton<double?>(
            tooltip: '比例',
            initialValue: _ratio,
            icon: const Icon(Icons.aspect_ratio),
            onSelected: (v) {
              setState(() => _ratio = v);
              _controller.aspectRatio = v; // 运行时改比例
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('自由')),
              PopupMenuItem(value: 1.0, child: Text('1 : 1')),
              PopupMenuItem(value: 4/3, child: Text('4 : 3')),
              PopupMenuItem(value: 3/4, child: Text('3 : 4')),
              PopupMenuItem(value: 16/9, child: Text('16 : 9')),
              PopupMenuItem(value: 9/16, child: Text('9 : 16')),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: '镜像',
            icon: const Icon(Icons.flip),
            onSelected: (key) {
              if (_busy) return;
              if (key == 'h') _applyBytes((s) => compute(_flipHIso, s));
              if (key == 'v') _applyBytes((s) => compute(_flipVIso, s));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'h', child: Text('水平翻转')),
              PopupMenuItem(value: 'v', child: Text('垂直翻转')),
            ],
          ),
          TextButton(
            onPressed: (_busy || _cropping) ? null : () {
              setState(() => _cropping = true);
              _controller.crop();
            },
            child: const Text('完成', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: Crop(
                controller: _controller,
                image: _working,
                baseColor: Colors.black,
                maskColor: Colors.black.withOpacity(0.6),
                aspectRatio: _ratio,
                // 初始区域：留 5% 边距
                initialRectBuilder: InitialRectBuilder.withBuilder((vp, _) {
                  final dx = vp.width * 0.05, dy = vp.height * 0.05;
                  return Rect.fromLTRB(
                    vp.left + dx, vp.top + dy, vp.right - dx, vp.bottom - dy,
                  );
                }),
                cornerDotBuilder: (size, _) => Container(
                  width: size, height: size,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
                // 兼容不同版本的回调类型：有的给 Uint8List，有的给 CropResult
                // v2：裁剪回调
                onCropped: (result) {
                  if (!mounted) return;

                  Uint8List? bytes;

                  // ✅ 绝大多数 v2.x：result 是 CropResult
                  try {
                    final dynamic r = result; // 动态取字段，避免不同版本类名差异
                    // 常见字段名：croppedImage / bytes / image / data
                    bytes = r.croppedImage as Uint8List?;
                    bytes ??= r.bytes as Uint8List?;
                    bytes ??= r.image as Uint8List?;
                    bytes ??= r.data as Uint8List?;
                  } catch (_) {
                    // ignore
                  }

                  // ✅ 兜底：有些旧版直接给 Uint8List
                  if (bytes == null && result is Uint8List) {
                    bytes = result as Uint8List;
                  }

                  if (bytes == null) {
                    setState(() => _cropping = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('裁剪失败：未取到图像数据')),
                    );
                    return;
                  }

                  // 先更新本地预览，下一帧再 pop，避免 Navigator locked
                  setState(() {
                    _cropping = false;
                    _working = bytes!;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) Navigator.of(context).pop(bytes);
                  });
                },
              ),
            ),
          ),
          if (_busy || _cropping)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x88000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
