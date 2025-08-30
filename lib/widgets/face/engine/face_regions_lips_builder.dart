// lib/widgets/face/engine/face_regions_lips_builder.dart
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;
import 'dart:ui' as ui;

const List<int> _kOuterIdx = <int>[
  // 外环（合并上/下，顺时针闭合，含嘴角过渡点）
  61,185,40,39,37,0,267,269,270,409,291,375,321,405,314,17,84,181,91,146,61
];
const List<int> _kInnerIdx = <int>[
  // 内环（口腔边界，顺时针闭合）
  78,95,88,178,87,14,317,402,318,324,308,78
];

class LipsAdvanced {
  final ui.Path outer, inner;         // 平滑闭合边界
  final ui.Path ringUpper, ringLower; // 上/下唇上妆区域（不染牙）
  LipsAdvanced(this.outer, this.inner, this.ringUpper, this.ringLower);
}

LipsAdvanced buildLipsAdvancedFromMesh({
  required ui.Size imageSize,
  required List<ui.Offset> pointsPx, // 468 点像素坐标
  double crTension = 0.5,            // Catmull-Rom 张力
  double baseInnerExpand = 1.06,     // ⭐ 基准外扩（>1 向外）
  double maxInnerExpand  = 1.20,     // ⭐ 最大外扩（张嘴很大时）
}) {
  assert(pointsPx.length >= 468);

  // 关键点
  final ui.Offset Lc = pointsPx[61];          // 左嘴角
  final ui.Offset Rc = pointsPx[291];         // 右嘴角
  final ui.Offset upperInnerMid = pointsPx[13];
  final ui.Offset lowerInnerMid = pointsPx[14];

  // 平滑外/内多边形
  final outerPoly = _pick(pointsPx, _kOuterIdx);
  final innerPoly = _pick(pointsPx, _kInnerIdx);
  final ui.Path outer = _smoothClosed(outerPoly, tension: crTension);
  ui.Path inner = _smoothClosed(innerPoly, tension: crTension);

  // —— 依据开口度自适应外扩 inner，并裁回 outer —— //
  final double seamLen = (Rc - Lc).distance;
  final double openGap = (lowerInnerMid - upperInnerMid).distance;
  final double openness = (openGap / math.max(1.0, seamLen)).clamp(0.0, 0.6); // 0..0.6
  final double expand = (baseInnerExpand + openness * 0.9) // 张嘴越大越外扩
      .clamp(baseInnerExpand, maxInnerExpand);

  final ui.Offset ic = inner.getBounds().center;
  final ui.Path innerExpanded = inner.transform(_scaleAround(expand, expand, ic.dx, ic.dy));
  // 只保留 outer 内的部分，避免越界
  final ui.Path innerForDiff = ui.Path.combine(ui.PathOperation.intersect, innerExpanded, outer);

  // 完整 ring（兜底）
  final ui.Path ringFull = ui.Path.combine(ui.PathOperation.difference, outer, innerForDiff)
    ..fillType = ui.PathFillType.evenOdd;

  // 沿嘴角连线分上/下半
  final ui.Path hpUpper = _halfPlane(Lc, Rc, keepPoint: upperInnerMid, imgSize: imageSize);
  final ui.Path hpLower = _halfPlane(Lc, Rc, keepPoint: lowerInnerMid, imgSize: imageSize);

  ui.Path ringUpper = ui.Path.combine(ui.PathOperation.intersect, ringFull, hpUpper);
  ui.Path ringLower = ui.Path.combine(ui.PathOperation.intersect, ringFull, hpLower);

  // 极端情况下为空 → 回退
  if (ringUpper.getBounds().isEmpty) ringUpper = ringFull;
  if (ringLower.getBounds().isEmpty) ringLower = ringFull;

  outer.fillType = ui.PathFillType.nonZero;
  inner.fillType = ui.PathFillType.nonZero;
  ringUpper.fillType = ui.PathFillType.evenOdd;
  ringLower.fillType = ui.PathFillType.evenOdd;

  return LipsAdvanced(outer, inner, ringUpper, ringLower);
}

// ========== 几何 & 工具 ==========

List<ui.Offset> _pick(List<ui.Offset> pts, List<int> idx) =>
    idx.map((i) => pts[i]).toList(growable: false);

ui.Path _smoothClosed(List<ui.Offset> poly, {double tension = .5}) {
  final n = poly.length;
  final path = ui.Path();
  if (n < 3) { path.addPolygon(poly, true); return path; }

  final pts = <ui.Offset>[...poly, poly.first];
  path.moveTo(pts[0].dx, pts[0].dy);
  for (int i = 1; i < pts.length - 2; i++) {
    final p0 = pts[i - 1], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2];
    final d1 = (p2 - p0) * (tension / 6.0);
    final d2 = (p3 - p1) * (tension / 6.0);
    final c1 = p1 + d1, c2 = p2 - d2;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  path.close();
  return path;
}

/// 构造“保留 seam(Lc->Rc) 某一侧”的巨大半平面多边形
ui.Path _halfPlane(ui.Offset Lc, ui.Offset Rc, {required ui.Offset keepPoint, required ui.Size imgSize}) {
  final ui.Offset d = Rc - Lc;
  final double len = d.distance.clamp(1.0, 1e9);
  final ui.Offset t = ui.Offset(d.dx / len, d.dy / len); // 切向
  final ui.Offset n = ui.Offset(-t.dy, t.dx);            // 法向

  // 点积正负判断侧向（Dart 无 math.sign(double)）
  final ui.Offset v = keepPoint - Lc;
  final double dot = v.dx * n.dx + v.dy * n.dy;
  final double side = dot >= 0 ? 1.0 : -1.0;
  final ui.Offset ns = n * side;

  final double B = math.max(imgSize.width, imgSize.height) * 4.0;
  final ui.Offset L_far = Lc - t * B;
  final ui.Offset R_far = Rc + t * B;

  final p1 = L_far + ns * (B * 2.0);
  final p2 = R_far + ns * (B * 2.0);
  final p3 = R_far + ns * (B * 6.0);
  final p4 = L_far + ns * (B * 6.0);

  final path = ui.Path()
    ..moveTo(p1.dx, p1.dy)
    ..lineTo(p2.dx, p2.dy)
    ..lineTo(p3.dx, p3.dy)
    ..lineTo(p4.dx, p4.dy)
    ..close();
  return path;
}

Float64List _scaleAround(double sx, double sy, double cx, double cy) {
  final m = Float64List(16);
  m[0] = sx;  m[5] = sy;  m[10] = 1; m[15] = 1;
  m[12] = cx - sx * cx;
  m[13] = cy - sy * cy;
  return m;
}

extension _V on ui.Offset {
  ui.Offset operator +(ui.Offset o) => ui.Offset(dx + o.dx, dy + o.dy);
  ui.Offset operator -(ui.Offset o) => ui.Offset(dx - o.dx, dy - o.dy);
  ui.Offset operator *(double s)    => ui.Offset(dx * s, dy * s);
  double get distance => math.sqrt(dx*dx + dy*dy);
}
