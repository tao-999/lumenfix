// lib/widgets/adjust/engine/curves.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../params/curves_params.dart';
import 'levels.dart' show LevelsEngine, LevelsChannel, HistogramResult;

/// 曲线插值模式
enum CurveMode { spline, linear }

class CurvesEngine {
  /// 生成整套 LUT（每通道 0..255）
  static Map<String, Uint8List> buildLuts({
    required CurvesParams params,
    CurveMode mode = CurveMode.spline,
  }) {
    final lutM = _lutFromPoints(params.master.points, mode: mode);
    final lutR = _lutFromPoints(params.r.points, mode: mode);
    final lutG = _lutFromPoints(params.g.points, mode: mode);
    final lutB = _lutFromPoints(params.b.points, mode: mode);
    return {
      'master': lutM,
      'r': lutR,
      'g': lutG,
      'b': lutB,
    };
  }

  /// 把 LUT 应用到 RGBA 图，返回新的 `ui.Image`
  static Future<ui.Image> applyToImage({
    required ui.Image src,
    required CurvesParams params,
    CurveMode mode = CurveMode.spline,
  }) async {
    final luts = buildLuts(params: params, mode: mode);
    final lutM = luts['master']!;
    final lutR = luts['r']!;
    final lutG = luts['g']!;
    final lutB = luts['b']!;

    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return src;
    final Uint8List px = Uint8List.fromList(bd.buffer.asUint8List());

    for (int i = 0; i < px.length; i += 4) {
      final r0 = px[i];
      final g0 = px[i + 1];
      final b0 = px[i + 2];

      final r1 = lutM[r0];
      final g1 = lutM[g0];
      final b1 = lutM[b0];

      px[i    ] = lutR[r1];
      px[i + 1] = lutG[g1];
      px[i + 2] = lutB[b1];
    }

    final ib = await ui.ImmutableBuffer.fromUint8List(px);
    final desc = ui.ImageDescriptor.raw(
      ib,
      width: src.width,
      height: src.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await desc.instantiateCodec();
    final frame = await codec.getNextFrame();
    final out = frame.image;
    // 这俩是同步的，不能 await
    codec.dispose();
    ib.dispose();
    return out;
  }

  /// —— Auto：按直方图估算一条「端点+中点」曲线 —— ///
  static Future<List<Offset>> autoCurve(ui.Image img, LevelsChannel ch) async {
    final hist = await LevelsEngine.computeHistogram(img, channel: ch, sampleStep: 2);
    return autoCurveFromHistogram(hist);
  }

  static List<Offset> autoCurveFromHistogram(HistogramResult h) {
    final total = h.total;
    if (total <= 0) return const [Offset(0,0), Offset(0.5,0.5), Offset(1,1)];

    final lowTarget  = (total * 0.005).round();
    final highTarget = (total * 0.995).round();

    int cum = 0, inBlack = 0, inWhite = 255;
    for (int i = 0; i < 256; i++) { cum += h.bins[i]; if (cum >= lowTarget)  { inBlack = i; break; } }
    cum = 0;
    for (int i = 0; i < 256; i++) { cum += h.bins[i]; if (cum >= highTarget) { inWhite = i; break; } }
    if (inWhite <= inBlack) inWhite = (inBlack + 1).clamp(1, 255);

    final midTarget = total ~/ 2;
    int acc = 0, mid = 127;
    for (int i = 0; i < 256; i++) { acc += h.bins[i]; if (acc >= midTarget) { mid = i; break; } }

    final ib = inBlack / 255.0;
    final iw = inWhite / 255.0;
    final xm = ((mid / 255.0) - ib) / (iw - ib);
    final xMid = xm.clamp(1e-5, 1.0 - 1e-5);

    final gamma = (math.log(0.5) / math.log(xMid)).clamp(0.10, 3.0);
    final yMid = math.pow(0.5, 1.0 / gamma).toDouble();

    return <Offset>[
      const Offset(0, 0),
      Offset(0.5, yMid),
      const Offset(1, 1),
    ];
  }

  /// —— 核心：由控制点生成 0..255 LUT —— ///
  static Uint8List _lutFromPoints(List<Offset> pts, {CurveMode mode = CurveMode.spline}) {
    final p = _normalizedSorted(pts);
    return mode == CurveMode.linear ? _lutLinear(p) : _lutMonotoneCubic(p);
  }

  /// 线性插值 LUT
  static Uint8List _lutLinear(List<Offset> pts) {
    final lut = Uint8List(256);
    int seg = 0;
    for (int x = 0; x < 256; x++) {
      final t = x / 255.0;
      while (seg < pts.length - 2 && t > pts[seg + 1].dx) seg++;
      final a = pts[seg];
      final b = pts[seg + 1];
      final u = ((t - a.dx) / (b.dx - a.dx)).clamp(0.0, 1.0);
      final y = a.dy + (b.dy - a.dy) * u;
      lut[x] = (y.clamp(0.0, 1.0) * 255.0 + 0.5).floor();
    }
    return lut;
  }

  /// 单调三次 Hermite（Fritsch–Carlson）LUT
  static Uint8List _lutMonotoneCubic(List<Offset> pts) {
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

    final lut = Uint8List(256);
    int seg = 0;
    for (int x = 0; x < 256; x++) {
      final t = x / 255.0;
      while (seg < n - 1 && t > pts[seg + 1].dx) seg++;
      final x0 = pts[seg].dx, x1 = pts[seg + 1].dx;
      final y0 = pts[seg].dy, y1 = pts[seg + 1].dy;
      final hseg = x1 - x0;
      final s = ((t - x0) / hseg).clamp(0.0, 1.0);

      final h00 = (2 * s * s * s - 3 * s * s + 1);
      final h10 = (s * s * s - 2 * s * s + s);
      final h01 = (-2 * s * s * s + 3 * s * s);
      final h11 = (s * s * s - s * s);

      final y = h00 * y0 + h10 * hseg * tang[seg] + h01 * y1 + h11 * hseg * tang[seg + 1];
      lut[x] = (y.clamp(0.0, 1.0) * 255.0 + 0.5).floor();
    }
    return lut;
  }

  /// —— 公共：提供给 UI 的规范化工具（带端点、去重、排序） —— ///
  static List<Offset> normalizePoints(List<Offset> src) => _normalizedSorted(src);

  /// —— 私有：规范化/排序/端点补齐 —— ///
// lib/widgets/adjust/engine/curves.dart

  static List<Offset> _normalizedSorted(List<Offset> src) {
    final pts = <Offset>[...src];
    if (pts.isEmpty) pts.addAll(const [Offset(0,0), Offset(1,1)]);
    pts.sort((a,b)=>a.dx.compareTo(b.dx));

    final out = <Offset>[];
    for (final p in pts) {
      final x = p.dx.clamp(0.0, 1.0);
      final y = p.dy.clamp(0.0, 1.0);
      if (out.isEmpty || (x - out.last.dx).abs() > 1e-6) {
        out.add(Offset(x, y));
      } else {
        // 同 x 取后者
        out[out.length - 1] = Offset(x, y);
      }
    }

    // ✅ 端点只锁 X，不强制 Y=0/1；若缺少端点，用相邻点的 Y 续上
    if (out.first.dx > 0) {
      final y0 = out.first.dy;          // 用第一段的 y 作为端点 y
      out.insert(0, Offset(0.0, y0));
    }
    if (out.last.dx < 1) {
      final y1 = out.last.dy;           // 用最后一段的 y 作为端点 y
      out.add(Offset(1.0, y1));
    }

    return out;
  }

}
