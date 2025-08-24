import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../mosaic_types.dart';

class EffectArgs {
  final Uint8List srcBytes;
  final MosaicBrushType brush;
  final int strength;
  final int previewMaxSide; // ✅ 预览最大边长（降采样）
  const EffectArgs({
    required this.srcBytes,
    required this.brush,
    required this.strength,
    required this.previewMaxSide,
  });
}

class ApplyArgs {
  final Uint8List srcBytes;
  final Uint8List? effectBytes;
  final MosaicBrushType brush;
  final int strength;
  final Uint8List maskRgba;
  const ApplyArgs({
    required this.srcBytes,
    required this.effectBytes,
    required this.brush,
    required this.strength,
    required this.maskRgba,
  });
}

/// 构建“整图效果”（预览：先降采样，再处理，更快）
Uint8List buildEffectIsolate(EffectArgs a) {
  final im0 = img.decodeImage(a.srcBytes)!;
  img.Image im = img.bakeOrientation(im0);

  // ✅ 降采样到 a.previewMaxSide
  final maxSide = a.previewMaxSide;
  final mw = im.width, mh = im.height;
  final side = mw > mh ? mw : mh;
  if (side > maxSide) {
    final scale = maxSide / side;
    im = img.copyResize(im,
        width: (mw * scale).round(), height: (mh * scale).round(), interpolation: img.Interpolation.average);
  }

  switch (a.brush) {
    case MosaicBrushType.pixel:
      img.pixelate(im, size: a.strength.clamp(4, 64));
      break;
    case MosaicBrushType.blur:
      img.gaussianBlur(im, radius: a.strength.clamp(2, 40));
      break;
    case MosaicBrushType.hex:
      img.hexagonPixelate(im, size: a.strength.clamp(6, 64));
      break;
    case MosaicBrushType.glass:
      final s = a.strength.clamp(6, 48);
      img.pixelate(im, size: s);
      img.gaussianBlur(im, radius: (s / 3).round().clamp(2, 16));
      break;
    case MosaicBrushType.bars:
      _rectPixelate(im, (a.strength * 2).clamp(8, 128), (a.strength / 2).clamp(2, 48));
      break;
  }

  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

/// 导出：按原图分辨率应用效果（质量全尺寸）
Uint8List applyEffectIsolate(ApplyArgs a) {
  final base = img.decodeImage(a.srcBytes)!;
  final w = base.width, h = base.height;

  img.Image eff;
  if (a.effectBytes != null) {
    eff = img.decodeImage(a.effectBytes!)!;
    // 如果预览分辨率比原图小，重新全尺寸计算一次，确保质量
    if (eff.width != w || eff.height != h) {
      eff = img.Image.from(base, noAnimation: true);
      switch (a.brush) {
        case MosaicBrushType.pixel:
          img.pixelate(eff, size: a.strength.clamp(4, 64));
          break;
        case MosaicBrushType.blur:
          img.gaussianBlur(eff, radius: a.strength.clamp(2, 40));
          break;
        case MosaicBrushType.hex:
          img.hexagonPixelate(eff, size: a.strength.clamp(6, 64));
          break;
        case MosaicBrushType.glass:
          final s = a.strength.clamp(6, 48);
          img.pixelate(eff, size: s);
          img.gaussianBlur(eff, radius: (s / 3).round().clamp(2, 16));
          break;
        case MosaicBrushType.bars:
          _rectPixelate(eff, (a.strength * 2).clamp(8, 128), (a.strength / 2).clamp(2, 48));
          break;
      }
    }
  } else {
    eff = img.Image.from(base, noAnimation: true);
    switch (a.brush) {
      case MosaicBrushType.pixel:
        img.pixelate(eff, size: a.strength.clamp(4, 64));
        break;
      case MosaicBrushType.blur:
        img.gaussianBlur(eff, radius: a.strength.clamp(2, 40));
        break;
      case MosaicBrushType.hex:
        img.hexagonPixelate(eff, size: a.strength.clamp(6, 64));
        break;
      case MosaicBrushType.glass:
        final s = a.strength.clamp(6, 48);
        img.pixelate(eff, size: s);
        img.gaussianBlur(eff, radius: (s / 3).round().clamp(2, 16));
        break;
      case MosaicBrushType.bars:
        _rectPixelate(eff, (a.strength * 2).clamp(8, 128), (a.strength / 2).clamp(2, 48));
        break;
    }
  }

  final mask = a.maskRgba; // RGBA
  int idx(int x, int y) => (y * w + x) * 4;

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final mA = mask[idx(x, y) + 3];
      if (mA <= 12) continue; // 边缘阈值，柔和过渡
      base.setPixel(x, y, eff.getPixel(x, y));
    }
  }

  return Uint8List.fromList(img.encodeJpg(base, quality: 95));
}

/// 各向异性矩形像素化（条栅）
void _rectPixelate(img.Image im, int cellW, num cellHn) {
  final cellH = cellHn.toInt();
  final w = im.width, h = im.height;
  for (int y = 0; y < h; y += cellH) {
    for (int x = 0; x < w; x += cellW) {
      final xe = (x + cellW).clamp(0, w);
      final ye = (y + cellH).clamp(0, h);
      int r = 0, g = 0, b = 0, a = 0, cnt = 0;
      for (int yy = y; yy < ye; yy++) {
        for (int xx = x; xx < xe; xx++) {
          final p = im.getPixel(xx, yy);
          r += p.r.toInt(); g += p.g.toInt(); b += p.b.toInt(); a += p.a.toInt();
          cnt++;
        }
      }
      if (cnt == 0) continue;
      r ~/= cnt; g ~/= cnt; b ~/= cnt; a ~/= cnt;
      for (int yy = y; yy < ye; yy++) {
        for (int xx = x; xx < xe; xx++) {
          im.setPixelRgba(xx, yy, r, g, b, a);
        }
      }
    }
  }
}
