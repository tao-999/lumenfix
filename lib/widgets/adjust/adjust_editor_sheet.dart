// lib/widgets/adjust/adjust_editor_sheet.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lumenfix/widgets/adjust/panel/blackwhite_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/channel_mixer_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/color_balance_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/denoise_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/desaturate_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/gradient_map_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/invert_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/photo_filter_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/posterize_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/replace_color_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/selective_color_panel.dart';
import 'package:lumenfix/widgets/adjust/panel/threshold_panel.dart';

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

// ====== 为“完成”导出引擎，这里直接用一模一样的处理顺序（不新建文件） ======
import 'engine/hsl_engine.dart';
import 'engine/color_balance.dart';
import 'engine/selective_color.dart';
import 'engine/channel_mixer_engine.dart';
import 'engine/black_white_engine.dart';
import 'engine/photo_filter_engine.dart';
import 'engine/shadows_highlights.dart';
import 'engine/vibrance.dart';
import 'engine/invert_engine.dart';
import 'engine/posterize_engine.dart';
import 'engine/threshold_engine.dart';
import 'engine/gradient_map_engine.dart';
import 'engine/desaturate_engine.dart';
import 'engine/replace_color_engine.dart';

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
            setState(() => _exporting = true);
            try {
              // ✅ 全分辨率导出（与预览完全同序）
              final data = await _exportPngBytes(_orig!, _params);
              if (!mounted) return;
              Navigator.pop(ctx, data); // 返回处理后的 PNG bytes
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('导出失败：$e')),
              );
            } finally {
              if (mounted) setState(() => _exporting = false);
            }
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
                  hsl: _params.hsl, // ✅ 传入 HSL
                  sh: _params.sh,
                  vibrance: _params.vibrance,
                  colorBalance: _params.colorBalance,
                  selectiveColor: _params.selectiveColor,
                  bw: _params.bw,
                  photoFilter: _params.photoFilter,
                  mixer: _params.mixer,
                  invert: _params.invert,
                  posterize: _params.posterize,
                  threshold: _params.threshold,
                  gradientMap: _params.gradientMap,
                  desaturate: _params.desaturate,
                  replaceColor: _params.replaceColor,
                  denoise: _params.denoise,
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
          onChanged: (BrightnessContrast v) =>
              setState(() => _params = _params.copyWith(bc: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.exposure:
        return ExposurePanel(
          value: _params.exposure,
          onChanged: (ExposureParams v) =>
              setState(() => _params = _params.copyWith(exposure: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.levels:
        return LevelsPanel(
          image: _orig!,
          value: _params.levels,
          onChanged: (LevelsParams v) =>
              setState(() => _params = _params.copyWith(levels: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.curves:
        return CurvesPanel(
          image: _orig!,
          value: _params.curves,
          onChanged: (CurvesParams v) =>
              setState(() => _params = _params.copyWith(curves: v)),
          onCommit: () => setState(() {}), // 松手刷新
        );
      case AdjustAction.hsl:
        return HslPanel(
          value: _params.hsl,
          onChanged: (HslParams v) =>
              setState(() => _params = _params.copyWith(hsl: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.shadowsHighlights:
        return ShadowsHighlightsPanel(
          value: _params.sh,
          onChanged: (ShadowsHighlightsParams v) =>
              setState(() => _params = _params.copyWith(sh: v)),
        );
      case AdjustAction.vibrance:
        return VibrancePanel(
          value: _params.vibrance,
          onChanged: (VibranceParams v) =>
              setState(() => _params = _params.copyWith(vibrance: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.colorBalance:
        return ColorBalancePanel(
          value: _params.colorBalance,
          onChanged: (v) =>
              setState(() => _params = _params.copyWith(colorBalance: v)),
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
          onChanged: (v) =>
              setState(() => _params = _params.copyWith(photoFilter: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.channelMixer:
        return ChannelMixerPanel(
          value: _params.mixer,
          onChanged: (v) =>
              setState(() => _params = _params.copyWith(mixer: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.invert:
        return InvertPanel(
          value: _params.invert,
          onChanged: (v) =>
              setState(() => _params = _params.copyWith(invert: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.posterize:
        return PosterizePanel(
          value: _params.posterize,
          onChanged: (PosterizeParams v) =>
              setState(() => _params = _params.copyWith(posterize: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.threshold:
        return ThresholdPanel(
          value: _params.threshold,
          onChanged: (ThresholdParams v) =>
              setState(() => _params = _params.copyWith(threshold: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.gradientMap:
        return GradientMapPanel(
          value: _params.gradientMap,
          onChanged: (v) =>
              setState(() => _params = _params.copyWith(gradientMap: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.desaturate:
        return DesaturatePanel(
          value: _params.desaturate,
          onChanged: (v) =>
              setState(() => _params = _params.copyWith(desaturate: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.replaceColor:
        return ReplaceColorPanel(
          value: _params.replaceColor,
          onChanged: (v) =>
              setState(() => _params = _params.copyWith(replaceColor: v)),
          onCommit: () => setState(() {}),
        );
      case AdjustAction.denoise:
        return DenoisePanel(
          value: _params.denoise,
          onChanged: (v) => setState(() => _params = _params.copyWith(denoise: v)),
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

// =========================
// ====== 导出实现区 =======
// =========================

Future<Uint8List> _exportPngBytes(ui.Image src, AdjustParams p) async {
  final w = src.width, h = src.height;
  final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = bd!.buffer.asUint8List();

  final lut = _buildCombinedLuts(
    bc: p.bc,
    exposure: p.exposure,
    levels: p.levels,
    curves: p.curves,
  );

  _applyPipelineInPlace(
    bytes, w, h,
    lut: lut,
    hsl: p.hsl,
    cb: p.colorBalance,
    sc: p.selectiveColor,
    mix: p.mixer,
    bw: p.bw,
    pf: p.photoFilter,
    sh: p.sh,
    vibrance: p.vibrance,
    invert: p.invert,
    posterize: p.posterize,
    threshold: p.threshold,
    gradientMap: p.gradientMap,
    desat: p.desaturate,
    repl: p.replaceColor,
  );

  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(bytes, w, h, ui.PixelFormat.rgba8888, c.complete);
  final cooked = await c.future;
  final out = await cooked.toByteData(format: ui.ImageByteFormat.png);
  return out!.buffer.asUint8List();
}

void _applyPipelineInPlace(
    Uint8List bytes, int w, int h, {
      required _RgbLut lut,
      required HslParams hsl,
      required ColorBalanceParams cb,
      required SelectiveColorParams sc,
      required ChannelMixerParams mix,
      required BlackWhiteParams bw,
      required PhotoFilterParams pf,
      required ShadowsHighlightsParams sh,
      required VibranceParams vibrance,
      required InvertParams invert,
      required PosterizeParams posterize,
      required ThresholdParams threshold,
      required GradientMapParams gradientMap,
      required DesaturateParams desat,
      required ReplaceColorParams repl,
    }) {
  // 1) LUT
  for (int i = 0; i < bytes.length; i += 4) {
    bytes[i]     = lut.r[bytes[i]];
    bytes[i + 1] = lut.g[bytes[i + 1]];
    bytes[i + 2] = lut.b[bytes[i + 2]];
  }
  // 2) HSL
  if (!_hslIsNeutral(hsl)) {
    HslEngine.applyToRgbaInPlace(bytes, w, h, hsl);
  }
  // 3) 色彩平衡
  if (!cb.isNeutral) {
    ColorBalanceEngine.applyToRgbaInPlace(bytes, w, h, cb);
  }
  // 4) 可选颜色
  if (!sc.isNeutral) {
    SelectiveColorEngine.applyToRgbaInPlace(bytes, w, h, sc);
  }
  // 5) 通道混合器
  if (!_mixerIsNeutral(mix)) {
    ChannelMixerEngine.applyToRgbaInPlace(bytes, w, h, mix);
  }
  // 6) 黑白
  if (bw.enabled) {
    BlackWhiteEngine.applyToRgbaInPlace(bytes, w, h, bw);
  }
  // 7) 照片滤镜
  if (!pf.isNeutral) {
    PhotoFilterEngine.applyToRgbaInPlace(bytes, w, h, pf);
  }
  // 8) 阴影/高光
  if (!sh.isNeutral) {
    ShadowsHighlightsEngine.applyToRgbaInPlace(bytes, w, h, sh);
  }
  // 9) 自然饱和度 / 饱和度
  if (vibrance.vibrance != 0 || vibrance.saturation != 0) {
    VibranceEngine.applyToRgbaInPlace(bytes, w, h, vibrance);
  }
  // 10) 反相
  if (!invert.isNeutral) {
    InvertEngine.applyToRgbaInPlace(bytes, w, h, invert);
  }
  // 11) 色调分离
  if (!posterize.isNeutral) {
    PosterizeEngine.applyToRgbaInPlace(bytes, w, h, posterize);
  }
  // 12) 阈值
  if (threshold.enabled) {
    ThresholdEngine.applyToRgbaInPlace(bytes, w, h, threshold);
  }
  // 13) 渐变映射
  if (!gradientMap.isNeutral) {
    GradientMapEngine.applyToRgbaInPlace(bytes, w, h, gradientMap);
  }
  // 14) 去色
  if (desat.enabled) {
    DesaturateEngine.applyToRgbaInPlace(bytes, w, h);
  }
  // 15) 替换颜色
  if (!repl.isNeutral) {
    ReplaceColorEngine.applyToRgbaInPlace(bytes, w, h, repl);
  }
}

_RgbLut _buildCombinedLuts({
  required BrightnessContrast bc,
  required ExposureParams exposure,
  required LevelsParams levels,
  required CurvesParams curves,
}) {
  List<double> _id() => List<double>.generate(256, (i) => i.toDouble());
  var gray = _id();

  // 曝光：乘 2^ev + offset + gamma
  final evMul = math.pow(2.0, exposure.ev).toDouble();
  final offs  = exposure.offset;
  final gma   = exposure.gamma.clamp(0.10, 3.0);
  for (int i = 0; i < 256; i++) {
    double t = (gray[i] / 255.0) * evMul + offs;
    t = t.clamp(0.0, 1.0);
    t = math.pow(t, 1.0 / gma).toDouble();
    gray[i] = (t * 255.0);
  }

  // 亮度/对比度
  final b = bc.brightness / 100.0;
  final c = bc.contrast / 100.0;
  for (int i = 0; i < 256; i++) {
    double t = gray[i] / 255.0;
    t = ((t - 0.5) * (1.0 + c) + 0.5) + b;
    gray[i] = (t.clamp(0.0, 1.0) * 255.0);
  }

  // 色阶
  final ib = levels.inBlack.clamp(0, 255);
  final iw = levels.inWhite.clamp(0, 255);
  final ob = levels.outBlack.clamp(0, 255);
  final ow = levels.outWhite.clamp(0, 255);
  final invRange = 1.0 / math.max(1, iw - ib);
  final lgamma = levels.gamma.clamp(0.10, 3.0);
  for (int i = 0; i < 256; i++) {
    double t = (gray[i] - ib) * invRange;
    t = t.clamp(0.0, 1.0);
    t = math.pow(t, 1.0 / lgamma).toDouble();
    final out = ob + t * (ow - ob);
    gray[i] = out.clamp(0.0, 255.0);
  }

  // 曲线：master + RGB
  final master = _buildCurveMap(curves.master.points);
  for (int i = 0; i < 256; i++) {
    final mi = master[(gray[i]).round().clamp(0, 255)];
    gray[i] = mi.toDouble();
  }

  final rCurve = _buildCurveMap(curves.r.points);
  final gCurve = _buildCurveMap(curves.g.points);
  final bCurve = _buildCurveMap(curves.b.points);

  final outR = Uint8List(256);
  final outG = Uint8List(256);
  final outB = Uint8List(256);
  for (int i = 0; i < 256; i++) {
    final gi = gray[i].round().clamp(0, 255);
    outR[i] = rCurve[gi];
    outG[i] = gCurve[gi];
    outB[i] = bCurve[gi];
  }
  return _RgbLut(outR, outG, outB);
}

List<int> _buildCurveMap(List<Offset> raw) {
  final pts = _normalizePoints(raw);
  final map = List<int>.filled(256, 0);
  for (int i = 0; i < 256; i++) {
    final x = i / 255.0;
    final y = _evalHermite(pts, x);
    map[i] = (y * 255.0).round().clamp(0, 255);
  }
  return map;
}

List<Offset> _normalizePoints(List<Offset> input) {
  final pts = List<Offset>.from(input)..sort((a, b) => a.dx.compareTo(b.dx));
  pts[0] = Offset(0, pts[0].dy.clamp(0, 1));
  pts[pts.length - 1] = Offset(1, pts.last.dy.clamp(0, 1));
  for (int i = 1; i < pts.length; i++) {
    if (pts[i].dx <= pts[i - 1].dx) {
      pts[i] = Offset(pts[i - 1].dx + 1e-6, pts[i].dy);
    }
    pts[i] = Offset(pts[i].dx.clamp(0, 1), pts[i].dy.clamp(0, 1));
  }
  return pts;
}

double _evalHermite(List<Offset> pts, double x) {
  if (pts.length <= 1) return x;
  final n = pts.length - 1;
  final h = List<double>.filled(n, 0);
  final m = List<double>.filled(n, 0);
  for (int i = 0; i < n; i++) {
    final dx = pts[i + 1].dx - pts[i].dx;
    h[i] = dx;
    m[i] = (pts[i + 1].dy - pts[i].dy) / dx;
  }
  final tang = List<double>.filled(n + 1, 0);
  tang[0] = m[0];
  tang[n] = m[n - 1];
  for (int i = 1; i < n; i++) {
    if (m[i - 1] * m[i] <= 0) {
      tang[i] = 0;
    } else {
      final w1 = 1 + h[i] / (h[i - 1] + 1e-9);
      final w2 = 1 + h[i - 1] / (h[i] + 1e-9);
      tang[i] = (w1 + w2) / (w1 / m[i - 1] + w2 / m[i]);
    }
  }
  if (tang[0].abs() > 3 * m[0].abs()) tang[0] = 3 * m[0];
  if (tang[n].abs() > 3 * m[n - 1].abs()) tang[n] = 3 * m[n - 1];

  int seg = 0;
  while (seg < n - 1 && x > pts[seg + 1].dx) seg++;
  final x0 = pts[seg].dx, x1 = pts[seg + 1].dx;
  final y0 = pts[seg].dy, y1 = pts[seg + 1].dy;
  final hseg = x1 - x0;
  final s = ((x - x0) / hseg).clamp(0.0, 1.0);

  final h00 = (2 * s * s * s - 3 * s * s + 1);
  final h10 = (s * s * s - 2 * s * s + s);
  final h01 = (-2 * s * s * s + 3 * s * s);
  final h11 = (s * s * s - s * s);
  return (h00 * y0 + h10 * hseg * tang[seg] + h01 * y1 + h11 * hseg * tang[seg + 1])
      .clamp(0.0, 1.0);
}

bool _hslIsNeutral(HslParams p) {
  if (p.colorize) return false; // 勾选就生效
  for (final e in p.bands.entries) {
    if (!e.value.isNeutral) return false;
  }
  return true;
}

bool _mixerIsNeutral(ChannelMixerParams p) {
  if (p.matrix.length != 9 || p.offset.length != 3) return false;
  const id = <double>[1, 0, 0,  0, 1, 0,  0, 0, 1];
  for (int i = 0; i < 9; i++) {
    if ((p.matrix[i] - id[i]).abs() > 1e-9) return false;
  }
  if (p.offset[0].abs() > 1e-9) return false;
  if (p.offset[1].abs() > 1e-9) return false;
  if (p.offset[2].abs() > 1e-9) return false;
  return true;
}

class _RgbLut {
  _RgbLut(this.r, this.g, this.b);
  final Uint8List r, g, b;
}
