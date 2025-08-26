import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../params/vibrance_params.dart';

class VibranceEngine {
  static Future<ui.Image> applyToImage(ui.Image src, VibranceParams p) async {
    final w = src.width, h = src.height;
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = bd!.buffer.asUint8List();
    applyToRgbaInPlace(bytes, w, h, p);
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(bytes, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  static void applyToRgbaInPlace(
      Uint8List rgba, int width, int height, VibranceParams p) {
    final n = width * height;
    final vK = (p.vibrance / 100.0).clamp(-1.0, 1.0);     // -1..1
    final sK = (1.0 + p.saturation / 100.0).clamp(0.0, 3.0);

    for (int i = 0, pi = 0; i < n; i++, pi += 4) {
      double r = rgba[pi] / 255.0;
      double g = rgba[pi + 1] / 255.0;
      double b = rgba[pi + 2] / 255.0;

      // RGB -> HSL
      final maxc = math.max(r, math.max(g, b));
      final minc = math.min(r, math.min(g, b));
      final l = (maxc + minc) * 0.5;
      double s, h;
      double d = maxc - minc;
      if (d == 0) {
        s = 0; h = 0;
      } else {
        s = l > 0.5 ? d / (2 - maxc - minc) : d / (maxc + minc);
        if (maxc == r) {
          h = (g - b) / d + (g < b ? 6 : 0);
        } else if (maxc == g) {
          h = (b - r) / d + 2;
        } else {
          h = (r - g) / d + 4;
        }
        h /= 6.0; // 0..1
      }

      // Saturation
      s = (s * sK).clamp(0.0, 1.0);

      // Vibrance：对低饱和加的多，对高饱和加的少
      final wLowSat = (1.0 - s);          // 低饱和权重
      s = (s + vK * wLowSat * s).clamp(0.0, 1.0);

      // HSL -> RGB
      double hue2rgb(double p, double q, double t) {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1/6) return p + (q - p) * 6 * t;
        if (t < 1/2) return q;
        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
        return p;
      }

      double rr, gg, bb;
      if (s == 0) {
        rr = gg = bb = l;
      } else {
        final q = l < 0.5 ? l * (1 + s) : (l + s - l * s);
        final p0 = 2 * l - q;
        rr = hue2rgb(p0, q, h + 1/3);
        gg = hue2rgb(p0, q, h);
        bb = hue2rgb(p0, q, h - 1/3);
      }

      rgba[pi]     = (rr * 255.0).round().clamp(0, 255);
      rgba[pi + 1] = (gg * 255.0).round().clamp(0, 255);
      rgba[pi + 2] = (bb * 255.0).round().clamp(0, 255);
    }
  }
}
