// lib/widgets/filters/engine/engine_distort.dart
import 'dart:math' as math;
import 'dart:typed_data';

/// 与面板的 DistortSpec 配套：输入 RGBA，输出 RGBA（不改入参）
class DistortSpec {
  final String id;
  final String name;
  final String type;        // barrel/pincushion/bulge/pinch/swirl/ripple/waveX/waveY/spherize/fisheye
  final double? amount;     // 主强度
  final double? radius;     // 0..1 相对短边
  final double? angle;      // 角度（度）
  final double? cx, cy;     // 中心 [0..1]
  final double? freq;       // 波频
  final double? amp;        // 幅度（像素）
  final double? phase;      // 相位

  const DistortSpec({
    required this.id,
    required this.name,
    required this.type,
    this.amount, this.radius, this.angle, this.cx, this.cy,
    this.freq, this.amp, this.phase,
  });
}

Future<Uint8List> engineDistort(
    Uint8List base, int w, int h, DistortSpec p,
    ) async {
  final out = Uint8List(base.length);
  final bw = w, bh = h;

  // 读参数（默认值）
  final amt   = (p.amount ?? 1.0);
  final rad   = (p.radius ?? 1.0);
  final ang   = (p.angle  ?? 0.0) * math.pi / 180.0;
  final cx    = (p.cx     ?? .5) * (bw - 1);
  final cy    = (p.cy     ?? .5) * (bh - 1);
  final freq  = (p.freq   ?? 10.0);
  final amp   = (p.amp    ?? 8.0);
  final phase = (p.phase  ?? 0.0);

  // 归一化半径（像素），按短边
  final shortSide = math.min(bw, bh).toDouble();
  final rPix = (rad * shortSide).clamp(1.0, shortSide);

  // 主循环：反向映射 + 双线性采样
  for (int y = 0; y < bh; y++) {
    for (int x = 0; x < bw; x++) {
      double sx = x.toDouble();
      double sy = y.toDouble();

      switch (p.type) {
        case 'barrel':
        case 'pincushion': {
          // 径向失真：barrel 正，pincushion 负
          final dx = (x - cx);
          final dy = (y - cy);
          final r  = math.sqrt(dx*dx + dy*dy);
          if (r > 0) {
            final k = (p.type == 'barrel' ? 1.0 : -1.0) * amt * 0.000005; // 系数
            final scale = 1 + k * r * r;
            sx = cx + dx * scale;
            sy = cy + dy * scale;
          }
          break;
        }
        case 'bulge':
        case 'pinch': {
          final dx = (x - cx);
          final dy = (y - cy);
          final r  = math.sqrt(dx*dx + dy*dy);
          if (r < rPix) {
            final t = 1 - (r / rPix);
            final s = (p.type == 'bulge' ? 1.0 : -1.0) * amt;
            final factor = 1 + s * t * t; // 中心更强
            sx = cx + dx * factor;
            sy = cy + dy * factor;
          }
          break;
        }
        case 'swirl': {
          final dx = x - cx;
          final dy = y - cy;
          final r  = math.sqrt(dx*dx + dy*dy);
          if (r < rPix) {
            final t = 1 - (r / rPix);
            final th = ang * t * amt;
            final cs = math.cos(th), sn = math.sin(th);
            sx = cx + dx * cs - dy * sn;
            sy = cy + dx * sn + dy * cs;
          }
          break;
        }
        case 'waveX': {
          final off = math.sin((y / bh) * freq * 2 * math.pi + phase) * amp * amt;
          sx = (x + off);
          break;
        }
        case 'waveY': {
          final off = math.sin((x / bw) * freq * 2 * math.pi + phase) * amp * amt;
          sy = (y + off);
          break;
        }
        case 'ripple': {
          final dx = x - cx;
          final dy = y - cy;
          final r  = math.sqrt(dx*dx + dy*dy);
          final off = math.sin(r / (shortSide / freq) + phase) * amp * amt;
          final rr = r + off;
          if (r > 1e-5) {
            sx = cx + dx * (rr / r);
            sy = cy + dy * (rr / r);
          }
          break;
        }
        case 'spherize': {
          final dx = (x - cx);
          final dy = (y - cy);
          final r  = math.sqrt(dx*dx + dy*dy);
          if (r < rPix) {
            final t = r / rPix;
            final z = math.sqrt(1 - t*t); // 球面
            final factor = 1 + (1 - z) * amt;
            sx = cx + dx * factor;
            sy = cy + dy * factor;
          }
          break;
        }
        case 'fisheye': {
          // 简化鱼眼：径向非线性映射
          final dx = (x - cx);
          final dy = (y - cy);
          final r  = math.sqrt(dx*dx + dy*dy);
          if (r < rPix) {
            final t = r / rPix;
            final f = (1 - math.cos(t * math.pi * 0.5)) * amt + 1.0;
            sx = cx + dx * f;
            sy = cy + dy * f;
          }
          break;
        }
        default:
          break;
      }

      // 双线性采样
      final rgba = _sampleBilinear(base, bw, bh, sx, sy);
      final o = (y * bw + x) << 2;
      out[o] = rgba[0];
      out[o + 1] = rgba[1];
      out[o + 2] = rgba[2];
      out[o + 3] = rgba[3];
    }
  }

  return out;
}

List<int> _sampleBilinear(Uint8List src, int w, int h, double fx, double fy) {
  // 超出边界：clamp
  if (fx < 0) fx = 0; else if (fx > w - 1) fx = w - 1.0;
  if (fy < 0) fy = 0; else if (fy > h - 1) fy = h - 1.0;

  final x0 = fx.floor();
  final y0 = fy.floor();
  final x1 = (x0 + 1 < w) ? x0 + 1 : x0;
  final y1 = (y0 + 1 < h) ? y0 + 1 : y0;

  final tx = fx - x0;
  final ty = fy - y0;

  List<int> px(int xx, int yy) {
    final i = (yy * w + xx) << 2;
    return [src[i], src[i + 1], src[i + 2], src[i + 3]];
  }

  final p00 = px(x0, y0);
  final p10 = px(x1, y0);
  final p01 = px(x0, y1);
  final p11 = px(x1, y1);

  int mix(int a, int b, double t) => (a + (b - a) * t).clamp(0.0, 255.0).round();
  final a0 = [mix(p00[0], p10[0], tx), mix(p00[1], p10[1], tx), mix(p00[2], p10[2], tx), mix(p00[3], p10[3], tx)];
  final a1 = [mix(p01[0], p11[0], tx), mix(p01[1], p11[1], tx), mix(p01[2], p11[2], tx), mix(p01[3], p11[3], tx)];

  return [mix(a0[0], a1[0], ty), mix(a0[1], a1[1], ty), mix(a0[2], a1[2], ty), mix(a0[3], a1[3], ty)];
}
