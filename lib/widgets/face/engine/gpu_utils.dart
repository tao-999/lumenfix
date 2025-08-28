import 'dart:typed_data';
import 'dart:ui' as ui;

/// 跨版本解码（兼容老/new decodeImageFromList 签名）
Future<ui.Image> decodeImageCompat(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  codec.dispose();
  return img;
}

Future<Uint8List> encodePng(ui.Image img) async {
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return Uint8List.view(bd!.buffer);
}

ui.Image _drawToImage(ui.PictureRecorder rec, int w, int h) {
  final pic = rec.endRecording();
  return pic.toImageSync(w, h);
}

/// 在 GPU 上执行一次绘制（返回 PNG 字节）
Future<Uint8List> drawGpu(
    ui.Image src,
    void Function(ui.Canvas, ui.Size) paint, {
      int? outW,
      int? outH,
    }) async {
  final w = outW ?? src.width;
  final h = outH ?? src.height;
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  paint(canvas, ui.Size(w.toDouble(), h.toDouble()));
  final out = _drawToImage(rec, w, h);
  final bytes = await encodePng(out);
  out.dispose();
  return bytes;
}

/// 原图画满
void drawFullImage(ui.Canvas c, ui.Image img, ui.Size size, {ui.Paint? paint}) {
  c.drawImageRect(
    img,
    ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, size.width, size.height),
    paint ?? (ui.Paint()..filterQuality = ui.FilterQuality.high),
  );
}

/// 色温（冷暖）矩阵
ui.ColorFilter colorTempMatrix(double tone) {
  final t = tone.clamp(-1.0, 1.0);
  final rScale = 1.0 + 0.12 * t;
  final bScale = 1.0 - 0.12 * t;
  final m = <double>[
    rScale, 0,      0,      0, 0,
    0,      1.0,    0,      0, 0,
    0,      0,      bScale, 0, 0,
    0,      0,      0,      1, 0,
  ];
  return ui.ColorFilter.matrix(m);
}

/// 多 Path 合并（并集）
ui.Path unionAll(Iterable<ui.Path> paths) {
  ui.Path? acc;
  for (final p in paths) {
    acc = acc == null ? p : ui.Path.combine(ui.PathOperation.union, acc, p);
  }
  return acc ?? ui.Path();
}
