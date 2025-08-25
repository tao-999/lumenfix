// lib/widgets/adjust/engine/ops_color_curves_hsl_grade_split.dart
part of 'adjust_engine.dart';

// ---------- 曲线 ----------
List<int> _curveLut(List<CurvePt> pts) {
  if (pts.length < 2) return List<int>.generate(256, (i) => i);
  final sorted = [...pts]..sort((a, b) => a.x.compareTo(b.x));

  double interp(double x) {
    for (int i = 0; i < sorted.length - 1; i++) {
      final p0 = sorted[i], p1 = sorted[i + 1];
      if (x >= p0.x && x <= p1.x) {
        final t = ((x - p0.x) / (p1.x - p0.x)).clamp(0.0, 1.0);
        return p0.y * (1 - t) + p1.y * t;
      }
    }
    return x <= sorted.first.x ? sorted.first.y : sorted.last.y;
  }

  return List<int>.generate(256, (i) {
    final x = i / 255.0;
    final y = interp(x).clamp(0.0, 1.0);
    return (y * 255.0).round();
  });
}

void opCurves(img.Image im, ToneCurves c) {
  if (c.isNeutral) return;

  final lLut = _curveLut(c.luma);
  final rLut = _curveLut(c.r);
  final gLut = _curveLut(c.g);
  final bLut = _curveLut(c.b);

  for (final px in im) {
    final r = px.r, g = px.g, b = px.b;

    // Luma curve（在亮度通道做缩放）
    final y = (0.2126 * r + 0.7152 * g + 0.0722 * b).clamp(0, 255).toInt();
    final y2 = lLut[y];
    final scale = (y == 0) ? 1.0 : (y2 / y);

    int rr = (r * scale).clamp(0, 255).toInt();
    int gg = (g * scale).clamp(0, 255).toInt();
    int bb = (b * scale).clamp(0, 255).toInt();

    // RGB 通道曲线
    rr = rLut[rr];
    gg = gLut[gg];
    bb = bLut[bb];

    px
      ..r = rr
      ..g = gg
      ..b = bb;
  }
}

// ---------- HSL 8 分区（高斯混合 + 安全取模） ----------

// 0..360
@pragma('vm:prefer-inline')
double _wrapHue(double h) {
  h = h % 360.0;
  return h < 0 ? h + 360.0 : h;
}

// 圆环角距（0..180）
@pragma('vm:prefer-inline')
double _hueDist(double a, double b) {
  final d = (a - b).abs();
  return d > 180.0 ? 360.0 - d : d;
}

void opHslBands(img.Image im, HslTable table) {
  if (table.isNeutral) return;

  const centers = <HslBand, double>{
    HslBand.red:     0.0,
    HslBand.orange: 30.0,
    HslBand.yellow: 60.0,
    HslBand.green: 120.0,
    HslBand.aqua:  180.0,
    HslBand.blue:  240.0,
    HslBand.purple:270.0,
    HslBand.magenta:300.0,
  };

  // sigma≈30°，覆盖更均匀；w = exp(-d^2/(2*sigma^2))
  const double sigma = 30.0;
  const double denom = 2.0 * sigma * sigma;

  final bands = table.bands;

  for (final px in im) {
    final r0 = px.r, g0 = px.g, b0 = px.b;

    final hsl = _rgb2hsl(r0, g0, b0);
    double h = _wrapHue(hsl[0]);
    double s = hsl[1];
    double l = hsl[2];

    double wSum = 0.0;
    double dHue = 0.0;
    double kSat = 0.0;
    double kLum = 0.0;

    for (final e in centers.entries) {
      final adj = bands[e.key]!;
      if (adj.isNeutral) continue;

      final d = _hueDist(h, e.value);
      final w = math.exp(-(d * d) / denom);
      if (w <= 1e-6) continue;

      wSum += w;
      dHue += adj.hue * w;            // 度
      kSat += (adj.sat / 100.0) * w;  // 相对
      kLum += (adj.lum / 100.0) * w;  // 相对
    }

    if (wSum <= 1e-6) continue;

    dHue /= wSum;
    kSat /= wSum;
    kLum /= wSum;

    final h2 = _wrapHue(h + dHue);
    final s2 = (s * (1.0 + kSat)).clamp(0.0, 1.0);
    final l2 = (l * (1.0 + kLum)).clamp(0.0, 1.0);

    final rgb = _hsl2rgb(h2, s2, l2);
    px
      ..r = _clamp255(rgb[0])
      ..g = _clamp255(rgb[1])
      ..b = _clamp255(rgb[2]);
  }
}

// ---------- 色轮（阴影/中间/高光） ----------
void opColorGrade(img.Image im, ColorGrade g) {
  if (g.isNeutral) return;

  for (final px in im) {
    num r = px.r, gg = px.g, b = px.b;
    final y = (0.2126 * r + 0.7152 * gg + 0.0722 * b) / 255.0;

    double ws = _smooth01(((g.shadowPivot - y) / g.softness).clamp(0.0, 1.0));
    double wh = _smooth01(((y - g.highPivot) / g.softness).clamp(0.0, 1.0));
    ws = 1.0 - ws;                         // 阴影：y 越小越接近 1
    final wm = (1.0 - ws - wh).clamp(0.0, 1.0);

    List<num> tint(num r, num g, num b, GradeWheel w, double k) {
      if (k <= 0 || w.isNeutral) return [r, g, b];
      final hsl = _rgb2hsl(r, g, b);
      final h = _wrapHue(hsl[0] + w.hue * k);
      final s = (hsl[1] * (1.0 + w.sat / 100.0 * k)).clamp(0.0, 1.0);
      final l = (hsl[2] * (1.0 + w.lum / 100.0 * k)).clamp(0.0, 1.0);
      final rgb = _hsl2rgb(h, s, l);
      return [rgb[0], rgb[1], rgb[2]];
    }

    var rgb = [r, gg, b];
    rgb = tint(rgb[0], rgb[1], rgb[2], g.shadows, ws);
    rgb = tint(rgb[0], rgb[1], rgb[2], g.mids, wm);
    rgb = tint(rgb[0], rgb[1], rgb[2], g.highs, wh);

    px
      ..r = _clamp255(rgb[0])
      ..g = _clamp255(rgb[1])
      ..b = _clamp255(rgb[2]);
  }
}

// ---------- 分离色调 ----------
void opSplitToning(img.Image im, SplitToning s) {
  if (s.isNeutral) return;

  final kh = (s.hSat / 100.0).clamp(-1.0, 1.0);
  final ks = (s.sSat / 100.0).clamp(-1.0, 1.0);
  final bal = (s.balance / 100.0);

  for (final px in im) {
    num r = px.r, g = px.g, b = px.b;
    final y = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
    final wh = _smooth01(((y - 0.5 + bal * 0.3) + 0.5).clamp(0.0, 1.0)); // 高光权重
    final ws = 1.0 - wh;

    List<num> tint(num r, num g, num b, double hue, double sat, double k) {
      if (k <= 0 || sat == 0) return [r, g, b];
      final hsl = _rgb2hsl(r, g, b);
      final h = _wrapHue(hsl[0] + hue);
      final s2 = (hsl[1] * (1.0 + sat)).clamp(0.0, 1.0);
      final rgb = _hsl2rgb(h, s2, hsl[2]);
      return [(1 - k) * r + k * rgb[0], (1 - k) * g + k * rgb[1], (1 - k) * b + k * rgb[2]];
    }

    var rgb = [r, g, b];
    rgb = tint(rgb[0], rgb[1], rgb[2], s.sHue, ks, ws.abs());
    rgb = tint(rgb[0], rgb[1], rgb[2], s.hHue, kh, wh.abs());

    px
      ..r = _clamp255(rgb[0])
      ..g = _clamp255(rgb[1])
      ..b = _clamp255(rgb[2]);
  }
}
