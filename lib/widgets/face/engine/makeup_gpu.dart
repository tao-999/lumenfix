// 📄 lib/widgets/face/engine/makeup_gpu.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'gpu_utils.dart';
import '../panels/panel_common.dart';
import 'face_regions.dart';

/// 💄 唇妆（仅唇区 softLight 叠色）
/// 流程：TFLite 分割 -> （上/下唇保留，牙齿/口腔剔除）-> 与外/内唇几何做布尔约束 -> 轻量形态学收尾 -> 着色
class FaceGpuMakeupEngine {
  const FaceGpuMakeupEngine();

  static const String _kModelAsset = 'assets/models/lips_parsing_256.tflite';

  // 19 类常见映射（与你导出的模型保持一致；不一致就改这里）
  static const int _ID_MOUTH     = 10; // 口腔开口
  static const int _ID_UPPERLIP  = 11; // 上唇
  static const int _ID_TEETH     = 12; // 牙齿
  static const int _ID_LOWERLIP  = 13; // 下唇

  static tfl.Interpreter? _interp;
  static List<int>? _inShape;   // [1,H,W,3]
  static List<int>? _outShape;  // [1,h,w,C]

  Future<Uint8List> process(
      Uint8List inBytes,
      FaceParams p,
      FaceRegions r,
      ) async {
    if (p.lipAlpha <= 0.0) return inBytes;

    // 解码原图
    final src = await decodeImageCompat(inBytes);
    final size = ui.Size(src.width.toDouble(), src.height.toDouble());
    final rect = ui.Offset.zero & size;

    // —— 构建唇掩膜 —— //
    final _Mask m = await _buildLipsMask(inBytes, src, r);

    if (m.image == null) {
      // 回退：仅几何 ring（精度略差）
      final ui.Path? outer = r.lipsOuterPath ?? r.lipsPath;
      if (outer == null) return inBytes;
      final ui.Path ring = (r.lipsInnerPath == null)
          ? outer
          : ui.Path.combine(ui.PathOperation.difference, outer, r.lipsInnerPath!);

      final ui.Color lipColor = p.lipColor.withOpacity(p.lipAlpha.clamp(0, .5));

      return drawGpu(src, (c, _) {
        // 底图
        c.saveLayer(rect, ui.Paint());
        drawFullImage(c, src, size);
        // softLight 着色（裁剪在 ring 内）
        c.saveLayer(rect, ui.Paint()..blendMode = ui.BlendMode.softLight);
        c.save();
        c.clipPath(ring, doAntiAlias: true);
        c.drawRect(rect, ui.Paint()..color = lipColor);
        c.restore();
        c.restore();
        c.restore();
      });
    }

    // —— 只在唇区 softLight 叠色 —— //
    final ui.Image lipsMask = m.image!;
    final ui.Color lipColor = p.lipColor.withOpacity(p.lipAlpha.clamp(0, 0.5));

    return drawGpu(src, (c, _) {
      // [A] 底图
      c.saveLayer(rect, ui.Paint());
      drawFullImage(c, src, size);

      // [B] softLight 层：先画纯色，再用掩膜 dstIn 限制
      c.saveLayer(rect, ui.Paint()..blendMode = ui.BlendMode.softLight);
      c.saveLayer(rect, ui.Paint()); // 临时层
      c.drawRect(rect, ui.Paint()..color = lipColor);

      final srcRect = ui.Rect.fromLTWH(
        0, 0, lipsMask.width.toDouble(), lipsMask.height.toDouble(),
      );
      c.drawImageRect(
        lipsMask,
        srcRect,
        rect,
        ui.Paint()
          ..filterQuality = ui.FilterQuality.medium
          ..blendMode = ui.BlendMode.dstIn, // 仅保留掩膜区域
      );
      c.restore();   // 临时层 → [B]
      c.restore();   // [B] 与 [A] softLight 合成
      c.restore();   // 合到画布
    });
  }

  // ================= 掩膜构建 =================

  Future<_Mask> _buildLipsMask(Uint8List srcBytes, ui.Image decoded, FaceRegions r) async {
    // 0) 若 FaceRegions 已带 lipsSegMask（字节 + 尺寸），直接用
    try {
      final dyn = r as dynamic;
      final Uint8List? mb = dyn.lipsSegMask as Uint8List?;
      final int? mw = dyn.lipsW as int?;
      final int? mh = dyn.lipsH as int?;
      if (mb != null && mw != null && mh != null) {
        final refined = await _refineWithGeometry(mb, mw, mh, r, decoded.width, decoded.height);
        final img = await _alphaMaskToImage(refined, decoded.width, decoded.height);
        return _Mask(img);
      }
    } catch (_) {}

    // 1) 本地 TFLite：双前处理（0..1 & ImageNet），自动选更可靠的
    final _RawMask raw = await _runLipsSegAuto(srcBytes, decoded);

    // 2) 与几何外/内环做布尔（outer ∧ seg) \ inner
    final Uint8List refined = await _refineWithGeometry(
      raw.alpha, raw.w, raw.h, r, decoded.width, decoded.height,
    );

    // 3) 轻量形态学（闭后开）
    final Uint8List fixed = _morphCloseOpen(refined, decoded.width, decoded.height);

    final ui.Image img = await _alphaMaskToImage(fixed, decoded.width, decoded.height);
    return _Mask(img);
  }

  /// 同一张图跑两套前处理，自动挑选唇像素比例合理且更大的那份
  Future<_RawMask> _runLipsSegAuto(Uint8List srcBytes, ui.Image decoded) async {
    // init interpreter
    if (_interp == null) {
      _interp = await tfl.Interpreter.fromAsset(_kModelAsset);
      _inShape  = _interp!.getInputTensor(0).shape;   // [1,H,W,3]
      _outShape = _interp!.getOutputTensor(0).shape;  // [1,h,w,C]
    }
    final interp = _interp!;
    final inH = _inShape![1], inW = _inShape![2];
    final outH = _outShape![1], outW = _outShape![2], outC = _outShape![3];

    // 缩放到输入
    final scaled = await _scaleImage(decoded, inW, inH);
    final bd = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = bd!.buffer.asUint8List();
    scaled.dispose();

    // 构建两套输入
    List makeInput01() {
      return List.generate(
        1,
            (_) => List.generate(
          inH,
              (y) => List.generate(
            inW,
                (x) {
              final i = (y * inW + x) * 4;
              return [rgba[i] / 255.0, rgba[i + 1] / 255.0, rgba[i + 2] / 255.0];
            },
            growable: false,
          ),
          growable: false,
        ),
        growable: false,
      );
    }

    List makeInputIM() {
      const mean = [0.485, 0.456, 0.406];
      const std  = [0.229, 0.224, 0.225];
      return List.generate(
        1,
            (_) => List.generate(
          inH,
              (y) => List.generate(
            inW,
                (x) {
              final i = (y * inW + x) * 4;
              final r = rgba[i] / 255.0;
              final g = rgba[i + 1] / 255.0;
              final b = rgba[i + 2] / 255.0;
              return [(r - mean[0]) / std[0], (g - mean[1]) / std[1], (b - mean[2]) / std[2]];
            },
            growable: false,
          ),
          growable: false,
        ),
        growable: false,
      );
    }

    _RawMask infer(List input) {
      final output = List.generate(
        1,
            (_) => List.generate(
          outH,
              (_) => List.generate(outW, (_) => List.filled(outC, 0.0), growable: false),
          growable: false,
        ),
        growable: false,
      );

      interp.run(input, output);

      final mask = Uint8List(outW * outH);
      int lipCount = 0;
      for (int y = 0; y < outH; y++) {
        for (int x = 0; x < outW; x++) {
          int arg = 0;
          double best = (output[0][y][x][0] as num).toDouble();
          for (int k = 1; k < outC; k++) {
            final v = (output[0][y][x][k] as num).toDouble();
            if (v > best) { best = v; arg = k; }
          }
          final bool isLip = (arg == _ID_UPPERLIP) || (arg == _ID_LOWERLIP);
          final bool isBan = (arg == _ID_TEETH) || (arg == _ID_MOUTH);
          final on = isLip && !isBan;
          mask[y * outW + x] = on ? 255 : 0;
          if (on) lipCount++;
        }
      }
      return _RawMask(alpha: mask, w: outW, h: outH, lipCount: lipCount);
    }

    final _RawMask A = infer(makeInput01());
    final _RawMask B = infer(makeInputIM());

    final double ratioA = A.lipCount / (outW * outH);
    final double ratioB = B.lipCount / (outW * outH);
    final bool okA = ratioA > 0.001 && ratioA < 0.08; // 经验范围：0.1%~8%
    final bool okB = ratioB > 0.001 && ratioB < 0.08;

    final _RawMask chosen = (okA && okB)
        ? (ratioA >= ratioB ? A : B)
        : (okA ? A : (okB ? B : (A.lipCount >= B.lipCount ? A : B)));

    return chosen;
  }

  /// finalMask = (SegMask ∧ OuterPathMask) \ InnerPathMask，然后放大到原图尺寸
  Future<Uint8List> _refineWithGeometry(
      Uint8List seg, int sw, int sh,
      FaceRegions r, int imgW, int imgH,
      ) async {
    final ui.Path? outer = r.lipsOuterPath ?? r.lipsPath;
    final ui.Path? inner = r.lipsInnerPath;

    Uint8List mask = seg;

    if (outer != null) {
      final Uint8List outerMask = await _rasterizePathMask(
        outer, sw, sh, ui.Size(imgW.toDouble(), imgH.toDouble()),
      );
      for (int i = 0; i < mask.length; i++) {
        mask[i] = (mask[i] != 0 && outerMask[i] != 0) ? 255 : 0;
      }
    }
    if (inner != null) {
      final Uint8List innerMask = await _rasterizePathMask(
        inner, sw, sh, ui.Size(imgW.toDouble(), imgH.toDouble()),
      );
      for (int i = 0; i < mask.length; i++) {
        if (innerMask[i] != 0) mask[i] = 0;
      }
    }

    // 双线性放大到原图
    return _resizeMask(mask, sw, sh, imgW, imgH);
  }

  // 3x3：先闭再开，抹掉小孔洞和毛刺
  Uint8List _morphCloseOpen(Uint8List m, int w, int h) {
    Uint8List dilate(Uint8List a) {
      final out = Uint8List(a.length);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          int on = 0;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              final nx = x + dx, ny = y + dy;
              if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                if (a[ny * w + nx] != 0) { on = 1; break; }
              }
            }
            if (on != 0) break;
          }
          out[y * w + x] = on != 0 ? 255 : 0;
        }
      }
      return out;
    }

    Uint8List erode(Uint8List a) {
      final out = Uint8List(a.length);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          int on = 1;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              final nx = x + dx, ny = y + dy;
              if (nx < 0 || nx >= w || ny < 0 || ny >= h || a[ny * w + nx] == 0) {
                on = 0; break;
              }
            }
            if (on == 0) break;
          }
          out[y * w + x] = on != 0 ? 255 : 0;
        }
      }
      return out;
    }

    final d = dilate(m);
    final c = erode(d); // close
    final e = erode(c);
    final o = dilate(e); // open
    return o;
  }

  // ===== 工具 =====

  Future<ui.Image> _alphaMaskToImage(Uint8List alpha, int w, int h) async {
    final rgba = Uint8List(w * h * 4);
    for (int i = 0, j = 0; i < alpha.length; i++, j += 4) {
      rgba[j] = 0; rgba[j + 1] = 0; rgba[j + 2] = 0; rgba[j + 3] = alpha[i];
    }
    final buf = await ui.ImmutableBuffer.fromUint8List(rgba);
    final desc = ui.ImageDescriptor.raw(
      buf, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await desc.instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<ui.Image> _scaleImage(ui.Image src, int tw, int th) async {
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    return rec.endRecording().toImage(tw, th);
  }

  /// 将 Path 光栅为 seg 尺寸 alpha 掩膜
  Future<Uint8List> _rasterizePathMask(
      ui.Path path, int mw, int mh, ui.Size imgSize,
      ) async {
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    final sx = mw / imgSize.width;
    final sy = mh / imgSize.height;
    c.scale(sx, sy);
    c.drawPath(
      path,
      ui.Paint()
        ..style = ui.PaintingStyle.fill
        ..color = const ui.Color(0xFFFFFFFF)
        ..isAntiAlias = true,
    );
    final img = await rec.endRecording().toImage(mw, mh);
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = bd!.buffer.asUint8List();
    final out = Uint8List(mw * mh);
    for (int i = 0, j = 0; i < out.length; i++, j += 4) {
      out[i] = rgba[j + 3]; // 取 A
    }
    img.dispose();
    return out;
  }

  Uint8List _resizeMask(Uint8List m, int w, int h, int W, int H) {
    final out = Uint8List(W * H);
    for (int y = 0; y < H; y++) {
      final fy = (y + 0.5) * h / H - 0.5;
      final y0 = fy.floor().clamp(0, h - 1);
      final y1 = (y0 + 1).clamp(0, h - 1);
      final wy = fy - y0;
      for (int x = 0; x < W; x++) {
        final fx = (x + 0.5) * w / W - 0.5;
        final x0 = fx.floor().clamp(0, w - 1);
        final x1 = (x0 + 1).clamp(0, w - 1);
        final wx = fx - x0;

        final a00 = m[y0 * w + x0].toDouble();
        final a01 = m[y0 * w + x1].toDouble();
        final a10 = m[y1 * w + x0].toDouble();
        final a11 = m[y1 * w + x1].toDouble();

        final top = a00 * (1 - wx) + a01 * wx;
        final bot = a10 * (1 - wx) + a11 * wx;
        final v = top * (1 - wy) + bot * wy;

        out[y * W + x] = v >= 128 ? 255 : 0;
      }
    }
    return out;
  }
}

// ===== 小结构 =====
class _RawMask {
  _RawMask({required this.alpha, required this.w, required this.h, required this.lipCount});
  final Uint8List alpha;
  final int w, h;
  final int lipCount;
}

class _Mask {
  _Mask(this.image);
  final ui.Image? image;
}
