// 📄 lib/widgets/face/face_editor_sheet.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'engine/face_regions_lips_augmentor.dart';
import 'panels/panel_common.dart';
import 'panels/face_panel.dart';

import 'engine/face_regions.dart';
import 'engine/skin_gpu.dart';
import 'engine/shape_gpu.dart';
import 'engine/makeup_gpu.dart';
import 'engine/blemish_gpu.dart';

// ✅ 细实线可视层
import 'overlays/lips_outline_painter.dart';

class FaceEditorSheet extends StatefulWidget {
  const FaceEditorSheet({
    super.key,
    required this.binding, // 与页面共享的唯一数据源（显示用）
    this.initial,
  });

  final ValueNotifier<Uint8List> binding;
  final FaceParams? initial;

  @override
  State<FaceEditorSheet> createState() => _FaceEditorSheetState();
}

class _FaceEditorSheetState extends State<FaceEditorSheet> {
  // —— 基线管理 —— //
  late final Uint8List _originBytes;   // 进入时的原始图（用于“重置”）
  late Uint8List _baselineBytes;       // 参数类效果每次都从它重算
  ui.Image? _decoded;                  // 仅用于尺寸/fit 计算

  Rect _fitRect = Rect.zero;
  Size _previewBox = Size.zero;

  late FaceParams _params;
  FaceTab _currentTab = FaceTab.skin;

  // GPU 引擎
  final _skin = const FaceGpuSkinEngine();
  final _shape = const FaceGpuShapeEngine();
  final _makeup = const FaceGpuMakeupEngine();
  final _blemish = const FaceGpuBlemishEngine();

  // 人脸/皮肤区域
  FaceRegions? _regions;
  bool _regionsReady = false;

  // 节流
  static const int _kMinApplyIntervalMs = 60;
  Timer? _throttleTimer;
  int _lastApplyMs = 0;
  int _applyJob = 0;

  bool _processing = false;

  // 👁️ 唇线可视层开关
  bool _showLipsStroke = true;

  @override
  void initState() {
    super.initState();
    _originBytes = widget.binding.value;
    _baselineBytes = _originBytes;     // 基线=进入时
    _params = widget.initial ?? FaceParams();
    _decodeOnce();
    _detectRegionsFromBytes(_baselineBytes);   // ⭐ 初次检测
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }

  // ---- helpers ----
  Future<ui.Image> _decodeBytes(Uint8List bytes) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) => c.complete(img));
    return c.future;
  }

  Future<void> _decodeOnce() async {
    final img = await _decodeBytes(widget.binding.value);
    if (!mounted) return;
    setState(() => _decoded = img);
  }

  // FaceEditorSheet.dart 中，替换这个方法体
  Future<void> _detectRegionsFromBytes(Uint8List bytes) async {
    setState(() => _regionsReady = false);
    try {
      final det = const FaceRegionsDetector();
      var r = await det.detect(bytes);

      // ⭐ 用 facemesh 增强唇路径（张嘴/露齿稳）
      try {
        await augmentFaceRegionsLips(imageBytes: bytes, faceRegions: r);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _regions = r;
        _regionsReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _regions = null;
        _regionsReady = true;
      });
    }
  }

  // 兼容旧用法
  Future<void> _detectRegions() async {
    await _detectRegionsFromBytes(widget.binding.value);
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

  // —— 参数变更：节流重算（从基线重做）——
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
    final myJob = ++_applyJob;
    setState(() => _processing = true);
    try {
      // ⭐ 参数类效果永远基于 _baselineBytes 重算（避免累加）
      final base = _baselineBytes;

      Uint8List out;
      switch (_currentTab) {
        case FaceTab.skin:
          out = await _skin.process(
            base,
            _params,
            _regions ?? FaceRegions(imageSize: const ui.Size(0, 0), hasFace: false),
          );
          break;
        case FaceTab.shape:
          out = await _shape.process(
            base,
            _params,
            _regions ?? FaceRegions(imageSize: const ui.Size(0, 0), hasFace: false),
          );
          break;
        case FaceTab.makeup:
          out = await _makeup.process(
            base,
            _params,
            _regions ?? FaceRegions(imageSize: const ui.Size(0, 0), hasFace: false),
          );
          break;
      }

      if (!mounted || myJob != _applyJob) return;
      widget.binding.value = out; // 实时显示
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

  // —— 祛痘：落盘并更新基线（不显示任何绘制区域）——
  Future<void> _onTapForBlemish(Offset local) async {
    if (!_params.acneMode) return;
    final imgP = _localToImage(local);
    setState(() => _processing = true);
    try {
      // 祛痘基于当前基线做破坏式修改，并更新基线
      final out = await _blemish.processAt(
        _baselineBytes,
        imgP,
        _params.acneSize,
      );
      if (!mounted) return;
      _baselineBytes = out;        // 更新基线
      widget.binding.value = out;  // 同步显示
      // ⭐ 祛痘改变了嘴部几何吗？一般不会，但稳妥起见：如果当前在上妆，更新一次区域
      if (_currentTab == FaceTab.makeup) {
        // 轻量异步，不加 loading
        unawaited(_detectRegionsFromBytes(_baselineBytes));
      }
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

  // —— Tab 切换（不触发渲染；只更新基线与区域）——
  void _onTabChanged(FaceTab t) {
    _currentTab = t;
    // 进入新 Tab 的 checkpoint：之后的参数改动都基于这个版本重算
    _baselineBytes = widget.binding.value;

    // ⭐ 切到上妆时，用“当前基线图”重新做人脸区域（嘴唇 ring 与最新几何对齐）
    if (t == FaceTab.makeup) {
      unawaited(_detectRegionsFromBytes(_baselineBytes));
    }
    // 轻量提示：只检查，不渲染
    _lightCheck(t);
  }

  void _lightCheck(FaceTab t) {
    if (_regions == null) return;
    final hasFace = _regions!.hasFace == true;
    bool lipsOK = false, eyesOK = false, noseOK = false;
    try {
      final dyn = _regions as dynamic;
      lipsOK = dyn.lipsOuterPath != null || dyn.lipsPath != null || dyn.lipsInnerPath != null
          || dyn.lipsMask != null || dyn.lipMask != null
          || (dyn.segMasks?['lips'] ?? dyn.multiClassMasks?['lips'] ?? dyn.classMasks?['lips']) != null;
      eyesOK = (dyn.leftEyePath != null || dyn.rightEyePath != null ||
          dyn.eyesPath != null || dyn.eyeMask != null);
      noseOK = (dyn.nosePath != null || dyn.noseMask != null);
    } catch (_) {}
    String? warn;
    if (t == FaceTab.skin && !hasFace) warn = '未检测到人脸';
    if (t == FaceTab.makeup && !lipsOK) warn = '未检测到嘴唇';
    if (t == FaceTab.shape && !(eyesOK || noseOK)) warn = '未检测到眼睛/鼻子';
    if (warn != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(warn)));
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
          // 👁️ 唇线可视层开关
          IconButton(
            tooltip: _showLipsStroke ? '隐藏唇线' : '显示唇线',
            onPressed: () => setState(() => _showLipsStroke = !_showLipsStroke),
            icon: Icon(
              _showLipsStroke ? Icons.visibility : Icons.visibility_off,
              color: Colors.white, size: 18,
            ),
          ),
          TextButton(
            onPressed: () {
              // 重置：回到进入时，并刷新基线与区域
              _baselineBytes = _originBytes;
              widget.binding.value = _originBytes;
              setState(() {
                _params = FaceParams();
                _currentTab = FaceTab.skin; // 重置回默认
              });
              _detectRegionsFromBytes(_baselineBytes);
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
              // 仅图片
              Positioned(
                left: 0, right: 0, top: 0, height: previewH,
                child: Center(
                  child: ValueListenableBuilder<Uint8List>(
                    valueListenable: widget.binding,
                    builder: (_, bytes, __) => FittedBox(
                      fit: BoxFit.contain,
                      child: Image.memory(bytes),
                    ),
                  ),
                ),
              ),

              // ✅ 嘴唇细实线可视层（不吃点击）
              Positioned(
                left: 0, right: 0, top: 0, height: previewH,
                child: IgnorePointer(
                  ignoring: true,
                  child: (_showLipsStroke && _regions != null && _decoded != null)
                      ? CustomPaint(
                    size: Size(_previewBox.width, previewH),
                    painter: LipsOutlinePainter(
                      regions: _regions,
                      imageSize: Size(_decoded!.width.toDouble(), _decoded!.height.toDouble()),
                      fitRect: _fitRect,
                      color: const Color(0xFFFFFFFF),
                      strokeScreenPx: 0.5,
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
              ),

              // 祛痘点按
              Positioned(
                left: 0, right: 0, top: 0, height: previewH,
                child: IgnorePointer(
                  ignoring: !_params.acneMode,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _onTapForBlemish(d.localPosition),
                  ),
                ),
              ),

              // 处理遮罩（不吃点击）
              Positioned(
                left: 0, right: 0, top: 0, height: previewH,
                child: IgnorePointer(
                  ignoring: true,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _processing ? 1.0 : 0.0,
                    child: const ColoredBox(
                      color: Color(0x22000000),
                      child: Center(
                        child: SizedBox(
                          width: 28, height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const Positioned(
                left: 0, right: 0, bottom: 0, height: 1,
                child: Divider(height: 1, color: Colors.white10),
              ),

              // 面板
              Positioned(
                left: 0, right: 0, bottom: 0, height: panelH,
                child: FacePanel(
                  params: _params,
                  onChanged: _onParamsChanged,
                  onTabChanged: _onTabChanged, // ⭐ 基线 checkpoint + 上妆重测区域
                  regions: _regions,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
