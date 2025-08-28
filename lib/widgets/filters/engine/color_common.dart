// lib/widgets/filters/engine/color_common.dart
import 'dart:math' as math;
import 'dart:typed_data';

/// —— 调色公共：提供一个通用的“按 Spec 应用到 RGBA”方法 ——
/// 不引入任何 Engine 命名；各 panel 的引擎文件直接调用这里的方法即可。

void colorApplySpecInPlace(
    Uint8List rgba,
    int w,
    int h,
    Map<String, dynamic> spec,
    ) {
  final exposureEv   = _d(spec['exposureEv']);
  final brightness   = _d(spec['brightness']);
  final contrast     = _d(spec['contrast']);
  final matte        = _d(spec['matte']);
  final curve        = (spec['curve'] ?? 0) as int; // 0 none,1 soft,2 hard,3 film,4 matte

  final saturation   = _d(spec['saturation']);
  final vibrance     = _d(spec['vibrance']);
  final temperature  = _d(spec['temperature']);
  final tint         = _d(spec['tint']);
  final bw           = (spec['bw'] ?? false) == true;

  final duoA         = _argbToRgb(spec['duoA']);
  final duoB         = _argbToRgb(spec['duoB']);
  final duoAmount    = _clamp01(_d(spec['duoAmount']));

  final tealOrange   = _d(spec['tealOrange']);
  final hueShift     = _d(spec['hueShift']);
  final splitAmount  = _clamp01(_d(spec['splitAmount']));
  final splitBalance = _clamp(_d(spec['splitBalance']), -1.0, 1.0);
  final splitShadow  = _argbToRgb(spec['splitShadow']) ?? [0.0, 0.62, 0.65];
  final splitHigh    = _argbToRgb(spec['splitHighlight']) ?? [1.0, 0.58, 0.3];

  final expGain = math.pow(2.0, exposureEv);

  final n = w * h;
  for (int i = 0; i < n; i++) {
    final o = i << 2;
    double r = rgba[o]     / 255.0;
    double g = rgba[o + 1] / 255.0;
    double b = rgba[o + 2] / 255.0;
    final   a = rgba[o + 3];

    r = _tone(r, expGain, brightness, contrast, matte, curve);
    g = _tone(g, expGain, brightness, contrast, matte, curve);
    b = _tone(b, expGain, brightness, contrast, matte, curve);

    final wb = _wb(r, g, b, temperature, tint); r = wb[0]; g = wb[1]; b = wb[2];

    var hsv = _rgb2hsv(r, g, b);
    if (hueShift != 0) {
      hsv[0] = (hsv[0] + hueShift) % 360.0;
      if (hsv[0] < 0) hsv[0] += 360.0;
    }
    if (saturation != 0) hsv[1] = _clamp01(hsv[1] * (1 + saturation));
    if (vibrance   != 0) hsv[1] = _clamp01(hsv[1] + vibrance * (1 - hsv[1]));
    final rgb1 = _hsv2rgb(hsv[0], hsv[1], hsv[2]); r = rgb1[0]; g = rgb1[1]; b = rgb1[2];

    if (bw) { final y = _luma(r, g, b); r = g = b = y; }

    if (splitAmount > 0) {
      final lum = _luma(r, g, b);
      final t   = _clamp01((lum - .5) * 2 + splitBalance);
      final kS  = (1 - t) * splitAmount;
      final kH  = t * splitAmount;
      r = _mix(r, _tint(r, splitShadow[0]), kS);
      g = _mix(g, _tint(g, splitShadow[1]), kS);
      b = _mix(b, _tint(b, splitShadow[2]), kS);
      r = _mix(r, _tint(r, splitHigh[0]),   kH);
      g = _mix(g, _tint(g, splitHigh[1]),   kH);
      b = _mix(b, _tint(b, splitHigh[2]),   kH);
    }

    if (tealOrange != 0) {
      final lum = _luma(r, g, b);
      const cTeal = [0.0, 0.62, 0.65];
      const cOrg  = [1.0, 0.55, 0.25];
      final k = tealOrange * .85;
      r = _mix(r, _tint(r, cTeal[0]), (1 - lum) * k);
      g = _mix(g, _tint(g, cTeal[1]), (1 - lum) * k);
      b = _mix(b, _tint(b, cTeal[2]), (1 - lum) * k);
      r = _mix(r, _tint(r, cOrg[0]),  lum * k);
      g = _mix(g, _tint(g, cOrg[1]),  lum * k);
      b = _mix(b, _tint(b, cOrg[2]),  lum * k);
    }

    if (duoAmount > 0 && duoA != null && duoB != null) {
      final y  = _luma(r, g, b);
      final rr = _mix(duoA[0], duoB[0], y);
      final gg = _mix(duoA[1], duoB[1], y);
      final bb = _mix(duoA[2], duoB[2], y);
      r = _mix(r, rr, duoAmount);
      g = _mix(g, gg, duoAmount);
      b = _mix(b, bb, duoAmount);
    }

    rgba[o]     = _to8(r);
    rgba[o + 1] = _to8(g);
    rgba[o + 2] = _to8(b);
    rgba[o + 3] = a;
  }
}

Uint8List colorApplyThumb(
    Uint8List baseRgba,
    int w,
    int h,
    Map<String, dynamic> spec,
    ) {
  final out = Uint8List.fromList(baseRgba);
  colorApplySpecInPlace(out, w, h, spec);
  return out;
}

// —— 工具 —— //
double _tone(double x, num expGain, double br, double ct, double matte, int curve) {
  x = _clamp01(x * expGain);
  x = _clamp01(x + br);
  if (ct != 0) x = _clamp01((x - .5) * (1 + ct * 1.4) + .5);
  switch (curve) {
    case 1: x = _sigmoid(x, .85); break;
    case 2: x = _sigmoid(x, 1.25); break;
    case 3: x = _film(x); break;
    case 4: x = _sigmoid(x, .95); break;
    default: break;
  }
  if (matte > 0) {
    final lift = matte * .18;
    x = _clamp01(x * (1 - matte) + lift);
  }
  return x;
}

double _film(double x) { const a=2.51,b=.03,c=2.43,d=.59,e=.14; return _clamp01(((x*(a*x+b))/(x*(c*x+d)+e))); }

List<double> _wb(double r,double g,double b,double temp,double tint){
  final t = temp * .20; r=_clamp01(r*(1+t)); b=_clamp01(b*(1-t));
  final m = tint * .18; g=_clamp01(g*(1-m)); r=_clamp01(r*(1+m*.5)); b=_clamp01(b*(1+m*.5));
  return [r,g,b];
}

double _luma(double r,double g,double b)=>0.2627*r+0.6780*g+0.0593*b;
double _tint(double v,double tgt)=>_clamp01(v*.7+tgt*.3);
double _mix(double a,double b,double t)=>a+(b-a)*t;
int _to8(double x)=>(math.min(1.0, math.max(0.0, x))*255.0+.5).floor();
double _d(dynamic v)=> (v is num)?v.toDouble():double.tryParse('$v')??0.0;
double _clamp01(double x)=> x<0?0:(x>1?1:x);
double _clamp(double x,double a,double b)=> x<a?a:(x>b?b:x);
double _sigmoid(double x,double k){final t=(x-.5)*k*6.0; return 1/(1+math.exp(-t));}

List<double>? _argbToRgb(dynamic v){
  if(v==null) return null;
  final c=v as int;
  return [((c>>16)&0xFF)/255.0, ((c>>8)&0xFF)/255.0, (c&0xFF)/255.0];
}

// HSV
List<double> _rgb2hsv(double r,double g,double b){
  final maxc = math.max(r, math.max(g,b));
  final minc = math.min(r, math.min(g,b));
  final v = maxc; final d = maxc - minc;
  double h = 0, s = 0; if (maxc != 0) s = d/maxc;
  if (d != 0) {
    if (maxc == r)      h = 60.0 * ((g - b) / d % 6);
    else if (maxc == g) h = 60.0 * ((b - r) / d + 2);
    else                h = 60.0 * ((r - g) / d + 4);
  }
  if (h < 0) h += 360.0;
  return [h, s, v];
}
List<double> _hsv2rgb(double h,double s,double v){
  final c=v*s; final x=c*(1-((h/60.0)%2-1).abs()); final m=v-c;
  double r=0,g=0,b=0;
  if(h<60){r=c;g=x;} else if(h<120){r=x;g=c;}
  else if(h<180){g=c;b=x;} else if(h<240){g=x;b=c;}
  else if(h<300){r=x;b=c;} else {r=c;b=x;}
  return [r+m,g+m,b+m];
}
