// lib/pages/camera_page.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _index = 0;

  bool _initializing = true;
  bool _busy = false;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  FlashMode _flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _reinitCurrent();
    }
  }

  Future<void> _boot() async {
    setState(() => _initializing = true);

    // 1) 权限
    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      if (mounted) {
        setState(() => _initializing = false);
      }
      return;
    }

    // 2) 获取相机列表
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _initializing = false);
      return;
    }

    // 优先后置
    final backIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
    );
    _index = backIndex >= 0 ? backIndex : 0;

    // 3) 初始化控制器
    await _initController();

    if (mounted) setState(() => _initializing = false);
  }

  Future<void> _reinitCurrent() async {
    if (_cameras.isEmpty) return;
    await _initController();
    if (mounted) setState(() {});
  }

  Future<void> _initController() async {
    final desc = _cameras[_index];
    final controller = CameraController(
      desc,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();

    _minZoom = await controller.getMinZoomLevel();
    _maxZoom = await controller.getMaxZoomLevel();
    _currentZoom = _currentZoom.clamp(_minZoom, _maxZoom);
    await controller.setZoomLevel(_currentZoom);

    _flash = FlashMode.off;
    await controller.setFlashMode(_flash);

    await _controller?.dispose();
    _controller = controller;
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length <= 1 || _busy) return;
    setState(() => _busy = true);
    _index = (_index + 1) % _cameras.length;
    await _initController();
    setState(() => _busy = false);
  }

  Future<void> _cycleFlash() async {
    if (_controller == null) return;
    final order = <FlashMode>[FlashMode.off, FlashMode.auto, FlashMode.always, FlashMode.torch];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    await _controller!.setFlashMode(next);
    setState(() => _flash = next);
  }

  Future<void> _takePicture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await c.takePicture();
      if (!mounted) return;
      await _showPreviewSheet(file);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPreviewSheet(XFile file) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.file(File(file.path), fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('继续拍'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final ok = await _saveToGallery(file);
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? '已保存到相册' : '保存失败')),
                          );
                        },
                        icon: const Icon(Icons.save_alt),
                        label: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _saveToGallery(XFile xf) async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      await PhotoManager.openSetting();
      return false;
    }
    final bytes = await File(xf.path).readAsBytes();
    final ext = p.extension(xf.path).toLowerCase().replaceFirst('.', '');
    final safeExt = (ext == 'jpeg') ? 'jpg' : (ext.isEmpty ? 'jpg' : ext);
    final name = 'LumenFix_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final asset = await PhotoManager.editor.saveImage(
      bytes,
      filename: name,
      relativePath: 'LumenFix',
    );
    return asset != null;
  }

  // 手势：点按对焦/测光、双指缩放
  Widget _buildGestures(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onScaleStart: (d) => _baseZoom = _currentZoom,
          onScaleUpdate: (d) async {
            final z = (_baseZoom * d.scale).clamp(_minZoom, _maxZoom);
            if (z != _currentZoom) {
              _currentZoom = z;
              await _controller?.setZoomLevel(_currentZoom);
              if (mounted) setState(() {});
            }
          },
          onTapDown: (details) async {
            final c = _controller;
            if (c == null) return;
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final offset = details.localPosition;
            final px = (offset.dx / size.width).clamp(0.0, 1.0);
            final py = (offset.dy / size.height).clamp(0.0, 1.0);
            await c.setFocusPoint(Offset(px, py));
            await c.setExposurePoint(Offset(px, py));
          },
          behavior: HitTestBehavior.opaque,
          child: child,
        );
      },
    );
  }

  IconData _flashIcon(FlashMode m) {
    switch (m) {
      case FlashMode.off: return Icons.flash_off;
      case FlashMode.auto: return Icons.flash_auto;
      case FlashMode.always: return Icons.flash_on;
      case FlashMode.torch: return Icons.highlight; // 常亮
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return Scaffold(
      appBar: AppBar(title: const Text('相机')),
      backgroundColor: Colors.black,
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : (c == null || !c.value.isInitialized)
          ? _NoCamera(onRetry: _boot)
          : Stack(
        alignment: Alignment.center,
        children: [
          // 预览
          Center(
            child: AspectRatio(
              aspectRatio: c.value.previewSize != null
                  ? c.value.previewSize!.width / c.value.previewSize!.height
                  : 3 / 4,
              child: _buildGestures(CameraPreview(c)),
            ),
          ),
          // 顶部控件
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                _RoundIconButton(
                  icon: _flashIcon(_flash),
                  onTap: _cycleFlash,
                ),
                const SizedBox(height: 12),
                _RoundIconButton(
                  icon: Icons.cameraswitch,
                  onTap: _toggleCamera,
                ),
              ],
            ),
          ),
          // 缩放提示
          Positioned(
            bottom: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  '${_currentZoom.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          // 底部快门
          Positioned(
            bottom: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ShutterButton(
                  busy: _busy,
                  onTap: _takePicture,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 74,
        height: 74,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: busy ? Colors.grey.shade400 : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2),
          ),
        ),
      ),
    );
  }
}

class _NoCamera extends StatelessWidget {
  const _NoCamera({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.videocam_off_outlined, size: 56),
        const SizedBox(height: 12),
        const Text('无法访问相机'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('重试')),
      ]),
    );
  }
}
