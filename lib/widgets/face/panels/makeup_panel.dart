import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'panel_common.dart';
import '../engine/face_regions.dart';

class MakeupPanel extends StatefulWidget {
  const MakeupPanel({
    super.key,
    required this.params,
    required this.onChanged,
    required this.regions,
    required this.fitRect,
    required this.imageWidth,
    required this.imageHeight,
    this.onOverlayChanged, // 把需要叠加的 overlay 交给上层
  });

  final FaceParams params;
  final ValueChanged<FaceParams> onChanged;

  final FaceRegions? regions;
  final Rect fitRect;
  final int imageWidth;
  final int imageHeight;

  final ValueChanged<Widget?>? onOverlayChanged;

  @override
  State<MakeupPanel> createState() => _MakeupPanelState();
}

class _MakeupPanelState extends State<MakeupPanel> {
  late FaceParams _p;

  @override
  void initState() {
    super.initState();
    _p = widget.params;
    _emitOverlay();
  }

  @override
  void didUpdateWidget(covariant MakeupPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.regions != widget.regions ||
        oldWidget.fitRect != widget.fitRect ||
        oldWidget.imageWidth != widget.imageWidth ||
        oldWidget.imageHeight != widget.imageHeight) {
      _emitOverlay();
    }
  }

  void _emitOverlay() {
    final r = widget.regions;
    if (r?.lipsPath == null ||
        widget.imageWidth <= 0 ||
        widget.imageHeight <= 0 ||
        widget.fitRect.isEmpty) {
      // 延后清空，避免父级 build 中 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onOverlayChanged?.call(null);
      });
      return;
    }

    final overlay = CustomPaint(
      painter: _DashedPathPainter(
        pathInImageSpace: r!.lipsPath!,
        fitRect: widget.fitRect,
        imgW: widget.imageWidth,
        imgH: widget.imageHeight,
        color: Colors.white,
        strokeWidth: 2,
        dash: 6,
        gap: 4,
      ),
    );

    // 延后上报 overlay，避免父级 build 中 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onOverlayChanged?.call(overlay);
    });
  }

  void _updateColor(Color c) {
    setState(() => _p = _p.copyWith(lipColor: c));
    widget.onChanged(_p);
  }

  void _updateAlpha(double a) {
    setState(() => _p = _p.copyWith(lipAlpha: a));
    widget.onChanged(_p);
  }

  @override
  Widget build(BuildContext context) {
    const swatches = [
      Color(0xFFEB4E5B), // 樱桃红
      Color(0xFFF08A7E), // 豆沙
      Color(0xFFD94A86), // 玫红
      Color(0xFFB6343B), // 正红
      Color(0xFF8E2A2A), // 复古砖
      Color(0xFFF2A2B6), // 少女粉
    ];

    return Column(
      children: [
        const SizedBox(height: 10),
        const Text('唇彩', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final c in swatches)
              GestureDetector(
                onTap: () => _updateColor(c),
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _p.lipColor.value == c.value ? Colors.white : Colors.white24,
                      width: _p.lipColor.value == c.value ? 2 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.opacity, size: 18, color: Colors.white70),
              Expanded(
                child: Slider(
                  value: _p.lipAlpha.clamp(0, 1),
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: (_p.lipAlpha * 100).toStringAsFixed(0),
                  onChanged: _updateAlpha,
                ),
              ),
              Text('${(_p.lipAlpha * 100).round()}%', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// —— 将图像坐标 Path 映射到屏幕坐标并绘制虚线 —— ///
class _DashedPathPainter extends CustomPainter {
  _DashedPathPainter({
    required this.pathInImageSpace,
    required this.fitRect,
    required this.imgW,
    required this.imgH,
    this.color = Colors.white,
    this.strokeWidth = 2.0,
    this.dash = 6.0,
    this.gap = 4.0,
  });

  final ui.Path pathInImageSpace;
  final Rect fitRect;
  final int imgW, imgH;
  final Color color;
  final double strokeWidth, dash, gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (fitRect.isEmpty || imgW <= 0 || imgH <= 0) return;

    final m = Matrix4.identity()
      ..translate(fitRect.left, fitRect.top)
      ..scale(fitRect.width / imgW, fitRect.height / imgH);
    final ui.Path mapped = pathInImageSpace.transform(m.storage);

    final dashed = _dashPath(mapped, dash: dash, gap: gap);

    final p = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withOpacity(0.95);

    canvas.drawPath(dashed, p);

    p
      ..strokeWidth = strokeWidth + 2
      ..color = color.withOpacity(0.35)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2);
    canvas.drawPath(dashed, p);
  }

  @override
  bool shouldRepaint(covariant _DashedPathPainter old) {
    return old.pathInImageSpace != pathInImageSpace ||
        old.fitRect != fitRect ||
        old.imgW != imgW ||
        old.imgH != imgH ||
        old.color != color ||
        old.strokeWidth != strokeWidth ||
        old.dash != dash ||
        old.gap != gap;
  }

  ui.Path _dashPath(ui.Path src, {required double dash, required double gap}) {
    final dst = ui.Path();
    for (final metric in src.computeMetrics()) {
      final double length = metric.length;
      double d = 0.0;
      bool draw = true;
      while (d < length) {
        final double seg = draw ? dash : gap;
        final double next = (d + seg).clamp(0.0, length).toDouble(); // ← num→double
        if (draw) {
          dst.addPath(metric.extractPath(d, next), ui.Offset.zero);
        }
        d = next;
        draw = !draw;
      }
    }
    return dst;
  }
}
