// lib/widgets/adjust/adjust_params.dart
import 'dart:math';

class AdjustParams {
  // ===== 已有（保持不变） =====
  double exposure; double contrast; double highlights; double shadows;
  double whites; double blacks; double gamma;
  double saturation; double vibrance; double temperature; double tint;
  double clarity; double sharpness; double denoise;

  // ===== 新增（全部可选，默认中性） =====
  HslTable hsl;                 // 8 分区 H/S/L
  ToneCurves curves;            // Luma + RGB 曲线
  ColorGrade grade;             // 色轮：阴影/中间调/高光
  SplitToning split;            // 分离色调
  double texture;               // 纹理（-100..100）
  Vignette vignette;            // 暗角（强度/半径/圆角/羽化/中心）
  Grain grain;                  // 胶片颗粒（强度/粒径/粗糙）
  Bloom bloom;                  // 辉光（阈值/强度/半径）
  Usm usm;                      // 锐化高级（量/半径/阈值）
  DenoiseAdv denoiseAdv;        // 降噪：亮度/色度
  Defringe defringe;            // 去紫边
  Deband deband;                // 去色带
  Lens lens;                    // 镜头校正（畸变/边角渐晕补偿/色差）
  Geometry geo;                 // 几何/透视/裁剪
  LutConfig lut;                // LUT 混合

  AdjustParams({
    // 旧字段默认
    this.exposure = 0, this.contrast = 0, this.highlights = 0, this.shadows = 0,
    this.whites = 0, this.blacks = 0, this.gamma = 1.0,
    this.saturation = 0, this.vibrance = 0, this.temperature = 0, this.tint = 0,
    this.clarity = 0, this.sharpness = 0, this.denoise = 0,
    // 新增默认
    HslTable? hsl, ToneCurves? curves, ColorGrade? grade, SplitToning? split,
    this.texture = 0,
    Vignette? vignette, Grain? grain, Bloom? bloom, Usm? usm, DenoiseAdv? denoiseAdv,
    Defringe? defringe, Deband? deband, Lens? lens, Geometry? geo, LutConfig? lut,
  })  : hsl = hsl ?? HslTable.neutral(),
        curves = curves ?? ToneCurves.neutral(),
        grade = grade ?? ColorGrade.neutral(),
        split = split ?? SplitToning.neutral(),
        vignette = vignette ?? Vignette.neutral(),
        grain = grain ?? Grain.neutral(),
        bloom = bloom ?? Bloom.neutral(),
        usm = usm ?? Usm.neutral(),
        denoiseAdv = denoiseAdv ?? DenoiseAdv.neutral(),
        defringe = defringe ?? Defringe.neutral(),
        deband = deband ?? Deband.neutral(),
        lens = lens ?? Lens.neutral(),
        geo = geo ?? Geometry.neutral(),
        lut = lut ?? LutConfig.neutral();

  factory AdjustParams.neutral() => AdjustParams();

  Map<String, dynamic> toMap() => {
    // 旧字段
    'exposure': exposure, 'contrast': contrast, 'highlights': highlights,
    'shadows': shadows, 'whites': whites, 'blacks': blacks, 'gamma': gamma,
    'saturation': saturation, 'vibrance': vibrance, 'temperature': temperature,
    'tint': tint, 'clarity': clarity, 'sharpness': sharpness, 'denoise': denoise,
    // 新字段
    'hsl': hsl.toMap(), 'curves': curves.toMap(), 'grade': grade.toMap(),
    'split': split.toMap(), 'texture': texture,
    'vignette': vignette.toMap(), 'grain': grain.toMap(), 'bloom': bloom.toMap(),
    'usm': usm.toMap(), 'denoiseAdv': denoiseAdv.toMap(),
    'defringe': defringe.toMap(), 'deband': deband.toMap(),
    'lens': lens.toMap(), 'geo': geo.toMap(), 'lut': lut.toMap(),
  };

  factory AdjustParams.fromMap(Map m) => AdjustParams(
    // 旧字段
    exposure: (m['exposure'] ?? 0).toDouble(),
    contrast: (m['contrast'] ?? 0).toDouble(),
    highlights: (m['highlights'] ?? 0).toDouble(),
    shadows: (m['shadows'] ?? 0).toDouble(),
    whites: (m['whites'] ?? 0).toDouble(),
    blacks: (m['blacks'] ?? 0).toDouble(),
    gamma: (m['gamma'] ?? 1.0).toDouble(),
    saturation: (m['saturation'] ?? 0).toDouble(),
    vibrance: (m['vibrance'] ?? 0).toDouble(),
    temperature: (m['temperature'] ?? 0).toDouble(),
    tint: (m['tint'] ?? 0).toDouble(),
    clarity: (m['clarity'] ?? 0).toDouble(),
    sharpness: (m['sharpness'] ?? 0).toDouble(),
    denoise: (m['denoise'] ?? 0).toDouble(),
    // 新字段（兼容旧数据）
    hsl: HslTable.fromMap(m['hsl'] ?? const {}),
    curves: ToneCurves.fromMap(m['curves'] ?? const {}),
    grade: ColorGrade.fromMap(m['grade'] ?? const {}),
    split: SplitToning.fromMap(m['split'] ?? const {}),
    texture: (m['texture'] ?? 0).toDouble(),
    vignette: Vignette.fromMap(m['vignette'] ?? const {}),
    grain: Grain.fromMap(m['grain'] ?? const {}),
    bloom: Bloom.fromMap(m['bloom'] ?? const {}),
    usm: Usm.fromMap(m['usm'] ?? const {}),
    denoiseAdv: DenoiseAdv.fromMap(m['denoiseAdv'] ?? const {}),
    defringe: Defringe.fromMap(m['defringe'] ?? const {}),
    deband: Deband.fromMap(m['deband'] ?? const {}),
    lens: Lens.fromMap(m['lens'] ?? const {}),
    geo: Geometry.fromMap(m['geo'] ?? const {}),
    lut: LutConfig.fromMap(m['lut'] ?? const {}),
  );

  AdjustParams clone() => AdjustParams.fromMap(toMap());

  bool get isNeutral {
    const eps = 1e-6;
    final base = [
      exposure, contrast, highlights, shadows, whites, blacks,
      saturation, vibrance, temperature, tint, clarity, sharpness, denoise
    ].every((v) => v.abs() < eps) && (gamma - 1.0).abs() < eps;
    final ext = texture.abs() < eps &&
        hsl.isNeutral && curves.isNeutral && grade.isNeutral && split.isNeutral &&
        vignette.isNeutral && grain.isNeutral && bloom.isNeutral &&
        usm.isNeutral && denoiseAdv.isNeutral && defringe.isNeutral &&
        deband.isNeutral && lens.isNeutral && geo.isNeutral && lut.isNeutral;
    return base && ext;
  }
}

// ---------- HSL 8 分区 ----------
enum HslBand { red, orange, yellow, green, aqua, blue, purple, magenta }

class HslAdjust { // 每个色相分区的 H/S/L 调整
  final double hue;       // [-180,180] 度
  final double sat;       // [-100,100]
  final double lum;       // [-100,100]
  const HslAdjust({this.hue = 0, this.sat = 0, this.lum = 0});
  Map<String,dynamic> toMap()=>{'hue':hue,'sat':sat,'lum':lum};
  factory HslAdjust.fromMap(Map m)=>HslAdjust(
      hue:(m['hue']??0).toDouble(), sat:(m['sat']??0).toDouble(), lum:(m['lum']??0).toDouble());
  bool get isNeutral => hue==0 && sat==0 && lum==0;
}

class HslTable {
  final Map<HslBand,HslAdjust> bands;
  const HslTable(this.bands);
  factory HslTable.neutral()=>HslTable({
    for(final b in HslBand.values) b: const HslAdjust(),
  });
  Map<String,dynamic> toMap()=>bands.map((k,v)=>MapEntry(k.name, v.toMap()));
  factory HslTable.fromMap(Map m){
    final map = <HslBand,HslAdjust>{};
    for(final b in HslBand.values){
      map[b]=HslAdjust.fromMap((m[b.name]??const {} ) as Map);
    }
    return HslTable(map);
  }
  bool get isNeutral => bands.values.every((e)=>e.isNeutral);
}

// ---------- 曲线 ----------
class CurvePt{ final double x,y; const CurvePt(this.x,this.y);
Map toMap()=>{'x':x,'y':y}; factory CurvePt.fromMap(Map m)=>CurvePt((m['x']??0).toDouble(),(m['y']??0).toDouble());}
class ToneCurves{
  final List<CurvePt> luma, r, g, b;
  const ToneCurves(this.luma,this.r,this.g,this.b);
  factory ToneCurves.neutral()=>ToneCurves(
    const [CurvePt(0,0),CurvePt(1,1)],
    const [CurvePt(0,0),CurvePt(1,1)],
    const [CurvePt(0,0),CurvePt(1,1)],
    const [CurvePt(0,0),CurvePt(1,1)],
  );
  Map<String,dynamic> toMap()=> {
    'luma': luma.map((e)=>e.toMap()).toList(),
    'r': r.map((e)=>e.toMap()).toList(),
    'g': g.map((e)=>e.toMap()).toList(),
    'b': b.map((e)=>e.toMap()).toList(),
  };
  factory ToneCurves.fromMap(Map m){
    List<CurvePt> _list(String k){
      final L=(m[k]??[]) as List; return L.map((e)=>CurvePt.fromMap(e as Map)).toList();
    }
    final t=ToneCurves(_list('luma'),_list('r'),_list('g'),_list('b'));
    return t.luma.isEmpty?t.copyWith(ToneCurves.neutral()):t;
  }
  ToneCurves copyWith(ToneCurves other)=>ToneCurves(
      other.luma.isEmpty?luma:other.luma,
      other.r.isEmpty?r:other.r, other.g.isEmpty?g:other.g, other.b.isEmpty?b:other.b);
  bool get isNeutral => [luma,r,g,b].every((L)=>L.length==2 && L.first.x==0 && L.first.y==0 && L.last.x==1 && L.last.y==1);
}

// ---------- 色轮 / 分离色调 ----------
class GradeWheel{ final double hue,sat,lum; const GradeWheel({this.hue=0,this.sat=0,this.lum=0});
Map toMap()=>{'h':hue,'s':sat,'l':lum}; factory GradeWheel.fromMap(Map m)=>GradeWheel(
    hue:(m['h']??0).toDouble(), sat:(m['s']??0).toDouble(), lum:(m['l']??0).toDouble()); bool get isNeutral=>hue==0&&sat==0&&lum==0;}
class ColorGrade{
  final GradeWheel shadows, mids, highs;
  // Pivot & falloff in 0..1
  final double shadowPivot, highPivot, softness;
  const ColorGrade({this.shadows=const GradeWheel(),this.mids=const GradeWheel(),this.highs=const GradeWheel(),
    this.shadowPivot=0.25,this.highPivot=0.75,this.softness=0.2});
  factory ColorGrade.neutral()=>const ColorGrade();
  Map toMap()=>{'shadows':shadows.toMap(),'mids':mids.toMap(),'highs':highs.toMap(),
    'sp':shadowPivot,'hp':highPivot,'sf':softness};
  factory ColorGrade.fromMap(Map m)=>ColorGrade(
    shadows: GradeWheel.fromMap(m['shadows']??const{}),
    mids: GradeWheel.fromMap(m['mids']??const{}),
    highs: GradeWheel.fromMap(m['highs']??const{}),
    shadowPivot: (m['sp']??0.25).toDouble(),
    highPivot: (m['hp']??0.75).toDouble(),
    softness: (m['sf']??0.2).toDouble(),
  );
  bool get isNeutral => shadows.isNeutral && mids.isNeutral && highs.isNeutral;
}

class SplitToning{
  final double hHue,hSat,sHue,sSat,balance; // hue: [-180,180], sat:[-100,100], balance:[-100..100]
  const SplitToning({this.hHue=0,this.hSat=0,this.sHue=0,this.sSat=0,this.balance=0});
  factory SplitToning.neutral()=>const SplitToning();
  Map toMap()=>{'hh':hHue,'hs':hSat,'sh':sHue,'ss':sSat,'bal':balance};
  factory SplitToning.fromMap(Map m)=>SplitToning(
    hHue:(m['hh']??0).toDouble(), hSat:(m['hs']??0).toDouble(),
    sHue:(m['sh']??0).toDouble(), sSat:(m['ss']??0).toDouble(),
    balance:(m['bal']??0).toDouble(),
  );
  bool get isNeutral => [hHue,hSat,sHue,sSat,balance].every((v)=>v==0);
}

// ---------- 纹理/暗角/颗粒/辉光 ----------
class Vignette{ final double amount,radius,roundness,feather, cx,cy;
const Vignette({this.amount=0,this.radius=0.75,this.roundness=0.0,this.feather=0.5,this.cx=0.0,this.cy=0.0});
factory Vignette.neutral()=>const Vignette();
Map toMap()=>{'a':amount,'r':radius,'ro':roundness,'f':feather,'cx':cx,'cy':cy};
factory Vignette.fromMap(Map m)=>Vignette(
  amount:(m['a']??0).toDouble(), radius:(m['r']??0.75).toDouble(),
  roundness:(m['ro']??0.0).toDouble(), feather:(m['f']??0.5).toDouble(),
  cx:(m['cx']??0.0).toDouble(), cy:(m['cy']??0.0).toDouble(),
);
bool get isNeutral => amount==0;
}
class Grain{ final double amount,size,roughness; const Grain({this.amount=0,this.size=1.0,this.roughness=0.5});
factory Grain.neutral()=>const Grain();
Map toMap()=>{'a':amount,'s':size,'r':roughness};
factory Grain.fromMap(Map m)=>Grain(
    amount:(m['a']??0).toDouble(), size:(m['s']??1.0).toDouble(), roughness:(m['r']??0.5).toDouble());
bool get isNeutral=>amount==0;
}
class Bloom{ final double threshold,intensity,radius; const Bloom({this.threshold=0.8,this.intensity=0,this.radius=20});
factory Bloom.neutral()=>const Bloom();
Map toMap()=>{'t':threshold,'i':intensity,'r':radius};
factory Bloom.fromMap(Map m)=>Bloom(
    threshold:(m['t']??0.8).toDouble(), intensity:(m['i']??0).toDouble(), radius:(m['r']??20).toDouble());
bool get isNeutral=>intensity==0;
}
class Usm{ final double amount,radius,threshold; const Usm({this.amount=0,this.radius=1.0,this.threshold=0});
factory Usm.neutral()=>const Usm();
Map toMap()=>{'a':amount,'r':radius,'t':threshold};
factory Usm.fromMap(Map m)=>Usm(
    amount:(m['a']??0).toDouble(), radius:(m['r']??1.0).toDouble(), threshold:(m['t']??0).toDouble());
bool get isNeutral=>amount==0;
}
class DenoiseAdv{ final double luma,chroma; const DenoiseAdv({this.luma=0,this.chroma=0});
factory DenoiseAdv.neutral()=>const DenoiseAdv();
Map toMap()=>{'l':luma,'c':chroma};
factory DenoiseAdv.fromMap(Map m)=>DenoiseAdv(luma:(m['l']??0).toDouble(),chroma:(m['c']??0).toDouble());
bool get isNeutral=>luma==0 && chroma==0;
}
class Defringe{ final double amount, hueCenter, hueWidth; const Defringe({this.amount=0,this.hueCenter=300,this.hueWidth=40});
factory Defringe.neutral()=>const Defringe();
Map toMap()=>{'a':amount,'c':hueCenter,'w':hueWidth};
factory Defringe.fromMap(Map m)=>Defringe(
    amount:(m['a']??0).toDouble(), hueCenter:(m['c']??300).toDouble(), hueWidth:(m['w']??40).toDouble());
bool get isNeutral=>amount==0;
}
class Deband{ final double amount,dither; const Deband({this.amount=0,this.dither=0.3});
factory Deband.neutral()=>const Deband();
Map toMap()=>{'a':amount,'d':dither};
factory Deband.fromMap(Map m)=>Deband(amount:(m['a']??0).toDouble(), dither:(m['d']??0.3).toDouble());
bool get isNeutral=>amount==0;
}
class Lens{ final double distortion, vignettingComp, caRed, caBlue; // 简化：径向畸变 & 色差两个通道偏移
const Lens({this.distortion=0,this.vignettingComp=0,this.caRed=0,this.caBlue=0});
factory Lens.neutral()=>const Lens();
Map toMap()=>{'d':distortion,'v':vignettingComp,'cr':caRed,'cb':caBlue};
factory Lens.fromMap(Map m)=>Lens(
    distortion:(m['d']??0).toDouble(), vignettingComp:(m['v']??0).toDouble(),
    caRed:(m['cr']??0).toDouble(), caBlue:(m['cb']??0).toDouble());
bool get isNeutral=>distortion==0 && vignettingComp==0 && caRed==0 && caBlue==0;
}
class Geometry{ final double rotate, perspX, perspY, scale; final List<double> crop; // crop: [l,t,r,b] 0..1
const Geometry({this.rotate=0,this.perspX=0,this.perspY=0,this.scale=1.0,this.crop=const [0,0,1,1]});
factory Geometry.neutral()=>const Geometry();
Map toMap()=>{'rot':rotate,'px':perspX,'py':perspY,'s':scale,'crop':crop};
factory Geometry.fromMap(Map m)=>Geometry(
    rotate:(m['rot']??0).toDouble(), perspX:(m['px']??0).toDouble(), perspY:(m['py']??0).toDouble(),
    scale:(m['s']??1.0).toDouble(), crop: List<double>.from(m['crop']??const [0,0,1,1]));
bool get isNeutral=>rotate==0 && perspX==0 && perspY==0 && scale==1.0 && crop[0]==0 && crop[1]==0 && crop[2]==1 && crop[3]==1;
}
class LutConfig{ final String id; final double strength; // 用 id 找到内置/外部 .cube；引擎负责加载
const LutConfig({this.id='', this.strength=0});
factory LutConfig.neutral()=>const LutConfig();
Map toMap()=>{'id':id,'k':strength};
factory LutConfig.fromMap(Map m)=>LutConfig(id:(m['id']??'') as String, strength:(m['k']??0).toDouble());
bool get isNeutral=>strength==0 || id.isEmpty;
}
