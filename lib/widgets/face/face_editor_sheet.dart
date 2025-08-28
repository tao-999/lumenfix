import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'panels/panel_common.dart';
import 'panels/face_panel.dart';

import 'engine/skin_gpu.dart';
import 'engine/shape_gpu.dart';
import 'engine/makeup_gpu.dart';
import 'engine/blemish_gpu.dart';
import 'engine/gpu_utils.dart';
import 'engine/face_regions.dart';

class FaceEditorSheet extends StatefulWidget {
  const FaceEditorSheet({
    super.key,
    required this.binding, // 与页面共享的唯一数据源
    this.initial,
  });

  final ValueNotifier<Uint8List> binding;
  final FaceParams? initial;

  @override
  State<FaceEditorSheet> createState() => _FaceEditorSheetState();
}

class _FaceEditorSheetState extends State<FaceEditorSheet> {
  late final Uint8List _originBytes;
  ui.Image? _decoded;

  Rect _fitRect = Rect.zero;
  Size _previewBox = Size.zero;

  late FaceParams _params;
  FaceTab _currentTab = FaceTab.skin;

  // 引擎
  final _skin = const FaceGpuSkinEngine();
  final _shape = const FaceGpuShapeEngine();
  final _makeup = const FaceGpuMakeupEngine();
  final _blemish = const FaceGpuBlemishEngine();
  final _detector = const FaceRegionsDetector();

  // 人脸区域缓存
  FaceRegions? _regions;
  bool _detecting = false;

  // 子面板提供的覆盖层（虚线等）；更新统一延后到帧末
  Widget? _overlay;
  void _scheduleOverlay(Widget? w) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _overlay = w);
    });
  }

  // 节流
  static const int _kMinApplyIntervalMs = 60;
  Timer? _throttleTimer;
  int _lastApplyMs = 0;
  int _applyJob = 0;

  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _originBytes = widget.binding.value;
    _params = widget.initial ?? FaceParams();
    _decodeOnce();
    _ensureRegions();
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }

  Future<void> _decodeOnce() async {
    final img = await decodeImageCompat(widget.binding.value);
    if (!mounted) return;
    setState(() => _decoded = img);
  }

  Future<void> _ensureRegions() async {
    if (_detecting) return;
    setState(() => _detecting = true);
    try {
      _regions = await _detector.detect(widget.binding.value);
      if (!mounted) return;
      if (!(_regions?.hasFace ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未检测到人脸，部分功能不可用')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('人脸识别失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Rect _containRect(Size content, Size box) {
    if (content.width <= 0 || content.height <= 0 || box.isEmpty) return Rect.zero;
    final sx = box.width / content.width;
    final sy = box.height / content.height;
    final s = sx < sy ? sx : sy;
    final w = content.width * s;
    final h = content.height * s;
    final dx = (box.width - w) / 2;
    final dy = (box.height - h) / 2;
    return Rect.fromLTWH(dx, dy, w, h);
  }

  Offset _localToImage(Offset local) {
    final w = _decoded?.width ?? 0;
    final h = _decoded?.height ?? 0;
    if (w == 0 || h == 0 || _fitRect.isEmpty) return Offset.zero;
    final x = ((local.dx - _fitRect.left) / _fitRect.width) * w;
    final y = ((local.dy - _fitRect.top) / _fitRect.height) * h;
    return Offset(x.clamp(0, w.toDouble()), y.clamp(0, h.toDouble()));
  }

  void _onParamsChanged(FaceParams p) {
    setState(() => _params = p);
    _applyThrottled();
  }

  void _applyThrottled() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final gap = now - _lastApplyMs;
    if (gap >= _kMinApplyIntervalMs && _throttleTimer == null) {
      _lastApplyMs = now;
      _applyOnce();
    } else {
      _throttleTimer ??= Timer(
        const Duration(milliseconds: _kMinApplyIntervalMs),
            () {
          _throttleTimer = null;
          _lastApplyMs = DateTime.now().millisecondsSinceEpoch;
          _applyOnce();
        },
      );
    }
  }

  Future<void> _applyOnce() async {
    if (_regions == null) {
      await _ensureRegions();
      if (_regions == null) return;
    }
    final myJob = ++_applyJob;
    setState(() => _processing = true);
    try {
      final inBytes = widget.binding.value;
      final r = _regions!;

      Uint8List out;
      switch (_currentTab) {
        case FaceTab.skin:
          out = await _skin.process(inBytes, _params, r);
          break;
        case FaceTab.shape:
          out = await _shape.process(inBytes, _params, r);
          break;
        case FaceTab.makeup:
          out = await _makeup.process(inBytes, _params, r);
          break;
      }

      if (!mounted || myJob != _applyJob) return;
      widget.binding.value = out; // 实时回写到页面
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _onTapForBlemish(Offset local) async {
    if (!_params.acneMode) return;
    final imgP = _localToImage(local);
    setState(() => _processing = true);
    try {
      final out = await _blemish.processAt(
        widget.binding.value,
        imgP,
        _params.acneSize,
      );
      if (!mounted) return;
      widget.binding.value = out;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('祛痘失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _decoded;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('人脸美容'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              widget.binding.value = _originBytes;
              setState(() => _params = FaceParams());
              _ensureRegions();
              _scheduleOverlay(null);
            },
            child: const Text('重置', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: (img == null)
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (_, cons) {
          final panelH = (cons.maxHeight / 3).floorToDouble();
          final previewH = cons.maxHeight - panelH;
          _previewBox = Size(cons.maxWidth, previewH);
          _fitRect = _containRect(
            Size(img.width.toDouble(), img.height.toDouble()),
            _previewBox,
          );

          return Stack(
            children: [
              // 预览（页面同源）
              Positioned(
                left: 0, right: 0, top: 0, height: previewH,
                child: Center(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ValueListenableBuilder<Uint8List>(
                          valueListenable: widget.binding,
                          builder: (_, bytes, __) => FittedBox(
                            fit: BoxFit.contain,
                            child: Image.memory(bytes),
                          ),
                        ),
                      ),

                      // 子面板 overlay（虚线等）
                      if (_overlay != null)
                        Positioned.fill(
                          child: IgnorePointer(child: _overlay!),
                        ),

                      // 点祛痘
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !_params.acneMode,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (d) => _onTapForBlemish(d.localPosition),
                          ),
                        ),
                      ),

                      if (_processing || _detecting)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x22000000),
                            child: Center(
                              child: SizedBox(
                                width: 28, height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2.6),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const Positioned(
                left: 0, right: 0, bottom: 0, height: 1,
                child: Divider(height: 1, color: Colors.white10),
              ),

              // 面板（透传上下文，接收 overlay）
              Positioned(
                left: 0, right: 0, bottom: 0, height: panelH,
                child: FacePanel(
                  params: _params,
                  onChanged: _onParamsChanged,
                  onTabChanged: (t) {
                    _currentTab = t;
                    _applyThrottled();
                    _scheduleOverlay(null); // 切页清 overlay
                  },
                  onOverlayChanged: _scheduleOverlay,
                  regions: _regions,
                  fitRect: _fitRect,
                  imageWidth: img.width,
                  imageHeight: img.height,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
