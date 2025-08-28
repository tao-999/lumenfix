// lib/widgets/filters/engine/engine_pixelate.dart
import 'dart:typed_data';
import 'dart:math' as math;

/// 像素化参数（单面板专用）
class PixelateSpec {
  final String id;
  final String name;
  final double? size;  // 单元格像素尺寸（优先）
  final int? gridX;    // 或：横向格子数（用于自适应）
  final int? gridY;    // 或：纵向格子数
  final int? levels;   // 每通道量化级数（null/<=1 表示不量化）
  final bool centerSample; // true=用中心采样；false=块内平均
  const PixelateSpec({
    required this.id,
    required this.name,
    this.size,
    this.gridX,
    this.gridY,
    this.levels,
    this.centerSample = false,
  });
}

Future<Uint8List> enginePixelate(
    Uint8List base, int w, int h, PixelateSpec p,
    ) async {
  final out = Uint8List(base.length);

  // 计算单元格大小
  int cell;
  if (p.size != null) {
    cell = p.size!.round().clamp(2, math.max(w, h));
  } else if (p.gridX != null && p.gridX! > 0) {
    cell = (w / p.gridX!).round().clamp(2, math.max(w, h));
  } else if (p.gridY != null && p.gridY! > 0) {
    cell = (h / p.gridY!).round().clamp(2, math.max(w, h));
  } else {
    cell = 8;
  }

  // 量化参数
  final lv = (p.levels ?? 0) <= 1 ? 0 : (p.levels!.clamp(2, 256));
  final step = lv == 0 ? 0.0 : 255.0 / (lv - 1);

  int idx(int x, int y) => ((y * w + x) << 2);

  for (int by = 0; by < h; by += cell) {
    final bh = (by + cell <= h) ? cell : (h - by);
    for (int bx = 0; bx < w; bx += cell) {
      final bw = (bx + cell <= w) ? cell : (w - bx);

      int r = 0, g = 0, b = 0, a = 0, count = 0;

      if (p.centerSample) {
        // 中心采样
        final cx = (bx + bw ~/ 2).clamp(0, w - 1);
        final cy = (by + bh ~/ 2).clamp(0, h - 1);
        final ii = idx(cx, cy);
        r = base[ii];
        g = base[ii + 1];
        b = base[ii + 2];
        a = base[ii + 3];
      } else {
        // 块内平均（240px 缩略下也够快）
        for (int y = 0; y < bh; y++) {
          final row = (by + y);
          final baseRow = row * w;
          for (int x = 0; x < bw; x++) {
            final col = (bx + x);
            final i = ((baseRow + col) << 2);
            r += base[i];
            g += base[i + 1];
            b += base[i + 2];
            a += base[i + 3];
            count++;
          }
        }
        if (count > 0) {
          r ~/= count; g ~/= count; b ~/= count; a ~/= count;
        }
      }

      // 量化
      if (lv != 0) {
        r = ((r / 255.0 * (lv - 1)).round() * step).round().clamp(0, 255);
        g = ((g / 255.0 * (lv - 1)).round() * step).round().clamp(0, 255);
        b = ((b / 255.0 * (lv - 1)).round() * step).round().clamp(0, 255);
      }

      // 填充整个块
      for (int y = 0; y < bh; y++) {
        final row = by + y;
        for (int x = 0; x < bw; x++) {
          final o = idx(bx + x, row);
          out[o]     = r;
          out[o + 1] = g;
          out[o + 2] = b;
          out[o + 3] = a;
        }
      }
    }
  }

  return out;
}
