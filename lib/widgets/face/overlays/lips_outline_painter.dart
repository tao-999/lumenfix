// 📄 lib/widgets/face/overlays/lips_outline_painter.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../engine/face_regions.dart';

/// 画“唇缘细线”（两条开放折线）：上唇弧 + 下唇弧
/// 改进点：
/// 1) 用主轴投影在外唇 Path 上找“左右嘴角”，抗头部旋转；
/// 2) 只画开放折线（不 close），不会出现嵌套闭合圈；
/// 3) strokeScreenPx=0.5（屏幕像素），换算到图像坐标，真正的发丝线；
/// 4) 可选平滑成曲线（Catmull-Rom）。
class LipsOutlinePainter extends CustomPainter {
  LipsOutlinePainter({
    required this.regions,
    required this.imageSize,     // 原图像素
    required this.fitRect,       // 预览 contain 区域
    this.devicePixelRatio = 1.0, // 传 MediaQuery.of(context).devicePixelRatio
    this.color = const Color(0xFFFFFFFF),
    this.strokeScreenPx = 0.5,   // 目标屏幕像素宽度（0.5 = 发丝线）
    this.smooth = true,          // 是否平滑
    this.debug = false,          // 是否画调试点
  });

  final FaceRegions? regions;
  final Size imageSize;
  final Rect fitRect;
  final double devicePixelRatio;
  final Color color;
  final double strokeScreenPx;
  final bool smooth;
  final bool debug;

  @override
  void paint(Canvas canvas, Size size) {
    final r = regions;
    final outer = r?.lipsOuterPath ?? r?.lipsPath;
    if (r == null || outer == null || outer.getBounds().isEmpty || fitRect.isEmpty) return;

    // 计算图像→预览的等比缩放
    final sx = fitRect.width  / imageSize.width;
    final sy = fitRect.height / imageSize.height;
    final s  = sx < sy ? sx : sy;
    if (s <= 0) return;

    // 按屏幕像素换算到“图像坐标系”的线宽（避免被强制加粗）
    final strokeInImage = (strokeScreenPx / s);

    // 采样外唇曲线（均匀弧长采样）
    final pmList = outer.computeMetrics().toList();
    if (pmList.isEmpty) return;
    final pm = pmList.first;
    final int steps = math.max(320, (pm.length / 1.2).round());
    final sample = <_Samp>[];
    for (int i = 0; i <= steps; i++) {
      final d = pm.length * (i / steps);
      final t = pm.getTangentForOffset(d);
      if (t == null) continue;
      sample.add(_Samp(d, t.position));
    }
    if (sample.length < 4) return;

    // —— 用主轴投影找两端（左右嘴角，更抗旋转）——
    // 1) 计算均值与协方差
    double mx = 0, my = 0;
    for (final p in sample) { mx += p.pos.dx; my += p.pos.dy; }
    mx /= sample.length; my /= sample.length;
    double sxx = 0, sxy = 0, syy = 0;
    for (final p in sample) {
      final dx = p.pos.dx - mx, dy = p.pos.dy - my;
      sxx += dx*dx; sxy += dx*dy; syy += dy*dy;
    }
    // 2) 求协方差矩阵最大特征向量（2x2 手算）
    final tr = sxx + syy;
    final det = sxx*syy - sxy*sxy;
    final tmp = math.sqrt(math.max(0.0, tr*tr/4 - det));
    final l1 = tr/2 + tmp; // 最大特征值
    // (A - λI)v = 0 => [sxx-λ, sxy; sxy, syy-λ] v = 0
    ui.Offset axis;
    if (sxy.abs() > 1e-6) {
      axis = ui.Offset(l1 - syy, sxy);
    } else {
      axis = (sxx >= syy) ? const ui.Offset(1,0) : const ui.Offset(0,1);
    }
    final nrm = axis.distance;
    if (nrm > 0) axis = axis / nrm;
    // 3) 所有点沿 axis 做投影，找最小/最大 => 两个嘴角
    double minProj = double.infinity, maxProj = -double.infinity;
    _Samp? leftC, rightC;
    for (final p in sample) {
      final v = ui.Offset(p.pos.dx - mx, p.pos.dy - my);
      final proj = v.dx*axis.dx + v.dy*axis.dy;
      if (proj < minProj) { minProj = proj; leftC  = p; }
      if (proj > maxProj) { maxProj = proj; rightC = p; }
    }
    if (leftC == null || rightC == null) return;

    // —— 生成两条从“左嘴角到右嘴角”的弧段 —— //
    final arcA = _sampleArcBetween(pm, leftC!.dist, rightC!.dist); // 正向
    final arcB = _sampleArcBetween(pm, rightC!.dist, leftC!.dist); // 绕回另一半
    if (arcA.length < 2 || arcB.length < 2) return;

    // —— 平均 y 判断上下（图像坐标下 y 越小越靠上）——
    final avgYA = _avgY(arcA);
    final avgYB = _avgY(arcB);
    List<ui.Offset> upperPts = avgYA <= avgYB ? arcA : arcB;
    List<ui.Offset> lowerPts = avgYA <= avgYB ? arcB : arcA;

    // 平滑（可选）
    final ui.Path upPath = smooth ? _catmullRom(upperPts) : _polyline(upperPts);
    final ui.Path loPath = smooth ? _catmullRom(lowerPts) : _polyline(lowerPts);

    // 画：等同图片展示的几何
    canvas.save();
    canvas.clipRect(fitRect); // 防溢出
    canvas.translate(fitRect.left, fitRect.top);
    canvas.scale(s, s);

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeInImage
      ..color = color
      ..isAntiAlias = true
      ..strokeJoin = StrokeJoin.round
      ..strokeCap  = StrokeCap.round;

    canvas.drawPath(upPath, p);
    canvas.drawPath(loPath, p);

    if (debug) {
      final dp = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFF00FF);
      canvas.drawCircle(leftC!.pos, 2.0 / s, dp);
      canvas.drawCircle(rightC!.pos, 2.0 / s, dp);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LipsOutlinePainter old) {
    return old.regions != regions ||
        old.imageSize != imageSize ||
        old.fitRect != fitRect ||
        old.devicePixelRatio != devicePixelRatio ||
        old.color != color ||
        old.strokeScreenPx != strokeScreenPx ||
        old.smooth != smooth ||
        old.debug != debug;
  }

  // === helpers ===

  List<ui.Offset> _sampleArcBetween(ui.PathMetric pm, double start, double end) {
    final L = pm.length;
    double seg = (end >= start) ? (end - start) : (L - start + end);
    seg = seg.clamp(1.0, L);
    final int steps = math.max(64, (seg / L * 400).round());
    final pts = <ui.Offset>[];
    for (int i = 0; i <= steps; i++) {
      double d = start + seg * (i / steps);
      if (d > L) d -= L;
      final pos = pm.getTangentForOffset(d)?.position;
      if (pos != null) pts.add(pos);
    }
    // 去掉跳变过大的点（防止 path metric 接缝处突跳）
    final cleaned = <ui.Offset>[];
    for (int i = 0; i < pts.length; i++) {
      if (i == 0 || (pts[i] - pts[i - 1]).distance <= 12.0) cleaned.add(pts[i]);
    }
    return cleaned.length >= 2 ? cleaned : pts;
  }

  double _avgY(List<ui.Offset> pts) {
    double s = 0;
    for (final p in pts) s += p.dy;
    return s / pts.length;
  }

  ui.Path _polyline(List<ui.Offset> pts) {
    final path = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path; // 不 close
  }

  /// 用 Catmull-Rom 生成顺滑曲线（开放曲线）
  ui.Path _catmullRom(List<ui.Offset> pts, {double alpha = 0.5}) {
    if (pts.length <= 2) return _polyline(pts);
    final path = ui.Path()..moveTo(pts.first.dx, pts.first.dy);
    // 端点重复，保证开放曲线首尾自然
    final p = [pts.first, ...pts, pts.last];
    for (int i = 0; i < p.length - 3; i++) {
      final p0 = p[i], p1 = p[i+1], p2 = p[i+2], p3 = p[i+3];
      // Catmull-Rom to cubic Bezier
      final c1 = p1 + (p2 - p0) * (1/6);
      final c2 = p2 - (p3 - p1) * (1/6);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }
}

class _Samp {
  const _Samp(this.dist, this.pos);
  final double dist;
  final ui.Offset pos;
}

extension _Vec on ui.Offset {
  double get distance => math.sqrt(dx*dx + dy*dy);
  ui.Offset operator +(ui.Offset o) => ui.Offset(dx + o.dx, dy + o.dy);
  ui.Offset operator -(ui.Offset o) => ui.Offset(dx - o.dx, dy - o.dy);
  ui.Offset operator *(double s)    => ui.Offset(dx * s, dy * s);
  ui.Offset operator /(double s)    => ui.Offset(dx / s, dy / s);
}
