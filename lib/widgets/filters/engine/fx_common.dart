// lib/widgets/filters/engine/fx_common.dart
import 'dart:math' as math;
import 'dart:typed_data';

int _idx(int x,int y,int w)=>((y*w)+x)<<2;

void _read(Uint8List s,int w,int h,int x,int y,List<double> out){
  if(x<0) x=0; else if(x>=w) x=w-1;
  if(y<0) y=0; else if(y>=h) y=h-1;
  final o=_idx(x,y,w);
  out[0]=s[o]/255.0; out[1]=s[o+1]/255.0; out[2]=s[o+2]/255.0; out[3]=s[o+3]/255.0;
}

void bilinear(Uint8List s,int w,int h,double x,double y,List<double> out){
  final x0=x.floor(), y0=y.floor(), x1=x0+1, y1=y0+1;
  final tx=x-x0, ty=y-y0;
  final c00=List<double>.filled(4,0), c10=List<double>.filled(4,0),
      c01=List<double>.filled(4,0), c11=List<double>.filled(4,0);
  _read(s,w,h,x0,y0,c00); _read(s,w,h,x1,y0,c10);
  _read(s,w,h,x0,y1,c01); _read(s,w,h,x1,y1,c11);
  for(int i=0;i<4;i++){
    final a=c00[i]*(1-tx)+c10[i]*tx;
    final b=c01[i]*(1-tx)+c11[i]*tx;
    out[i]=a*(1-ty)+b*ty;
  }
}

int to8(double x)=>(math.min(1.0, math.max(0.0, x))*255.0+.5).floor();
int clampi(int x,int a,int b)=> x<a?a:(x>b?b:x);

Future<Uint8List> conv3(
    Uint8List s,int w,int h,{
      required List<List<num>> kernel,
      double bias=0.0,double scale=1.0,double mix=1.0,
    }) async {
  final out=Uint8List(s.length);
  final c=List<double>.filled(4,0), src=List<double>.filled(4,0);
  for(int y=0;y<h;y++){
    for(int x=0;x<w;x++){
      double rr=0,gg=0,bb=0;
      for(int j=-1;j<=1;j++){
        for(int i=-1;i<=1;i++){
          _read(s,w,h,x+i,y+j,c);
          final wv=kernel[j+1][i+1].toDouble();
          rr+=c[0]*wv; gg+=c[1]*wv; bb+=c[2]*wv;
        }
      }
      _read(s,w,h,x,y,src);
      rr=rr*scale+bias; gg=gg*scale+bias; bb=bb*scale+bias;
      final o=_idx(x,y,w);
      out[o]=to8(src[0]*(1-mix)+rr*mix);
      out[o+1]=to8(src[1]*(1-mix)+gg*mix);
      out[o+2]=to8(src[2]*(1-mix)+bb*mix);
      out[o+3]=s[o+3];
    }
  }
  return out;
}
