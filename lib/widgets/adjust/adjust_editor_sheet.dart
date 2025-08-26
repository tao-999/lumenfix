// lib/widgets/adjust/adjust_editor_sheet.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lumenfix/widgets/adjust/panel/blackwhite_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/channel_mixer_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/color_balance_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/invert_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/photo_filter_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/selective_color_panel.dart';

// 面板
import 'package:lumenfix/widgets/adjust/panel/vibrance_panel.dart';
import 'panel/brightness_contrast_panel.dart';
import 'panel/exposure_panel.dart';
import 'panel/levels_panel.dart';
import 'panel/curves_panel.dart';
import 'panel/shadows_highlights_panel.dart';
import 'panel/hsl_panel.dart'; // ✅ HSL 面板

// 参数/菜单 & 预览
import 'adjust_params.dart';
import 'params/params.dart';
import 'adjust_menu.dart';
import 'adjust_preview.dart';

class AdjustEditorSheet extends StatefulWidget {
  const AdjustEditorSheet({super.key, required this.imageBytes});
  final Uint8List imageBytes;

  @override
  State<AdjustEditorSheet> createState() => _AdjustEditorSheetState();
}

class _AdjustEditorSheetState extends State<AdjustEditorSheet> {
  ui.Image? _orig;
  Rect _fitRect = Rect.zero;

  late AdjustParams _params;
  AdjustAction _current = AdjustAction.brightnessContrast;

  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _params = const AdjustParams();
    _decode();
  }

  // 项目里的 Future 版解码：不要加 ui. 前缀
  Future<void> _decode() async {
    final img = await decodeImageFromList(widget.imageBytes);
    if (!mounted) return;
    setState(() => _orig = img);
  }

  Rect _containRect(Size content, Size box) {
    final sx = box.width / content.width;
    final sy = box.height / content.height;
    final s = sx < sy ? sx : sy;
    final w = content.width * s;
    final h = content.height * s;
    final dx = (box.width - w) / 2;
    final dy = (box.height - h) / 2;
    return Rect.fromLTWH(dx, dy, w, h);
  }

  PreferredSizeWidget _buildHeader(BuildContext ctx) {
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('调整'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(ctx),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _params = const AdjustParams()),
          child: const Text('重置', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: _exporting
              ? null
              : () async {
            // 占位：先返回原图；导出流程后续再接
            setState(() => _exporting = true);
            final data = widget.imageBytes;
            if (!mounted) return;
            setState(() => _exporting = false);
            Navigator.pop(ctx, data);
          },
          child: const Text('完成', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final bottomH = screenH / 3; // 底部容器占屏高 1/3
    const menuRowH = 56.0; // 菜单行高（防裁切）

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildHeader(context),
      body: (_orig == null)
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (_, c) {
          final imgSize =
          Size(_orig!.width.toDouble(), _orig!.height.toDouble());
          _fitRect = _containRect(
              imgSize, Size(c.maxWidth, c.maxHeight - bottomH));

          return Stack(
            children: [
              // —— 预览组件 —— //
              Positioned.fill(
                child: AdjustPreview(
                  orig: _orig!,
                  fitRect: _fitRect,
                  bc: _params.bc,
                  exposure: _params.exposure,
                  levels: _params.levels,
                  curves: _params.curves,
                  hsl: _params.hsl,  // ✅ 传入 HSL
                  sh: _params.sh,
                  vibrance: _params.vibrance,
                  colorBalance: _params.colorBalance,
                  selectiveColor: _params.selectiveColor,
                  bw: _params.bw,
                  photoFilter: _params.photoFilter,
                  mixer: _params.mixer,
                  invert: _params.invert,
                ),
              ),

              // —— 底部容器：菜单在上、面板在下（可滚动）——
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    height: bottomH,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.85),
                      border: const Border(
                          top: BorderSide(color: Colors.white12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AdjustMenu.flatRow(
                          enabled: true,
                          actions: kAllAdjustActions,
                          selected: _current,
                          onSelect: (a) =>
                              setState(() => _current = a),
                          rowHeight: menuRowH,
                          padding:
                          const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(
                                12, 10, 12, 12),
                            children: [
                              _buildPanelForCurrent(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_exporting)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child:
                    Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 子面板分发（与菜单一一对应）
  Widget _buildPanelForCurrent() {
    switch (_current) {
      case AdjustAction.brightnessContrast:
        return BrightnessContrastPanel(
          value: _params.bc,
          onChanged: (BrightnessContrast v) => // ✅ 强类型
          setState(() => _params = _params.copyWith(bc: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.exposure:
        return ExposurePanel(
          value: _params.exposure,
          onChanged: (ExposureParams v) =>   // ✅
          setState(() => _params = _params.copyWith(exposure: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.levels:
        return LevelsPanel(
          image: _orig!,
          value: _params.levels,
          onChanged: (LevelsParams v) =>     // ✅
          setState(() => _params = _params.copyWith(levels: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.curves:
        return CurvesPanel(
          image: _orig!,
          value: _params.curves,
          onChanged: (CurvesParams v) =>     // ✅
          setState(() => _params = _params.copyWith(curves: v)),
          onCommit: () => setState(() {}), // 松手刷新
        );
      case AdjustAction.hsl:
        return HslPanel(
          value: _params.hsl,
          onChanged: (HslParams v) =>       // ✅
          setState(() => _params = _params.copyWith(hsl: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.shadowsHighlights:
        return ShadowsHighlightsPanel(
          value: _params.sh,
          onChanged: (ShadowsHighlightsParams v) => // ✅
          setState(() => _params = _params.copyWith(sh: v)),
        );
      case AdjustAction.vibrance:
        return VibrancePanel(
          value: _params.vibrance,
          onChanged: (VibranceParams v) =>  // ✅
          setState(() => _params = _params.copyWith(vibrance: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.colorBalance:
        return ColorBalancePanel(
          value: _params.colorBalance,
          onChanged: (v) => setState(() => _params = _params.copyWith(colorBalance: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.selectiveColor:
        return SelectiveColorPanel(
          value: _params.selectiveColor,
          onChanged: (SelectiveColorParams v) =>
              setState(() => _params = _params.copyWith(selectiveColor: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.blackWhite:
        return BlackWhitePanel(
          value: _params.bw,
          onChanged: (BlackWhiteParams v) =>
              setState(() => _params = _params.copyWith(bw: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.photoFilter:
        return PhotoFilterPanel(
          value: _params.photoFilter,
          onChanged: (v) => setState(() => _params = _params.copyWith(photoFilter: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.channelMixer:
        return ChannelMixerPanel(
          value: _params.mixer,
          onChanged: (v) => setState(() => _params = _params.copyWith(mixer: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.invert:
        return InvertPanel(
          value: _params.invert,
          onChanged: (v) => setState(() => _params = _params.copyWith(invert: v)),
          onCommit: () => setState(() {}),
        );

      default:
        return _PlaceholderPanel(labelForAdjustAction(_current));
    }
  }
}

/* ===== 未实现功能占位 ===== */

class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$title：面板待接入',
                style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
