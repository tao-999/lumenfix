// lib/widgets/adjust/adjust_preview.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// —— 参数类型：从 params/ 统一导出 —— //
import 'params/params.dart';

// —— 引擎 —— //
import 'engine/denoise_engine.dart';          // 🆕 降噪引擎
import 'engine/hsl_engine.dart';
import 'engine/color_balance.dart';
import 'engine/selective_color.dart';
import 'engine/channel_mixer_engine.dart';
import 'engine/black_white_engine.dart';
import 'engine/photo_filter_engine.dart';
import 'engine/shadows_highlights.dart';
import 'engine/vibrance.dart';
import 'engine/invert_engine.dart';
import 'engine/desaturate_engine.dart';
import 'engine/gradient_map_engine.dart';
import 'engine/posterize_engine.dart';
import 'engine/replace_color_engine.dart';
import 'engine/threshold_engine.dart';

class AdjustPreview extends StatefulWidget {
  const AdjustPreview({
    super.key,
    required this.orig,
    required this.fitRect,

    // —— 基础 —— //
    required this.bc,
    required this.exposure,
    required this.levels,
    required this.curves,

    // —— 颜色 —— //
    required this.hsl,
    required this.colorBalance,
    required this.selectiveColor,
    required this.mixer,
    required this.bw,
    required this.photoFilter,
    required this.sh,
    required this.vibrance,

    // —— 降噪 —— //
    required this.denoise,

    // —— 特殊 —— //
    required this.invert,
    required this.posterize,
    required this.threshold,
    required this.gradientMap,
    required this.desaturate,
    required this.replaceColor,
  });

  final ui.Image orig;
  final Rect fitRect;

  // —— 基础 —— //
  final BrightnessContrast bc;
  final ExposureParams exposure;
  final LevelsParams levels;
  final CurvesParams curves;

  // —— 颜色 —— //
  final HslParams hsl;
  final ColorBalanceParams colorBalance;
  final SelectiveColorParams selectiveColor;
  final ChannelMixerParams mixer;
  final BlackWhiteParams bw;
  final PhotoFilterParams photoFilter;

  // —— 局部光照 & 饱和 —— //
  final ShadowsHighlightsParams sh;
  final VibranceParams vibrance;

  // —— 降噪 —— //
  final DenoiseParams denoise;

  // —— 特殊 —— //
  final InvertParams invert;
  final PosterizeParams posterize;
  final ThresholdParams threshold;
  final GradientMapParams gradientMap;
  final DesaturateParams desaturate;
  final ReplaceColorParams replaceColor;

  @override
  State<AdjustPreview> createState() => _AdjustPreviewState();
}

class _AdjustPreviewState extends State<AdjustPreview> {
  ui.Image? _preview;
  bool _rebuilding = false;
  bool _dirty = false;

  // 预览像素预算（1MP 更丝滑；要更清晰可调回 3MP）
  static const int _kMaxPreviewPixels = 1 * 1024 * 1024;

  // 轻微防抖，避免频繁重建卡顿
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // 首帧绘制后再做第一次重建，避免与路由/MediaQuery 冲突
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleRebuild();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 不在这里重建：Dropdown 打开/关闭会触发依赖变化，容易卡
  }

  @override
  void didUpdateWidget(covariant AdjustPreview old) {
    super.didUpdateWidget(old);

    // 仅在参数“真的有变化”时重建；打开下拉等 UI 操作不会触发
    final same =
        identical(widget.orig, old.orig) &&
            widget.fitRect == old.fitRect &&
            widget.bc == old.bc &&
            widget.exposure == old.exposure &&
            widget.levels == old.levels &&
            widget.curves == old.curves &&
            widget.hsl == old.hsl &&
            widget.colorBalance == old.colorBalance &&
            widget.selectiveColor == old.selectiveColor &&
            widget.mixer == old.mixer &&
            widget.bw == old.bw &&
            widget.photoFilter == old.photoFilter &&
            widget.sh == old.sh &&
            widget.vibrance == old.vibrance &&
            widget.denoise == old.denoise && // 🆕
            widget.invert == old.invert &&
            widget.posterize == old.posterize &&
            widget.threshold == old.threshold &&
            widget.gradientMap == old.gradientMap &&
            widget.desaturate == old.desaturate &&
            widget.replaceColor == old.replaceColor;

    if (!same) {
      _scheduleRebuild();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // 实时获取 DPR（首帧后用 MediaQuery 安全）
  double _currentDpr() {
    final mq = MediaQuery.maybeOf(context);
    if (mq != null) return mq.devicePixelRatio;
    try {
      return View.of(context).devicePixelRatio; // Flutter 3.10+
    } catch (_) {
      final implicit = WidgetsBinding.instance.platformDispatcher.implicitView;
      if (implicit != null) return implicit.devicePixelRatio;
      final views = WidgetsBinding.instance.platformDispatcher.views;
      return views.isNotEmpty ? views.first.devicePixelRatio : 1.0;
    }
  }

  void _scheduleRebuild({Duration debounce = const Duration(milliseconds: 60)}) {
    if (_rebuilding) {
      _dirty = true;
      return;
    }
    _debounce?.cancel();
    if (debounce == Duration.zero) {
      _rebuild();
    } else {
      _debounce = Timer(debounce, _rebuild);
    }
  }

  Future<void> _rebuild() async {
    _rebuilding = true;
    _dirty = false;

    final outSizePx = _pickPreviewSizePx(widget.fitRect.size);
    final frame = await _rasterToSize(widget.orig, outSizePx);

    // —— 预生成 LUT（曝光 / 亮度对比度 / 色阶 / 曲线） —— //
    final lut = _buildCombinedLuts(
      bc: widget.bc,
      exposure: widget.exposure,
      levels: widget.levels,
      curves: widget.curves,
    );

    // —— 合成顺序 —— //
    final cooked = await _applyPipeline(
      frame,
      lut,

      // 前置：降噪在 LUT 之后、HSL 之前
      widget.denoise,

      // 颜色系
      widget.hsl,
      widget.colorBalance,
      widget.selectiveColor,
      widget.mixer,
      widget.bw,
      widget.photoFilter,
      widget.sh,
      widget.vibrance,

      // 特殊系
      widget.invert,
      widget.posterize,
      widget.threshold,
      widget.gradientMap,
      widget.desaturate,
      widget.replaceColor,
    );

    if (!mounted) return;
    setState(() => _preview = cooked);

    _rebuilding = false;
    if (_dirty) _rebuild();
  }

  Size _pickPreviewSizePx(Size fitDp) {
    final dpr = _currentDpr();
    final targetW = (fitDp.width * dpr).ceil();
    final targetH = (fitDp.height * dpr).ceil();

    int w = targetW.clamp(1, widget.orig.width);
    int h = targetH.clamp(1, widget.orig.height);

    final area = w * h;
    if (area > _kMaxPreviewPixels) {
      final s = math.sqrt(_kMaxPreviewPixels / area);
      w = (w * s).round().clamp(1, widget.orig.width);
      h = (h * s).round().clamp(1, widget.orig.height);
    }
    w = math.max(64, w);
    h = math.max(64, h);
    return Size(w.toDouble(), h.toDouble());
  }

  Future<ui.Image> _rasterToSize(ui.Image src, Size outPx) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final dst = Rect.fromLTWH(0, 0, outPx.width, outPx.height);
    final srcRect = Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.high;
    c.drawImageRect(src, srcRect, dst, paint);
    final pic = rec.endRecording();
    return pic.toImage(outPx.width.toInt(), outPx.height.toInt());
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PreviewPainter(
          image: _preview ?? widget.orig,
          fitRect: widget.fitRect,
        ),
        child: _rebuilding
            ? const SizedBox.expand(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        )
            : null,
      ),
    );
  }

  /* =========================
   * LUT + Denoise + HSL + CB + SC + MIX + BW + PF + SH + Vibrance + Invert
   * ========================= */

  _RgbLut _buildCombinedLuts({
    required BrightnessContrast bc,
    required ExposureParams exposure,
    required LevelsParams levels,
    required CurvesParams curves,
  }) {
    List<double> _id() => List<double>.generate(256, (i) => i.toDouble());

    // 灰度通道映射（master）
    var gray = _id();

    // 1) 曝光：乘 2^ev + offset + gamma
    final evMul = math.pow(2.0, exposure.ev).toDouble();
    final offs = exposure.offset;
    final gma = exposure.gamma.clamp(0.10, 3.0);
    for (int i = 0; i < 256; i++) {
      double t = (gray[i] / 255.0) * evMul + offs;
      t = t.clamp(0.0, 1.0);
      t = math.pow(t, 1.0 / gma).toDouble();
      gray[i] = (t * 255.0);
    }

    // 2) 亮度/对比度
    final b = bc.brightness / 100.0;
    final c = bc.contrast / 100.0;
    for (int i = 0; i < 256; i++) {
      double t = gray[i] / 255.0;
      t = ((t - 0.5) * (1.0 + c) + 0.5) + b;
      gray[i] = (t.clamp(0.0, 1.0) * 255.0);
    }

    // 3) 色阶
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

    // 4) 曲线：master + RGB
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

  Future<ui.Image> _applyPipeline(
      ui.Image src,
      _RgbLut lut,

      // —— 降噪 —— //
      DenoiseParams denoise,

      // —— 颜色 —— //
      HslParams hsl,
      ColorBalanceParams cb,
      SelectiveColorParams sc,
      ChannelMixerParams mix,
      BlackWhiteParams bw,
      PhotoFilterParams pf,
      ShadowsHighlightsParams sh,
      VibranceParams vibrance,

      // —— 特殊 —— //
      InvertParams invert,
      PosterizeParams posterize,
      ThresholdParams threshold,
      GradientMapParams gradientMap,
      DesaturateParams desat,
      ReplaceColorParams repl,
      ) async {
    final w = src.width, h = src.height;
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = bd!.buffer.asUint8List();

    // 1) LUT
    for (int i = 0; i < bytes.length; i += 4) {
      bytes[i]     = lut.r[bytes[i]];
      bytes[i + 1] = lut.g[bytes[i + 1]];
      bytes[i + 2] = lut.b[bytes[i + 2]];
    }

    // 1.5) Denoise（早做：为后续色彩/曲线提供更干净底子）
    if (!denoise.isNeutral) {
      DenoiseEngine.applyToRgbaInPlace(bytes, w, h, denoise);
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

    // 10) 反相（接近最后）
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

    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
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
}

class _RgbLut {
  _RgbLut(this.r, this.g, this.b);
  final Uint8List r, g, b;
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter({required this.image, required this.fitRect});
  final ui.Image image;
  final Rect fitRect;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(image, src, fitRect, paint);
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) =>
      old.image != image || old.fitRect != fitRect;
}
