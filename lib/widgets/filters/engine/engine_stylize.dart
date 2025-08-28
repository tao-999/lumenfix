// lib/widgets/filters/engine/engine_stylize.dart
//
// ✅ 专业版绘画引擎（纯 Dart / RGBA, 已接入后台 Isolate）
// 关键改进：
// 1) XDoG（eXtended DoG）漫画墨线：边缘更干净、可调节阈值与锐度
// 2) Guided Filter 引导滤波：O(N) 复杂度边缘保留平滑
// 3) 三盒逼近高斯（3*BoxBlur）
// 4) KMeans 色彩聚类量化（下采样采样+迭代）
// 5) 改进油画（加权众数）
// 6) 方向感知霓虹：梯度方向上色
//
// ⚙️ 后台异步：所有 stylize* 公共函数都会把工作丢到后台 Isolate 执行，主线程不阻塞。
//     - compute(_filterEntry, job) + TransferableTypedData 零拷贝传输
//     - 对外 API（函数名/参数/返回 Future<Uint8List>）保持不变
// ─────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // compute + TransferableTypedData
import 'dart:isolate' show TransferableTypedData;
import 'package:flutter/foundation.dart' show compute, kIsWeb;

// 开关：需要时可改为 false 退回前台（调试用）
const bool _useBackgroundIsolate = true;

// ============= 对外：20+ 种绘画风格（签名不变，内部已异步） =============

// 卡通（基础）：引导滤波 + KMeans 量化 + XDoG 墨线
Future<Uint8List> stylizeCartoon(Uint8List rgba, int w, int h,
    {int blur = 1, int levels = 6, double edge = 0.28}) {
  return _runOnWorker('cartoon', rgba, w, h, {
    'blur': blur,
    'levels': levels,
    'edge': edge,
  });
}

// 卡通（厚描边）
Future<Uint8List> stylizeCartoonBold(Uint8List rgba, int w, int h) {
  return _runOnWorker('cartoon_bold', rgba, w, h, {});
}

// 彩绘（偏暖水彩）
Future<Uint8List> stylizeWatercolor(Uint8List rgba, int w, int h) {
  return _runOnWorker('watercolor', rgba, w, h, {});
}

// 水粉（柔和+低细节）
Future<Uint8List> stylizeGouache(Uint8List rgba, int w, int h) {
  return _runOnWorker('gouache', rgba, w, h, {});
}

// 油画：改进加权众数
Future<Uint8List> stylizeOil(Uint8List rgba, int w, int h) {
  return _runOnWorker('oil', rgba, w, h, {});
}

// 粉彩
Future<Uint8List> stylizePastel(Uint8List rgba, int w, int h) {
  return _runOnWorker('pastel', rgba, w, h, {});
}

// 彩铅素描（彩色）
Future<Uint8List> stylizeSketchColor(Uint8List rgba, int w, int h) {
  return _runOnWorker('sketch_color', rgba, w, h, {});
}

// 铅笔素描（黑白）
Future<Uint8List> stylizeSketchBW(Uint8List rgba, int w, int h) {
  return _runOnWorker('sketch_bw', rgba, w, h, {});
}

// 木炭
Future<Uint8List> stylizeCharcoal(Uint8List rgba, int w, int h) {
  return _runOnWorker('charcoal', rgba, w, h, {});
}

// 墨线（漫画墨水）
Future<Uint8List> stylizeInk(Uint8List rgba, int w, int h) {
  return _runOnWorker('ink', rgba, w, h, {});
}

// 雕塑（浮雕+去色）
Future<Uint8List> stylizeSculpt(Uint8List rgba, int w, int h) {
  return _runOnWorker('sculpt', rgba, w, h, {});
}

// 浮雕
Future<Uint8List> stylizeRelief(Uint8List rgba, int w, int h) {
  return _runOnWorker('relief', rgba, w, h, {});
}

// 霓虹描边：方向感知上色
Future<Uint8List> stylizeNeon(Uint8List rgba, int w, int h) {
  return _runOnWorker('neon', rgba, w, h, {});
}

// 发光描边（荧光）
Future<Uint8List> stylizeGlowEdge(Uint8List rgba, int w, int h) {
  return _runOnWorker('glow_edge', rgba, w, h, {});
}

// 点彩
Future<Uint8List> stylizePointillism(Uint8List rgba, int w, int h) {
  return _runOnWorker('pointillism', rgba, w, h, {});
}

// 马赛克彩绘（粗格）
Future<Uint8List> stylizeMosaicPaint(Uint8List rgba, int w, int h) {
  return _runOnWorker('mosaic_paint', rgba, w, h, {});
}

// 强海报化
Future<Uint8List> stylizePoster(Uint8List rgba, int w, int h) {
  return _runOnWorker('poster', rgba, w, h, {});
}

// 扁平色（赛璐璐）
Future<Uint8List> stylizeFlat(Uint8List rgba, int w, int h) {
  return _runOnWorker('flat', rgba, w, h, {});
}

// 波普
Future<Uint8List> stylizePopArt(Uint8List rgba, int w, int h) {
  return _runOnWorker('popart', rgba, w, h, {});
}

// 复古彩绘（棕调）
Future<Uint8List> stylizeSepiaPaint(Uint8List rgba, int w, int h) {
  return _runOnWorker('sepia_paint', rgba, w, h, {});
}

// 蜡笔
Future<Uint8List> stylizeCrayon(Uint8List rgba, int w, int h) {
  return _runOnWorker('crayon', rgba, w, h, {});
}

// ======================== 后台调度核心 ========================

// ✅ 修正后的 _runOnWorker（含 web/调试兜底）
Future<Uint8List> _runOnWorker(
    String op, Uint8List rgba, int w, int h, Map<String, dynamic> params,
    ) async {
  // web 或禁用后台时，走前台同步（避免 TransferableTypedData 不可用）
  if (kIsWeb || !_useBackgroundIsolate) {
    return _dispatchSync(op, Uint8List.fromList(rgba), w, h, params);
  }

  final job = <String, Object?>{
    'op': op,
    'w': w,
    'h': h,
    'params': params,
    'bytes': TransferableTypedData.fromList([rgba]), // 零拷贝
  };

  final TransferableTypedData res =
  await compute<Map<String, Object?>, TransferableTypedData>(
    _filterEntry, job,
  );

  final buf = res.materialize();      // ByteBuffer
  return buf.asUint8List();           // ↩️ 拿回 Uint8List
}

// ✅ 修正后的 compute 顶层入口（必须顶层/静态）
TransferableTypedData _filterEntry(Map<String, Object?> job) {
  final op = job['op'] as String;
  final w  = job['w']  as int;
  final h  = job['h']  as int;
  final params = (job['params'] as Map).cast<String, dynamic>();

  final Uint8List rgba =
  (job['bytes'] as TransferableTypedData).materialize().asUint8List();

  final out = _dispatchSync(op, rgba, w, h, params);
  return TransferableTypedData.fromList([out]);
}

// 后台实际执行：根据 op 分发到各同步实现
Uint8List _dispatchSync(
    String op, Uint8List rgba, int w, int h, Map<String, dynamic> p) {
  switch (op) {
    case 'cartoon':
      return _stylizeCartoonSync(rgba, w, h,
          blur: (p['blur'] ?? 1) as int,
          levels: (p['levels'] ?? 6) as int,
          edge: (p['edge'] ?? 0.28).toDouble());
    case 'cartoon_bold':
      return _stylizeCartoonBoldSync(rgba, w, h);
    case 'watercolor':
      return _stylizeWatercolorSync(rgba, w, h);
    case 'gouache':
      return _stylizeGouacheSync(rgba, w, h);
    case 'oil':
      return _stylizeOilSync(rgba, w, h);
    case 'pastel':
      return _stylizePastelSync(rgba, w, h);
    case 'sketch_color':
      return _stylizeSketchColorSync(rgba, w, h);
    case 'sketch_bw':
      return _stylizeSketchBWSync(rgba, w, h);
    case 'charcoal':
      return _stylizeCharcoalSync(rgba, w, h);
    case 'ink':
      return _stylizeInkSync(rgba, w, h);
    case 'sculpt':
      return _stylizeSculptSync(rgba, w, h);
    case 'relief':
      return _stylizeReliefSync(rgba, w, h);
    case 'neon':
      return _stylizeNeonSync(rgba, w, h);
    case 'glow_edge':
      return _stylizeGlowEdgeSync(rgba, w, h);
    case 'pointillism':
      return _stylizePointillismSync(rgba, w, h);
    case 'mosaic_paint':
      return _stylizeMosaicPaintSync(rgba, w, h);
    case 'poster':
      return _stylizePosterSync(rgba, w, h);
    case 'flat':
      return _stylizeFlatSync(rgba, w, h);
    case 'popart':
      return _stylizePopArtSync(rgba, w, h);
    case 'sepia_paint':
      return _stylizeSepiaPaintSync(rgba, w, h);
    case 'crayon':
      return _stylizeCrayonSync(rgba, w, h);
    default:
      return Uint8List.fromList(rgba);
  }
}

// ======================== 各风格的「同步」实现 ========================

Uint8List _stylizeCartoonSync(Uint8List rgba, int w, int h,
    {int blur = 1, int levels = 6, double edge = 0.28}) {
  final out = _clone(rgba);
  _guidedFilterRGB(out, w, h, r: math.max(2, blur * 2), eps: 1e-3);
  _kmeansQuantize(out, w, h, math.max(3, levels), sampleStep: 2, iters: 8);
  final edges =
  _xdogMask(rgba, w, h, sigma: 0.8, k: 1.6, eps: -0.015, phi: 10.0);
  _overlayEdgeDarken(out, w, h, edges, k: edge, thickness: 1);
  return out;
}

Uint8List _stylizeCartoonBoldSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _guidedFilterRGB(out, w, h, r: 4, eps: 1e-3);
  _kmeansQuantize(out, w, h, 5, sampleStep: 2, iters: 8);
  final edges = _xdogMask(rgba, w, h, sigma: 1.0, k: 1.6, eps: -0.02, phi: 12);
  _overlayEdgeDarken(out, w, h, edges, k: 0.22, thickness: 2);
  return out;
}

Uint8List _stylizeWatercolorSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _guidedFilterRGB(out, w, h, r: 4, eps: 1.5e-3);
  _saturation(out, w, h, 0.06);
  _temperature(out, w, h, 0.05);
  _grain(out, w, h, 0.03);
  final edges = _xdogMask(out, w, h, sigma: 0.9, k: 1.6, eps: -0.01, phi: 9.0);
  _overlayEdgeDarken(out, w, h, edges, k: 0.15, thickness: 1);
  return out;
}

Uint8List _stylizeGouacheSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _gaussApprox(out, w, h, sigma: 1.2, passes: 1);
  _kmeansQuantize(out, w, h, 7, sampleStep: 2, iters: 8);
  _contrast(out, w, h, 0.06);
  final edges = _xdogMask(out, w, h, sigma: 0.9, k: 1.6, eps: -0.015, phi: 10);
  _overlayEdgeDarken(out, w, h, edges, k: 0.10, thickness: 1);
  return out;
}

Uint8List _stylizeOilSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _oilWeighted(out, w, h,
      radius: 3, bins: 24, distWeight: 0.7, lumWeight: 0.3);
  _contrast(out, w, h, 0.08);
  return out;
}

Uint8List _stylizePastelSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _guidedFilterRGB(out, w, h, r: 3, eps: 1e-3);
  _saturation(out, w, h, -0.08);
  _brightness(out, w, h, 0.06);
  _curveSoft(out, w, h);
  final edges = _xdogMask(out, w, h, sigma: 0.8, k: 1.6, eps: -0.012, phi: 9);
  _overlayEdgeDarken(out, w, h, edges, k: 0.08, thickness: 1);
  return out;
}

Uint8List _stylizeSketchColorSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _kmeansQuantize(out, w, h, 8, sampleStep: 2, iters: 8);
  final edges =
  _xdogMask(rgba, w, h, sigma: 0.9, k: 1.6, eps: -0.012, phi: 11);
  _overlayEdgeDarken(out, w, h, edges, k: 0.85, thickness: 1);
  return out;
}

Uint8List _stylizeSketchBWSync(Uint8List rgba, int w, int h) {
  final gray = _toGray(_clone(rgba), w, h);
  final inv = _clone(gray);
  _invert(inv, w, h);
  final blur = _clone(inv);
  _gaussApprox(blur, w, h, sigma: 1.2, passes: 1);
  _colorDodge(gray, blur, w, h);
  _levels(gray, w, h, low: 0.12, high: 0.92);
  _paperTexture(gray, w, h, amt: 0.06);
  return gray;
}

Uint8List _stylizeCharcoalSync(Uint8List rgba, int w, int h) {
  final g = _toGray(_clone(rgba), w, h);
  final e = _xdogMask(rgba, w, h, sigma: 1.0, k: 1.6, eps: -0.02, phi: 12);
  _invert(g, w, h);
  _multiply(g, e, w, h, k: 1.2);
  _levels(g, w, h, low: 0.15, high: 0.85);
  return g;
}

Uint8List _stylizeInkSync(Uint8List rgba, int w, int h) {
  final base = _clone(rgba);
  _kmeansQuantize(base, w, h, 6, sampleStep: 2, iters: 8);
  final edges = _xdogMask(base, w, h, sigma: 1.0, k: 1.6, eps: -0.02, phi: 14);
  _overlayEdgeDarken(base, w, h, edges, k: 0.33, thickness: 2);
  _contrast(base, w, h, 0.10);
  return base;
}

Uint8List _stylizeSculptSync(Uint8List rgba, int w, int h) {
  final out = _emboss(_clone(rgba), w, h, 1);
  _toGrayInPlace(out, w, h);
  _contrast(out, w, h, 0.2);
  _brightness(out, w, h, 0.05);
  return out;
}

Uint8List _stylizeReliefSync(Uint8List rgba, int w, int h) {
  final out = _emboss(_clone(rgba), w, h, 2);
  _levels(out, w, h, low: 0.1, high: 0.95);
  return out;
}

Uint8List _stylizeNeonSync(Uint8List rgba, int w, int h) {
  final mag = Uint8List(w * h * 4);
  final ang = Float32List(w * h);
  _sobelMagAndDir(rgba, w, h, magOut: mag, angOut: ang);
  final out = _fill(w, h, 0, 0, 0);
  _neonDirColorize(out, w, h, mag, ang);
  return out;
}

Uint8List _stylizeGlowEdgeSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  final edges =
  _xdogMask(rgba, w, h, sigma: 0.9, k: 1.6, eps: -0.015, phi: 10.0);
  _glow(out, w, h, edges, radius: 2, strength: 0.85);
  _overlayEdgeDarken(out, w, h, edges, k: 0.18, thickness: 1);
  return out;
}

Uint8List _stylizePointillismSync(Uint8List rgba, int w, int h) {
  final out = _fill(w, h, 255, 255, 255);
  _stipplingToneAware(out, rgba, w, h, baseStep: 6, jitter: 0.5);
  return out;
}

Uint8List _stylizeMosaicPaintSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _gridPaintKMeans(out, w, h, cell: 10, jitter: 0.35, k: 3);
  final edges = _xdogMask(out, w, h, sigma: 0.9, k: 1.6, eps: -0.012, phi: 9);
  _overlayEdgeDarken(out, w, h, edges, k: 0.12, thickness: 1);
  return out;
}

Uint8List _stylizePosterSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _kmeansQuantize(out, w, h, 4, sampleStep: 2, iters: 8);
  _contrast(out, w, h, 0.18);
  return out;
}

Uint8List _stylizeFlatSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _guidedFilterRGB(out, w, h, r: 3, eps: 1e-3);
  _kmeansQuantize(out, w, h, 5, sampleStep: 2, iters: 8);
  final edges = _xdogMask(out, w, h, sigma: 0.8, k: 1.6, eps: -0.013, phi: 10);
  _overlayEdgeDarken(out, w, h, edges, k: 0.25, thickness: 1);
  return out;
}

Uint8List _stylizePopArtSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _kmeansQuantize(out, w, h, 5, sampleStep: 2, iters: 8);
  _hueRotate(out, w, h, 20);
  _saturation(out, w, h, 0.25);
  _contrast(out, w, h, 0.22);
  return out;
}

Uint8List _stylizeSepiaPaintSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _sepia(out, w, h, amt: 0.85);
  _guidedFilterRGB(out, w, h, r: 3, eps: 1.2e-3);
  final edges = _xdogMask(out, w, h, sigma: 0.9, k: 1.6, eps: -0.012, phi: 9);
  _overlayEdgeDarken(out, w, h, edges, k: 0.08, thickness: 1);
  return out;
}

Uint8List _stylizeCrayonSync(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _grain(out, w, h, 0.06);
  _guidedFilterRGB(out, w, h, r: 2, eps: 1e-3);
  _contrast(out, w, h, 0.05);
  final edges = _xdogMask(out, w, h, sigma: 0.8, k: 1.6, eps: -0.011, phi: 9.0);
  _overlayEdgeDarken(out, w, h, edges, k: 0.10, thickness: 1);
  return out;
}

// ======================== 基础工具（RGBA 0..255） ========================

Uint8List _clone(Uint8List src) => Uint8List.fromList(src);

Uint8List _fill(int w, int h, int r, int g, int b) {
  final out = Uint8List(w * h * 4);
  for (int i = 0; i < w * h; i++) {
    final o = i << 2;
    out[o] = r;
    out[o + 1] = g;
    out[o + 2] = b;
    out[o + 3] = 255;
  }
  return out;
}

void _toGrayInPlace(Uint8List rgba, int w, int h) {
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    final y =
    (0.2627 * rgba[o] + 0.678 * rgba[o + 1] + 0.0593 * rgba[o + 2]).round();
    rgba[o] = y;
    rgba[o + 1] = y;
    rgba[o + 2] = y;
  }
}

Uint8List _toGray(Uint8List rgba, int w, int h) {
  final out = _clone(rgba);
  _toGrayInPlace(out, w, h);
  return out;
}

void _invert(Uint8List rgba, int w, int h) {
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    rgba[o] = 255 - rgba[o];
    rgba[o + 1] = 255 - rgba[o + 1];
    rgba[o + 2] = 255 - rgba[o + 2];
  }
}

void _levels(Uint8List rgba, int w, int h,
    {double low = 0.0, double high = 1.0}) {
  final n = w * h;
  final lo = (low * 255).clamp(0, 255).toDouble();
  final hi = (high * 255).clamp(1, 255).toDouble();
  final k = 255.0 / (hi - lo + 1e-6);
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    for (int c = 0; c < 3; c++) {
      var v = rgba[o + c].toDouble();
      v = ((v - lo) * k).clamp(0.0, 255.0);
      rgba[o + c] = v.round();
    }
  }
}

void _brightness(Uint8List rgba, int w, int h, double br) {
  final add = (br * 255).round();
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    for (int c = 0; c < 3; c++) {
      rgba[o + c] = (rgba[o + c] + add).clamp(0, 255).toInt();
    }
  }
}

void _contrast(Uint8List rgba, int w, int h, double ct) {
  final k = 1 + ct * 1.4;
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    for (int c = 0; c < 3; c++) {
      final v = ((rgba[o + c] - 128) * k + 128).clamp(0.0, 255.0);
      rgba[o + c] = v.round();
    }
  }
}

void _saturation(Uint8List rgba, int w, int h, double sat) {
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    final r = rgba[o].toDouble(),
        g = rgba[o + 1].toDouble(),
        b = rgba[o + 2].toDouble();
    final y = 0.2627 * r + 0.678 * g + 0.0593 * b;
    rgba[o] = (r + (r - y) * sat).clamp(0.0, 255.0).round();
    rgba[o + 1] = (g + (g - y) * sat).clamp(0.0, 255.0).round();
    rgba[o + 2] = (b + (b - y) * sat).clamp(0.0, 255.0).round();
  }
}

void _temperature(Uint8List rgba, int w, int h, double t) {
  final n = w * h;
  final rGain = 1 + t, bGain = 1 - t;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    rgba[o] = (rgba[o] * rGain).clamp(0.0, 255.0).round();
    rgba[o + 2] = (rgba[o + 2] * bGain).clamp(0.0, 255.0).round();
  }
}

void _hueRotate(Uint8List rgba, int w, int h, double degrees) {
  final rad = degrees * math.pi / 180.0;
  final cosA = math.cos(rad), sinA = math.sin(rad);
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    double r = rgba[o] / 255.0,
        g = rgba[o + 1] / 255.0,
        b = rgba[o + 2] / 255.0;
    final y = 0.299 * r + 0.587 * g + 0.114 * b;
    double iC = 0.596 * r - 0.274 * g - 0.322 * b;
    double qC = 0.211 * r - 0.523 * g + 0.312 * b;
    final i2 = iC * cosA - qC * sinA;
    final q2 = iC * sinA + qC * cosA;
    r = (y + 0.956 * i2 + 0.621 * q2).clamp(0.0, 1.0);
    g = (y - 0.272 * i2 - 0.647 * q2).clamp(0.0, 1.0);
    b = (y - 1.105 * i2 + 1.702 * q2).clamp(0.0, 1.0);
    rgba[o] = (r * 255 + .5).floor();
    rgba[o + 1] = (g * 255 + .5).floor();
    rgba[o + 2] = (b * 255 + .5).floor();
  }
}

void _sepia(Uint8List rgba, int w, int h, {double amt = 1.0}) {
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    final r = rgba[o].toDouble(),
        g = rgba[o + 1].toDouble(),
        b = rgba[o + 2].toDouble();
    final rr = (0.393 * r + 0.769 * g + 0.189 * b);
    final gg = (0.349 * r + 0.686 * g + 0.168 * b);
    final bb = (0.272 * r + 0.534 * g + 0.131 * b);
    rgba[o] = (r + (rr - r) * amt).clamp(0.0, 255.0).round();
    rgba[o + 1] = (g + (gg - g) * amt).clamp(0.0, 255.0).round();
    rgba[o + 2] = (b + (bb - b) * amt).clamp(0.0, 255.0).round();
  }
}

// 颜色减淡（素描近似）
void _colorDodge(Uint8List base, Uint8List blur, int w, int h) {
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    for (int c = 0; c < 3; c++) {
      final b = blur[o + c];
      final a = base[o + c];
      final v = (a * 255.0) / (255 - b + 1.0);
      base[o + c] = v.clamp(0.0, 255.0).round();
    }
  }
}

void _multiply(Uint8List a, Uint8List b, int w, int h, {double k = 1.0}) {
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    for (int c = 0; c < 3; c++) {
      final v = (a[o + c] * b[o + c] / 255.0) * k;
      a[o + c] = v.clamp(0.0, 255.0).round();
    }
  }
}

// ================= 三盒逼近高斯 / Guided Filter =================

void _gaussApprox(Uint8List rgba, int w, int h,
    {double sigma = 1.0, int passes = 1}) {
  List<int> _boxesForGauss(double sigma, int n) {
    final wIdeal = math.sqrt((12 * sigma * sigma / n) + 1);
    int wl = wIdeal.floor();
    if (wl % 2 == 0) wl--;
    final wu = wl + 2;
    final m =
    ((12 * sigma * sigma - n * wl * wl - 4 * n * wl - 3 * n) / (-4 * wl - 4))
        .round();
    return List<int>.generate(n, (i) => i < m ? wl : wu);
  }

  final boxes = _boxesForGauss(sigma, 3);
  for (int p = 0; p < passes; p++) {
    for (final b in boxes) {
      _boxBlur(rgba, w, h, radius: (b - 1) ~/ 2, passes: 1);
    }
  }
}

// Guided Filter（灰度引导，作用到 RGB）
void _guidedFilterRGB(Uint8List rgba, int w, int h, {int r = 4, double eps = 1e-3}) {
  final n = w * h;
  final I = Float64List(n);
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    I[i] = (0.2627 * rgba[o] + 0.678 * rgba[o + 1] + 0.0593 * rgba[o + 2]) / 255.0;
  }

  void runChannel(int ch) {
    final P = Float64List(n);
    for (int i = 0; i < n; i++) P[i] = rgba[(i << 2) + ch] / 255.0;

    Float64List bf(Float64List arr) => _boxMeanDouble(arr, w, h, r);
    final meanI = bf(I);
    final meanP = bf(P);
    final corrI = bf(_mulDouble(I, I));
    final corrIP = bf(_mulDouble(I, P));

    final varI = Float64List(n);
    final covIP = Float64List(n);
    for (int i = 0; i < n; i++) {
      varI[i] = (corrI[i] - meanI[i] * meanI[i]).clamp(0.0, 1e9);
      covIP[i] = corrIP[i] - meanI[i] * meanP[i];
    }

    final a = Float64List(n);
    final b = Float64List(n);
    for (int i = 0; i < n; i++) {
      a[i] = covIP[i] / (varI[i] + eps);
      b[i] = meanP[i] - a[i] * meanI[i];
    }

    final meanA = bf(a);
    final meanB = bf(b);
    for (int i = 0; i < n; i++) {
      final q = (meanA[i] * I[i] + meanB[i]).clamp(0.0, 1.0);
      rgba[(i << 2) + ch] = (q * 255.0 + 0.5).floor();
    }
  }

  runChannel(0);
  runChannel(1);
  runChannel(2);
}

Float64List _boxMeanDouble(Float64List src, int w, int h, int r) {
  final tmp = Float64List(w * h);
  final out = Float64List(w * h);
  final invW = 1.0 / (2 * r + 1);

  // horizontal
  for (int y = 0; y < h; y++) {
    int idx = y * w;
    double s = 0;
    for (int x = -r; x <= r; x++) s += src[(y * w + _clampIndex(x, w))];
    for (int x = 0; x < w; x++) {
      tmp[idx + x] = s * invW;
      final add = src[y * w + _clampIndex(x + r + 1, w)];
      final sub = src[y * w + _clampIndex(x - r, w)];
      s += add - sub;
    }
  }
  // vertical
  final invH = 1.0 / (2 * r + 1);
  for (int x = 0; x < w; x++) {
    double s = 0;
    for (int y = -r; y <= r; y++) s += tmp[_clampIndex(y, h) * w + x];
    for (int y = 0; y < h; y++) {
      out[y * w + x] = s * invH;
      final add = tmp[_clampIndex(y + r + 1, h) * w + x];
      final sub = tmp[_clampIndex(y - r, h) * w + x];
      s += add - sub;
    }
  }
  return out;
}

Float64List _mulDouble(Float64List a, Float64List b) {
  final n = a.length;
  final out = Float64List(n);
  for (int i = 0; i < n; i++) out[i] = a[i] * b[i];
  return out;
}

// ================= XDoG 墨线 & Sobel 方向 =================

Uint8List _xdogMask(Uint8List rgba, int w, int h,
    {double sigma = 0.9, double k = 1.6, double eps = -0.015, double phi = 10.0}) {
  final g = _toGray(rgba, w, h);
  final G1 = _clone(g);
  _gaussApprox(G1, w, h, sigma: sigma, passes: 1);
  final G2 = _clone(g);
  _gaussApprox(G2, w, h, sigma: sigma * k, passes: 1);

  final out = Uint8List(w * h * 4);
  for (int i = 0; i < w * h; i++) {
    final o = i << 2;
    final d = (G1[o] - G2[o]).toDouble() / 255.0;
    double e = d >= eps ? 1.0 : (1.0 + _tanh(phi * (d - eps))) * 0.5;
    e = (1.0 - e);
    final v = (e * 255.0).clamp(0.0, 255.0).round();
    out[o] = out[o + 1] = out[o + 2] = v;
    out[o + 3] = 255;
  }
  return out;
}

double _tanh(double x) {
  final e2x = math.exp(2 * x);
  return (e2x - 1) / (e2x + 1);
}

void _sobelMagAndDir(Uint8List rgba, int w, int h,
    {required Uint8List magOut, required Float32List angOut}) {
  final gray = _toGray(rgba, w, h);
  int idx(int x, int y) => ((y * w + x) << 2);
  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final gx = -gray[idx(x - 1, y - 1)] -
          2 * gray[idx(x - 1, y)] -
          gray[idx(x - 1, y + 1)] +
          gray[idx(x + 1, y - 1)] +
          2 * gray[idx(x + 1, y)] +
          gray[idx(x + 1, y + 1)];
      final gy = -gray[idx(x - 1, y - 1)] -
          2 * gray[idx(x, y - 1)] -
          gray[idx(x + 1, y - 1)] +
          gray[idx(x - 1, y + 1)] +
          2 * gray[idx(x, y + 1)] +
          gray[idx(x + 1, y + 1)];
      final m = (math.sqrt((gx * gx + gy * gy).toDouble()) / 4)
          .clamp(0.0, 255.0)
          .round();
      final o = idx(x, y);
      magOut[o] = magOut[o + 1] = magOut[o + 2] = m;
      magOut[o + 3] = 255;
      angOut[y * w + x] = math.atan2(gy.toDouble(), gx.toDouble());
    }
  }
}

Uint8List _sobel(Uint8List rgba, int w, int h) {
  final out = Uint8List(w * h * 4);
  final gray = _toGray(rgba, w, h);
  int idx(int x, int y) => ((y * w + x) << 2);

  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final gx = -gray[idx(x - 1, y - 1)] -
          2 * gray[idx(x - 1, y)] -
          gray[idx(x - 1, y + 1)] +
          gray[idx(x + 1, y - 1)] +
          2 * gray[idx(x + 1, y)] +
          gray[idx(x + 1, y + 1)];
      final gy = -gray[idx(x - 1, y - 1)] -
          2 * gray[idx(x, y - 1)] -
          gray[idx(x + 1, y - 1)] +
          gray[idx(x - 1, y + 1)] +
          2 * gray[idx(x, y + 1)] +
          gray[idx(x + 1, y + 1)];
      final m = (math.sqrt((gx * gx + gy * gy).toDouble()) / 4)
          .clamp(0.0, 255.0)
          .round();
      final o = idx(x, y);
      out[o] = out[o + 1] = out[o + 2] = m;
      out[o + 3] = 255;
    }
  }
  return out;
}

void _overlayEdgeDarken(Uint8List rgba, int w, int h, Uint8List edgeGray,
    {double k = 0.3, int thickness = 1}) {
  final e = Uint8List.fromList(edgeGray);
  if (thickness > 1) _boxBlur(e, w, h, radius: 1);
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    final m = e[o] / 255.0;
    final t = (m * k).clamp(0.0, 1.0);
    for (int c = 0; c < 3; c++) {
      rgba[o + c] = (rgba[o + c] * (1 - t)).round();
    }
  }
}

// ================= 模糊与盒核 =================

void _boxBlur(Uint8List rgba, int w, int h, {int radius = 1, int passes = 1}) {
  if (radius <= 0) return;
  for (int p = 0; p < passes; p++) {
    _blur1D(rgba, w, h, radius, horizontal: true);
    _blur1D(rgba, w, h, radius, horizontal: false);
  }
}

void _blur1D(Uint8List rgba, int w, int h, int r, {required bool horizontal}) {
  final out = Uint8List.fromList(rgba);
  final len = horizontal ? w : h;
  final lines = horizontal ? h : w;
  final step = horizontal ? 4 : w * 4;
  final jump = horizontal ? w * 4 : 4;
  final wnd = r * 2 + 1;

  for (int L = 0; L < lines; L++) {
    int base = horizontal ? L * w * 4 : L * 4;
    int sr = 0, sg = 0, sb = 0;
    for (int i = -r; i <= r; i++) {
      final idx = _clampIndex(i, len) * step + base;
      sr += rgba[idx];
      sg += rgba[idx + 1];
      sb += rgba[idx + 2];
    }
    for (int x = 0; x < len; x++) {
      final o = base + x * step;
      out[o] = (sr / wnd).round();
      out[o + 1] = (sg / wnd).round();
      out[o + 2] = (sb / wnd).round();
      final xAdd = _clampIndex(x + r + 1, len) * step + base;
      final xSub = _clampIndex(x - r, len) * step + base;
      sr += rgba[xAdd] - rgba[xSub];
      sg += rgba[xAdd + 1] - rgba[xSub + 1];
      sb += rgba[xAdd + 2] - rgba[xSub + 2];
    }
  }
  rgba.setAll(0, out);
}

int _clampIndex(int x, int len) {
  if (x < 0) return 0;
  if (x >= len) return len - 1;
  return x;
}

// ================= 油画（加权众数） =================

void _oilWeighted(Uint8List rgba, int w, int h,
    {int radius = 3,
      int bins = 32,
      double distWeight = 0.7,
      double lumWeight = 0.3}) {
  final out = Uint8List.fromList(rgba);
  final histR = List<double>.filled(bins, 0);
  final histG = List<double>.filled(bins, 0);
  final histB = List<double>.filled(bins, 0);

  final lum = Float32List(w * h);
  for (int i = 0; i < w * h; i++) {
    final o = i << 2;
    lum[i] = (0.2627 * rgba[o] + 0.678 * rgba[o + 1] + 0.0593 * rgba[o + 2])
        .toDouble();
  }

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      for (int i = 0; i < bins; i++) {
        histR[i] = 0;
        histG[i] = 0;
        histB[i] = 0;
      }

      for (int yy = -radius; yy <= radius; yy++) {
        final sy = (y + yy).clamp(0, h - 1) as int;
        for (int xx = -radius; xx <= radius; xx++) {
          final sx = (x + xx).clamp(0, w - 1) as int;
          final o = (sy * w + sx) << 2;

          final rBin = (rgba[o] * bins) >> 8;
          final gBin = (rgba[o + 1] * bins) >> 8;
          final bBin = (rgba[o + 2] * bins) >> 8;

          final d2 = (xx * xx + yy * yy).toDouble();
          final dw = 1.0 / (1.0 + d2);
          final lw = 1.0 + (lum[sy * w + sx] / 255.0);
          final wgt = distWeight * dw + lumWeight * lw;

          histR[rBin] += wgt;
          histG[gBin] += wgt;
          histB[bBin] += wgt;
        }
      }

      int argMax(List<double> h) {
        int idx = 0;
        double best = -1e9;
        for (int i = 0; i < h.length; i++) {
          if (h[i] > best) {
            best = h[i];
            idx = i;
          }
        }
        return idx;
      }

      final o2 = (y * w + x) << 2;
      final ir = argMax(histR), ig = argMax(histG), ib = argMax(histB);
      out[o2] = ((ir + 0.5) * 255 / bins).round();
      out[o2 + 1] = ((ig + 0.5) * 255 / bins).round();
      out[o2 + 2] = ((ib + 0.5) * 255 / bins).round();
    }
  }
  rgba.setAll(0, out);
}

// ================= 量化（KMeans） =================

void _kmeansQuantize(Uint8List rgba, int w, int h, int k,
    {int sampleStep = 2, int iters = 8}) {
  k = k.clamp(2, 16);
  final samples = <List<double>>[];
  for (int y = 0; y < h; y += sampleStep) {
    for (int x = 0; x < w; x += sampleStep) {
      final o = ((y * w + x) << 2);
      samples.add([
        rgba[o].toDouble(),
        rgba[o + 1].toDouble(),
        rgba[o + 2].toDouble()
      ]);
    }
  }
  final rnd = math.Random(42);
  final centers =
  List.generate(k, (_) => samples[rnd.nextInt(samples.length)].toList());

  for (int it = 0; it < iters; it++) {
    final sums = List.generate(k, (_) => [0.0, 0.0, 0.0]);
    final cnts = List<int>.filled(k, 0);
    for (final s in samples) {
      int best = 0;
      double bestD = 1e18;
      for (int i = 0; i < k; i++) {
        final c = centers[i];
        final dx = s[0] - c[0], dy = s[1] - c[1], dz = s[2] - c[2];
        final d = dx * dx + dy * dy + dz * dz;
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      sums[best][0] += s[0];
      sums[best][1] += s[1];
      sums[best][2] += s[2];
      cnts[best] += 1;
    }
    for (int i = 0; i < k; i++) {
      if (cnts[i] > 0) {
        centers[i][0] = sums[i][0] / cnts[i];
        centers[i][1] = sums[i][1] / cnts[i];
        centers[i][2] = sums[i][2] / cnts[i];
      }
    }
  }

  for (int i = 0; i < w * h; i++) {
    final o = i << 2;
    int best = 0;
    double bestD = 1e18;
    for (int c = 0; c < k; c++) {
      final cc = centers[c];
      final dx = rgba[o] - cc[0],
          dy = rgba[o + 1] - cc[1],
          dz = rgba[o + 2] - cc[2];
      final d = dx * dx + dy * dy + dz * dz;
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    rgba[o] = centers[best][0].round();
    rgba[o + 1] = centers[best][1].round();
    rgba[o + 2] = centers[best][2].round();
  }
}

// ================= 霓虹/Glow/点彩/网格绘制 =================

void _neonDirColorize(
    Uint8List out, int w, int h, Uint8List mag, Float32List ang) {
  for (int i = 0; i < w * h; i++) {
    final m = mag[i << 2] / 255.0;
    final a = (ang[i] + math.pi) / (2 * math.pi);
    final s = 0.9, v = (m * 1.0).clamp(0.0, 1.0);
    final rgb = _hsv2rgb(a, s, v);
    final o = i << 2;
    out[o] = (rgb[0] * 255 + 0.5).floor();
    out[o + 1] = (rgb[1] * 255 + 0.5).floor();
    out[o + 2] = (rgb[2] * 255 + 0.5).floor();
    out[o + 3] = 255;
  }
}

List<double> _hsv2rgb(double h, double s, double v) {
  final i = (h * 6).floor() % 6;
  final f = h * 6 - i;
  final p = v * (1 - s);
  final q = v * (1 - f * s);
  final t = v * (1 - (1 - f) * s);
  switch (i) {
    case 0:
      return [v, t, p];
    case 1:
      return [q, v, p];
    case 2:
      return [p, v, t];
    case 3:
      return [p, q, v];
    case 4:
      return [t, p, v];
    default:
      return [v, p, q];
  }
}

void _glow(Uint8List base, int w, int h, Uint8List edges,
    {int radius = 2, double strength = 0.8}) {
  final glow = Uint8List.fromList(edges);
  _gaussApprox(glow, w, h, sigma: math.max(1.0, radius.toDouble()), passes: 1);
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    for (int c = 0; c < 3; c++) {
      final v = (base[o + c] + glow[o] * strength).clamp(0.0, 255.0);
      base[o + c] = v.round();
    }
  }
}

void _grain(Uint8List rgba, int w, int h, double amt) {
  final rnd = math.Random(1);
  final n = w * h;
  final k = (amt * 255).round();
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    final n0 = rnd.nextInt(k * 2 + 1) - k;
    for (int c = 0; c < 3; c++) {
      rgba[o + c] = (rgba[o + c] + n0).clamp(0, 255).toInt();
    }
  }
}

void _stipplingToneAware(Uint8List out, Uint8List src, int w, int h,
    {int baseStep = 6, double jitter = 0.5}) {
  final rnd = math.Random(2);
  for (int y = 0; y < h; y += baseStep) {
    for (int x = 0; x < w; x += baseStep) {
      int r = 0, g = 0, b = 0, c = 0;
      int lsum = 0;
      for (int yy = 0; yy < baseStep && y + yy < h; yy++) {
        for (int xx = 0; xx < baseStep && x + xx < w; xx++) {
          final o = ((y + yy) * w + (x + xx)) << 2;
          r += src[o];
          g += src[o + 1];
          b += src[o + 2];
          c++;
          lsum +=
              (0.2627 * src[o] + 0.678 * src[o + 1] + 0.0593 * src[o + 2])
                  .round();
        }
      }
      if (c == 0) continue;
      r ~/= c;
      g ~/= c;
      b ~/= c;
      final lum = lsum / c / 255.0;
      final cx = x +
          (baseStep / 2 + (rnd.nextDouble() - .5) * baseStep * jitter).round();
      final cy = y +
          (baseStep / 2 + (rnd.nextDouble() - .5) * baseStep * jitter).round();
      final rad = (baseStep * (0.4 + (1.0 - lum) * 0.6)).round();
      for (int yy = -rad; yy <= rad; yy++) {
        final sy = (cy + yy);
        if (sy < 0 || sy >= h) continue;
        for (int xx = -rad; xx <= rad; xx++) {
          final sx = (cx + xx);
          if (sx < 0 || sx >= w) continue;
          if (xx * xx + yy * yy <= rad * rad) {
            final o = (sy * w + sx) << 2;
            out[o] = r;
            out[o + 1] = g;
            out[o + 2] = b;
            out[o + 3] = 255;
          }
        }
      }
    }
  }
}

void _gridPaintKMeans(Uint8List rgba, int w, int h,
    {int cell = 10, double jitter = 0.3, int k = 3}) {
  final src = Uint8List.fromList(rgba);
  final rnd = math.Random(3);
  for (int y = 0; y < h; y += cell) {
    for (int x = 0; x < w; x += cell) {
      final x2 =
      (x + cell + (rnd.nextDouble() - .5) * cell * jitter).clamp(0, w).round();
      final y2 =
      (y + cell + (rnd.nextDouble() - .5) * cell * jitter).clamp(0, h).round();

      final pts = <List<double>>[];
      for (int yy = y; yy < y2; yy++) {
        for (int xx = x; xx < x2; xx++) {
          final o = (yy * w + xx) << 2;
          pts.add(
              [src[o].toDouble(), src[o + 1].toDouble(), src[o + 2].toDouble()]);
        }
      }
      if (pts.isEmpty) continue;

      final centers = <List<double>>[];
      for (int i = 0; i < k; i++) {
        centers.add(pts[rnd.nextInt(pts.length)].toList());
      }
      for (int it = 0; it < 4; it++) {
        final sums = List.generate(k, (_) => [0.0, 0.0, 0.0]);
        final cnts = List<int>.filled(k, 0);
        for (final p in pts) {
          int bi = 0;
          double bd = 1e18;
          for (int ci = 0; ci < k; ci++) {
            final c0 = centers[ci];
            final dx = p[0] - c0[0], dy = p[1] - c0[1], dz = p[2] - c0[2];
            final dd = dx * dx + dy * dy + dz * dz;
            if (dd < bd) {
              bd = dd;
              bi = ci;
            }
          }
          sums[bi][0] += p[0];
          sums[bi][1] += p[1];
          sums[bi][2] += p[2];
          cnts[bi] += 1;
        }
        for (int ci = 0; ci < k; ci++) {
          if (cnts[ci] > 0) {
            centers[ci][0] = sums[ci][0] / cnts[ci];
            centers[ci][1] = sums[ci][1] / cnts[ci];
            centers[ci][2] = sums[ci][2] / cnts[ci];
          }
        }
      }

      for (int yy = y; yy < y2; yy++) {
        for (int xx = x; xx < x2; xx++) {
          final o = (yy * w + xx) << 2;
          int bi = 0;
          double bd = 1e18;
          for (int ci = 0; ci < k; ci++) {
            final c0 = centers[ci];
            final dx = src[o] - c0[0],
                dy = src[o + 1] - c0[1],
                dz = src[o + 2] - c0[2];
            final dd = dx * dx + dy * dy + dz * dz;
            if (dd < bd) {
              bd = dd;
              bi = ci;
            }
          }
          rgba[o] = centers[bi][0].round();
          rgba[o + 1] = centers[bi][1].round();
          rgba[o + 2] = centers[bi][2].round();
        }
      }
    }
  }
}

// ================= 海报化/浮雕/曲线 =================

void _posterize(Uint8List rgba, int w, int h, int levels) {
  final n = w * h;
  final step = (255 / (levels - 1)).clamp(1, 255);
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    for (int c = 0; c < 3; c++) {
      final v = ((rgba[o + c] / step).round() * step).clamp(0, 255).round();
      rgba[o + c] = v;
    }
  }
}

Uint8List _emboss(Uint8List rgba, int w, int h, int power) {
  final out = _clone(rgba);
  for (int y = 1; y < h; y++) {
    for (int x = 1; x < w; x++) {
      final o = (y * w + x) << 2;
      final o2 = ((y - 1) * w + (x - 1)) << 2;
      for (int c = 0; c < 3; c++) {
        final v = (rgba[o + c] - rgba[o2 + c]) * power + 128;
        out[o + c] = v.clamp(0, 255).toInt();
      }
    }
  }
  return out;
}

void _curveSoft(Uint8List rgba, int w, int h) {
  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    for (int c = 0; c < 3; c++) {
      final x = rgba[o + c] / 255.0;
      final y = 1.0 / (1.0 + math.exp(-(x - .5) * 6.0));
      rgba[o + c] = (y * 255 + .5).floor();
    }
  }
}

// ================= 纸纹合成（素描用） =================

void _paperTexture(Uint8List rgba, int w, int h, {double amt = 0.05}) {
  int hash(int x, int y) {
    int n = x + y * 57;
    n = (n << 13) ^ n;
    final d = 1.0 -
        (((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) /
            1073741824.0);
    return (d.abs() * 255.0).round();
  }

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final v = (0.6 * hash(x, y) + 0.4 * hash(x + 4, y + 1)).round();
      final o = (y * w + x) << 2;
      for (int c = 0; c < 3; c++) {
        final t = (rgba[o + c] * (1.0 - amt) + v * amt).clamp(0.0, 255.0);
        rgba[o + c] = t.round();
      }
    }
  }
}
