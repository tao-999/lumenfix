// lib/widgets/filters/filter_editor_sheet.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../services/filter_material_cache.dart';
import '../../services/lut_apply.dart';

import 'filter_panel.dart';
import 'presets.dart';
import 'engine/color_common.dart' as cc;        // 兜底/其它引擎
import 'panels/panel_common.dart';              // EffectHandle

class FilterEditorSheet extends StatefulWidget {
  /// 旧：传入单次字节，内部维护一份拷贝（不共享）
  const FilterEditorSheet.bytes({
    super.key,
    required this.imageBytes,
    this.onLiveUpdate,
  }) : binding = null;

  /// 新：Live 模式，传入唯一的 ValueNotifier，共享同一份图片字节
  const FilterEditorSheet.live({
    super.key,
    required this.binding,
  })  : imageBytes = null,
        onLiveUpdate = null;

  // ---- 二选一 ----
  final Uint8List? imageBytes;                    // bytes 模式
  final ValueNotifier<Uint8List>? binding;        // live 模式

  /// bytes 模式下的可选实时回调（兼容旧写法）
  final ValueChanged<Uint8List>? onLiveUpdate;

  bool get isLive => binding != null;

  @override
  State<FilterEditorSheet> createState() => _FilterEditorSheetState();
}

class _FilterEditorSheetState extends State<FilterEditorSheet> {
  ui.Image? _orig;             // 打开时的“原始大图”
  Uint8List? _origBytes;       // 原始字节（用于重置）
  ui.Image? _preview;          // bytes 模式内部使用；live 模式不用它

  FilterPreset? _picked;       // 调色预设（→ LUT）
  EffectHandle? _pickedFx;     // 几何/像素类效果

  // 判重
  Object? _lastApplied;
  String? _lastAppliedKey;
  Size? _lastOutSize;

  bool _previewBusy = false;
  int _previewJob = 0;
  int _previewJobRunning = 0;
  Size? _lastReqSize;
  Object? _lastReqEffect;
  String? _lastReqKey;

  Size? _lastLayoutPreviewSize;
  Key _panelKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _decodeInitial();
  }

  @override
  void dispose() {
    _clearPreview();
    try { _orig?.dispose(); } catch (_){}
    _orig = null;
    super.dispose();
  }

  Future<void> _decodeInitial() async {
    final bytes = widget.isLive ? widget.binding!.value : widget.imageBytes!;
    _origBytes = bytes;
    final img0 = await decodeImageFromList(bytes);
    if (!mounted) return;
    setState(() => _orig = img0);
  }

  void _setPreview(ui.Image? img) {
    final old = _preview;
    setState(() => _preview = img);
    if (old != null && old != img) {
      WidgetsBinding.instance.addPostFrameCallback((_) { try { old.dispose(); } catch(_){}} );
    }
  }

  void _clearPreview() {
    final old = _preview; _preview = null;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { try { old.dispose(); } catch(_){}} );
    }
  }

  // 预览就是大图：直接用原尺寸
  Size _pickContainSizePx(Size _, double __, ui.Image src)
  => Size(src.width.toDouble(), src.height.toDouble());

  Future<void> _rebuildPreview(Size fitDp) async {
    final src = _orig; if (src == null) return;

    final outSizePx = _pickContainSizePx(fitDp, 1.0, src);
    final Object? current = _pickedFx ?? _picked;
    final String? currentKey = current == null
        ? null
        : (current is EffectHandle ? current.id : (current as FilterPreset).id);

    // 已有相同结果
    if (!_previewBusy &&
        _lastOutSize == outSizePx &&
        _lastAppliedKey == currentKey) {
      return;
    }

    // 相同请求已在跑
    if (_previewBusy &&
        _lastReqSize == outSizePx &&
        _lastReqKey == currentKey) {
      return;
    }
    _lastReqSize = outSizePx;
    _lastReqEffect = current;
    _lastReqKey = currentKey;

    final int myJob = ++_previewJob;
    setState(() => _previewBusy = true);

    // 读原图 RGBA
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    final baseRgba = Uint8List.fromList(bd!.buffer.asUint8List());

    // 无效果：恢复原图
    if (current == null) {
      if (!mounted || myJob != _previewJob) { return; }
      _lastApplied = null;
      _lastAppliedKey = null;
      _lastOutSize = outSizePx;
      _previewJobRunning = myJob;
      setState(() => _previewBusy = false);

      if (widget.isLive) {
        widget.binding!.value = _origBytes!;
      } else {
        _setPreview(null); // bytes 模式：RawImage 会显示 _orig
        if (widget.onLiveUpdate != null) {
          final jpg = await compute<_EncodeArgs, Uint8List>(
            _encodeJpegIsolate, _EncodeArgs(baseRgba, src.width, src.height, 90),
          );
          if (mounted && myJob == _previewJob) widget.onLiveUpdate!(jpg);
        }
      }
      return;
    }

    // 带效果：全尺寸处理
    Uint8List cookedRgba;
    if (current is EffectHandle) {
      cookedRgba = await current.render(baseRgba, src.width, src.height);
    } else {
      cookedRgba = await _applyPresetViaLut(
        baseRgba, src.width, src.height, _picked!, lutSize: 128,
      );
    }

    if (!mounted || myJob != _previewJob) { return; }

    _lastApplied = current;
    _lastAppliedKey = currentKey;
    _lastOutSize = outSizePx;
    _previewJobRunning = myJob;
    setState(() => _previewBusy = false);

    if (widget.isLive) {
      final jpg = await compute<_EncodeArgs, Uint8List>(
        _encodeJpegIsolate, _EncodeArgs(cookedRgba, src.width, src.height, 90),
      );
      if (!mounted || myJob != _previewJob) return;
      widget.binding!.value = jpg;
    } else {
      final cooked = await _decodeRgbaToImage(cookedRgba, src.width, src.height);
      if (!mounted || myJob != _previewJob) { try { cooked.dispose(); } catch (_) {} return; }
      _setPreview(cooked);
      if (widget.onLiveUpdate != null) {
        final jpg = await compute<_EncodeArgs, Uint8List>(
          _encodeJpegIsolate, _EncodeArgs(cookedRgba, src.width, src.height, 90),
        );
        if (mounted && myJob == _previewJob) widget.onLiveUpdate!(jpg);
      }
    }
  }

  Future<ui.Image> _decodeRgbaToImage(Uint8List rgba, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  @override
  Widget build(BuildContext context) {
    final img0 = _orig;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        // ==== 关键改动：不再自动插入返回按钮，也不再显示左上角 X ====
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('滤镜'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() { _picked = null; _pickedFx = null; });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _lastLayoutPreviewSize != null) {
                  _rebuildPreview(_lastLayoutPreviewSize!);
                }
              });
            },
            child: const Text('重置', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: (img0 == null)
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (_, cons) {
          final panelH = (cons.maxHeight / 3).floorToDouble();
          final previewH = cons.maxHeight - panelH;
          final previewSize = Size(cons.maxWidth, previewH);

          if (_lastLayoutPreviewSize != previewSize) {
            _lastLayoutPreviewSize = previewSize;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _rebuildPreview(previewSize);
            });
          }

          Widget previewStack;

          if (widget.isLive) {
            previewStack = ValueListenableBuilder<Uint8List>(
              valueListenable: widget.binding!,
              builder: (_, bytes, __) {
                return FittedBox(
                  fit: BoxFit.contain,
                  child: Image.memory(bytes, filterQuality: FilterQuality.high),
                );
              },
            );
          } else {
            previewStack = FittedBox(
              fit: BoxFit.contain,
              child: RawImage(
                image: _preview ?? img0,
                filterQuality: FilterQuality.high,
              ),
            );
          }

          return Stack(
            children: [
              Positioned(
                left: 0, right: 0, top: 0, height: previewH,
                child: Center(
                  child: Stack(
                    children: [
                      previewStack,
                      if (_previewBusy)
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
              const Positioned(left: 0, right: 0, bottom: 0, height: 1, child: Divider(height: 1, color: Colors.white10)),
              Positioned(
                left: 0, right: 0, bottom: 0, height: panelH,
                child: FilterPanel(
                  key: _panelKey,
                  origImage: img0,
                  selectedPresetId: _pickedFx?.id ?? _picked?.id,
                  onPick: (preset) {
                    setState(() { _picked = preset; _pickedFx = null; });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _rebuildPreview(previewSize);
                    });
                  },
                  onPickEffect: (h) {
                    setState(() { _pickedFx = h; _picked = null; });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _rebuildPreview(previewSize);
                    });
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ========= LUT 渲染助手（预览/导出共用） =========
Future<Uint8List> _applyPresetViaLut(
    Uint8List rgba, int w, int h, FilterPreset p, {
      int lutSize = 64, double intensity = 1.0,
    }) async {
  final lutBytes = await FilterMaterialCache.I.getOrBakeLutPng(
    preset: p,
    size: lutSize,
  );
  return compute<_IsoApplyArgs, Uint8List>(
    _applyLutIso,
    _IsoApplyArgs(Uint8List.fromList(rgba), w, h, lutBytes, lutSize, intensity),
  );
}

class _IsoApplyArgs {
  final Uint8List rgba, lutPng;
  final int w, h, lutSize;
  final double intensity;
  const _IsoApplyArgs(this.rgba, this.w, this.h, this.lutPng, this.lutSize, this.intensity);
}

Future<Uint8List> _applyLutIso(_IsoApplyArgs a) => applyLutToRgba(
  rgba: a.rgba, w: a.w, h: a.h, lutPng: a.lutPng, lutSize: a.lutSize, intensity: a.intensity,
);

Uint8List _applyPresetRgbaIsolate(Map<String, dynamic> a) {
  final Uint8List rgba = a['rgba'] as Uint8List;
  final int w = a['w'] as int, h = a['h'] as int;
  final Map<String, dynamic> spec = a['spec'] as Map<String, dynamic>;
  final out = Uint8List.fromList(rgba);
  cc.colorApplySpecInPlace(out, w, h, spec);
  return out;
}

class _EncodeArgs {
  final Uint8List rgba;
  final int w, h, quality;
  const _EncodeArgs(this.rgba, this.w, this.h, this.quality);
}
Uint8List _encodeJpegIsolate(_EncodeArgs a) {
  img.Image _fromBytesCompat(Uint8List bytes) {
    try {
      return img.Image.fromBytes(
        width: a.w, height: a.h,
        bytes: bytes.buffer, rowStride: a.w * 4, order: img.ChannelOrder.rgba,
      );
    } catch (_) {
      return img.Image.fromBytes(
        width: a.w, height: a.h,
        bytes: bytes.buffer, numChannels: 4, order: img.ChannelOrder.rgba,
      );
    }
  }
  try {
    final im = _fromBytesCompat(a.rgba);
    final jpg = img.encodeJpg(im, quality: a.quality);
    return Uint8List.fromList(jpg);
  } catch (_) {
    try {
      final im2 = _fromBytesCompat(a.rgba);
      final png = img.encodePng(im2);
      return Uint8List.fromList(png);
    } catch (_) {
      return a.rgba;
    }
  }
}
