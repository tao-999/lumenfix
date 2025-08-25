// lib/widgets/adjust/engine/ops_optics_geometry.dart
part of 'adjust_engine.dart';

// 光学校正（畸变/边角补偿/简单色差）
void opLens(img.Image im, Lens l) {
  if (l.isNeutral) return;

  final src = img.Image.from(im);
  final cx = (im.width - 1) / 2.0, cy = (im.height - 1) / 2.0;
  final k = l.distortion / 100.0;

  for (int y = 0; y < im.height; y++) {
    for (int x = 0; x < im.width; x++) {
      final dx = (x - cx) / cx, dy = (y - cy) / cy;
      final r = math.sqrt(dx * dx + dy * dy);
      final s = 1 + k * r * r;
      final sx = cx + dx * s * cx, sy = cy + dy * s * cy;

      final sp  = src.getPixelSafe(sx.round(), sy.round());
      final spR = src.getPixelSafe((sx + l.caRed).round(), sy.round());
      final spB = src.getPixelSafe((sx - l.caBlue).round(), sy.round());
      im.setPixelRgba(x, y, spR.r, sp.g, spB.b, sp.a);
    }
  }

  if (l.vignettingComp != 0) {
    final v = Vignette(amount: -l.vignettingComp, radius: 0.95, feather: 0.8);
    opVignette(im, v);
  }
}

/// 几何：纯旋转(±360°) + 透视(keystone 近似) + 等比缩放；
/// 画布尺寸保持不变；
/// - FAST 预览：
///   * 无透视 → 扫描线增量算法（极快），纯旋转不变形；
///   * 有透视 → 保留反向映射，但仍受全局 720 预览降采样保护；
/// - 导出：走完整反向映射（高质量）。
img.Image opGeometry(img.Image src, Geometry g) {
  final double ang = ((g.rotate % 360.0) + 360.0) % 360.0;
  final double sc  = g.scale.clamp(0.25, 4.0);
  // 与 GPU 约定同范围，避免畸变发散
  final double px  = g.perspX.clamp(-0.35, 0.35);
  final double py  = g.perspY.clamp(-0.35, 0.35);

  final bool neutral =
      ang.abs() < 1e-6 && (sc - 1.0).abs() < 1e-6 && px.abs() < 1e-6 && py.abs() < 1e-6;
  if (neutral) return src;

  final int w = src.width, h = src.height;
  final double cx = (w - 1) * 0.5, cy = (h - 1) * 0.5;

  final out = img.Image(
    width: w,
    height: h,
    format: src.format,
    numChannels: src.numChannels,
  );

  final double rad = ang * math.pi / 180.0;
  final double cosA = math.cos(rad);
  final double sinA = math.sin(rad);

  // 逐像素反向映射：dst(x,y) -> src(sx,sy)
  // 归一化到 [-1,1] 再解 2D 透视 + 旋转缩放
  for (int y = 0; y < h; y++) {
    final double dy = (y - cy) / cy;
    for (int x = 0; x < w; x++) {
      final double dx = (x - cx) / cx;

      // —— inverse of perspective: forward 是 (x1,y1) -> (x',y') = (x1/w, y1/w), w=1+px*x1+py*y1
      // 给定 (dx,dy) 反解 x1,y1：
      final double denom = (1.0 - (px * dx + py * dy));
      final double x1 = dx / (denom.abs() < 1e-6 ? (denom.isNegative ? -1e-6 : 1e-6) : denom);
      final double y1 = dy / (denom.abs() < 1e-6 ? (denom.isNegative ? -1e-6 : 1e-6) : denom);

      // —— inverse of rotate+scale：先反旋转再反缩放
      final double xr =  cosA * x1 + sinA * y1;
      final double yr = -sinA * x1 + cosA * y1;

      final double u = xr / sc;
      final double v = yr / sc;

      final double sx = cx + u * cx;
      final double sy = cy + v * cy;

      final sp = src.getPixelInterpolate(
        sx, sy,
        interpolation: img.Interpolation.linear,
      );
      out.setPixelRgba(x, y, sp.r, sp.g, sp.b, sp.a);
    }
  }
  return out;
}

// —— 快速路径：仅旋转 + 缩放（扫描线增量），每行只用加法推进 —— //
img.Image _rotateScaleFast(img.Image src, {required double angleDeg, required double scale}) {
  final int w = src.width, h = src.height;
  final double cx = (w - 1) * 0.5, cy = (h - 1) * 0.5;

  final img.Image dst = img.Image(
    width: w,
    height: h,
    format: src.format,
    numChannels: src.numChannels,
  );

  final double sc = scale.clamp(0.25, 4.0);
  final double invStep = 1.0 / sc;
  final double theta = angleDeg * math.pi / 180.0;
  final double c = math.cos(theta), s = math.sin(theta);

  for (int y = 0; y < h; y++) {
    final double dyPrime = (y - cy) / sc;

    double dxPrime = (-cx) / sc;
    double sx = cx + c * dxPrime + s * dyPrime;
    double sy = cy - s * dxPrime + c * dyPrime;

    final double stepSx = c * invStep;
    final double stepSy = -s * invStep;

    for (int x = 0; x < w; x++) {
      final sp = src.getPixelInterpolate(sx, sy, interpolation: img.Interpolation.linear);
      dst.setPixelRgba(x, y, sp.r, sp.g, sp.b, sp.a);
      sx += stepSx;
      sy += stepSy;
    }
  }

  return dst;
}
