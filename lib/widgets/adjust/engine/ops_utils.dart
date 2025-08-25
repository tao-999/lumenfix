// lib/widgets/adjust/engine/ops_utils.dart
part of 'adjust_engine.dart';

num _clamp255(num v) => v < 0 ? 0 : (v > 255 ? 255 : v);
double _smooth01(double x) => x <= 0 ? 0 : (x >= 1 ? 1 : x * x * (3 - 2 * x));

// ---------- RGB/HSL 相互转换 ----------
double _hueOf(num r, num g, num b) {
  final R = r / 255.0, G = g / 255.0, B = b / 255.0;
  final maxv = [R, G, B].reduce(math.max), minv = [R, G, B].reduce(math.min);
  final d = maxv - minv;
  double h = 0;
  if (d == 0) h = 0;
  else if (maxv == R) h = 60 * (((G - B) / d) % 6);
  else if (maxv == G) h = 60 * (((B - R) / d) + 2);
  else h = 60 * (((R - G) / d) + 4);
  if (h < 0) h += 360;
  return h;
}

double _satOf(num r, num g, num b) {
  final R = r / 255.0, G = g / 255.0, B = b / 255.0;
  final maxv = [R, G, B].reduce(math.max), minv = [R, G, B].reduce(math.min);
  final l = (maxv + minv) / 2.0;
  final d = maxv - minv;
  if (d == 0) return 0;
  return d / (1.0 - (2 * l - 1).abs());
}

List<double> _rgb2hsl(num r, num g, num b) {
  final h = _hueOf(r, g, b);
  final R = r / 255.0, G = g / 255.0, B = b / 255.0;
  final maxv = [R, G, B].reduce(math.max), minv = [R, G, B].reduce(math.min);
  final l = (maxv + minv) / 2.0;
  final s = _satOf(r, g, b);
  return [h, s, l];
}

List<num> _hsl2rgb(double h, double s, double l) {
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = l - c / 2;
  double r = 0, g = 0, b = 0;
  if (0 <= h && h < 60) {
    r = c; g = x;
  } else if (60 <= h && h < 120) {
    r = x; g = c;
  } else if (120 <= h && h < 180) {
    g = c; b = x;
  } else if (180 <= h && h < 240) {
    g = x; b = c;
  } else if (240 <= h && h < 300) {
    r = x; b = c;
  } else {
    r = c; b = x;
  }
  return [(r + m) * 255, (g + m) * 255, (b + m) * 255];
}
