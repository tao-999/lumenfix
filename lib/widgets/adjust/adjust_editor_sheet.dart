// lib/widgets/adjust/adjust_editor_sheet.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'adjust_params.dart';
import 'adjust_panel.dart';
import 'engine/adjust_engine.dart';

class AdjustEditorSheet extends StatefulWidget {
  const AdjustEditorSheet({super.key, required this.imageBytes});
  final Uint8List imageBytes;

  @override
  State<AdjustEditorSheet> createState() => _AdjustEditorSheetState();
}

class _AdjustEditorSheetState extends State<AdjustEditorSheet> {
  late AdjustParams _params;

  Uint8List? _previewBytes;
  bool _showOriginal = false;
  bool _exporting = false;
  AdjustGroup _group = AdjustGroup.tone;

  Timer? _debounce;
  int _previewSeq = 0;

  // 几何拖动时的 GPU 预览（保持到新预览烘焙完成为止，避免“松手跳一下”）
  Geometry? _liveGeo;

  @override
  void initState() {
    super.initState();
    _params = AdjustParams.neutral();
    _schedulePreview(immediate: true);
  }

  void _schedulePreview({bool immediate = false, bool clearGeoOnReady = false}) {
    _debounce?.cancel();

    void startTask() async {
      final int seq = ++_previewSeq;
      final out = await AdjustEngine.buildPreview(widget.imageBytes, _params, maxSide: 1080);
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _previewBytes = out;
        if (clearGeoOnReady) _liveGeo = null; // 只有当新图准备好了才移除 GPU 旋转
      });
    }

    if (immediate) {
      startTask();
    } else {
      _debounce = Timer(const Duration(milliseconds: 80), startTask);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final out = await AdjustEngine.exportFull(widget.imageBytes, _params);
    if (!mounted) return;
    setState(() => _exporting = false);
    Navigator.pop(context, out);
  }

  void _reset() {
    setState(() {
      _params = AdjustParams.neutral();
      _liveGeo = null;
    });
    _schedulePreview(immediate: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPreview = _previewBytes != null;
    final oneThird = MediaQuery.of(context).size.height / 3.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text('调整'),
            const SizedBox(width: 8),
            if (_exporting)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(onPressed: _exporting ? null : _reset, child: const Text('重置', style: TextStyle(color: Colors.white))),
          TextButton(onPressed: _exporting ? null : _export, child: const Text('完成', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onLongPressStart: (_) => setState(() => _showOriginal = true),
              onLongPressEnd: (_)   => setState(() => _showOriginal = false),
              child: Container(
                alignment: Alignment.center,
                color: Colors.black,
                child: hasPreview
                    ? Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_showOriginal) Image.memory(widget.imageBytes, fit: BoxFit.contain),
                    if (!_showOriginal) _buildPreviewImage(_previewBytes!),
                  ],
                )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: oneThird),
            child: AdjustPanel(
              params: _params,
              onChanged: _onPanelChanged,
              onChangeEnd: _onPanelChangeEnd,
              group: _group,
              onGroupChange: (g) => setState(() => _group = g),
              onReset: _reset,
              rebuilding: _exporting,
            ),
          ),
        ],
      ),
    );
  }

  // —— GPU 预览：旋转/缩放/轻量透视（仅视觉，不改像素）——
  Widget _buildPreviewImage(Uint8List bytes) {
    final base = Image.memory(bytes, fit: BoxFit.contain);
    final g = _liveGeo;
    if (g == null) return base;

    double clampPersp(double v) => v.clamp(-0.35, 0.35);

    final m = vm.Matrix4.identity()
    // 先写透视项：w = 1 + px*x + py*y（与 CPU 完全同构）
      ..setEntry(3, 0, clampPersp(g.perspX))
      ..setEntry(3, 1, clampPersp(g.perspY))
    // 再缩放、再绕 Z 纯旋转（不混其它轴）
      ..scale(g.scale)
      ..rotateZ(g.rotate * math.pi / 180.0);

    return Transform(
      alignment: Alignment.center,
      transform: m,
      child: RepaintBoundary(child: base), // 直接包一层，不用 extension
    );

  }

  void _onPanelChanged(AdjustParams p) {
    final isGeo = _group == AdjustGroup.geometry;
    setState(() {
      _params = p;
      _liveGeo = isGeo ? p.geo : null; // 几何：拖动时只更新 GPU 变换
    });
    if (!isGeo) _schedulePreview();    // 其他组：静默重建低清预览
  }

  void _onPanelChangeEnd(AdjustParams p) {
    setState(() => _params = p);
    if (_group == AdjustGroup.geometry) {
      // 保持当前 GPU 旋转不变，直到新预览烘焙完成（避免“松手跳一下”）
      _liveGeo = p.geo;
      _schedulePreview(immediate: true, clearGeoOnReady: true);
    }
  }
}
