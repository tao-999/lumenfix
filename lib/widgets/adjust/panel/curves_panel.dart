// lib/widgets/adjust/panel/curves_panel.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/curves.dart';
import '../engine/levels.dart';
import '../params/curves_params.dart';

class CurvesPanel extends StatefulWidget {
  const CurvesPanel({
    super.key,
    required this.image,        // 用于直方图 / Auto
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final ui.Image? image; // 可空：无图时隐藏直方图/Auto
  final CurvesParams value;
  final ValueChanged<CurvesParams> onChanged;
  final VoidCallback onCommit;

  @override
  State<CurvesPanel> createState() => _CurvesPanelState();
}

class _CurvesPanelState extends State<CurvesPanel> {
  LevelsChannel _channel = LevelsChannel.rgb;
  CurveMode _mode = CurveMode.spline;

  // 直方图
  List<int>? _hist; int _histTotal = 0; bool _loadingHist = false;

  // 选中点（在当前通道 points 的索引）
  int? _selIdx;
  final _xCtl = TextEditingController();
  final _yCtl = TextEditingController();
  final _xFocus = FocusNode();
  final _yFocus = FocusNode();

  List<Offset> get _pts {
    final v = widget.value;
    switch (_channel) {
      case LevelsChannel.rgb:   return v.master.points;
      case LevelsChannel.red:   return v.r.points;
      case LevelsChannel.green: return v.g.points;
      case LevelsChannel.blue:  return v.b.points;
    }
  }

  void _setPts(List<Offset> p) {
    final v = widget.value;
    CurvesParams nv;
    switch (_channel) {
      case LevelsChannel.rgb:   nv = v.copyWith(master: v.master.copyWith(points: p)); break;
      case LevelsChannel.red:   nv = v.copyWith(r: v.r.copyWith(points: p)); break;
      case LevelsChannel.green: nv = v.copyWith(g: v.g.copyWith(points: p)); break;
      case LevelsChannel.blue:  nv = v.copyWith(b: v.b.copyWith(points: p)); break;
    }
    widget.onChanged(nv);
  }

  Future<void> _loadHistogram() async {
    if (widget.image == null) return;
    setState(() => _loadingHist = true);
    final res = await LevelsEngine.computeHistogram(widget.image!, channel: _channel, sampleStep: 2);
    setState(() {
      _hist = res.bins;
      _histTotal = res.total;
      _loadingHist = false;
    });
  }

  Future<void> _runAuto() async {
    if (widget.image == null) return;
    final pts = await CurvesEngine.autoCurve(widget.image!, _channel);
    _setPts(pts);
    widget.onCommit();
    await _loadHistogram();
    _syncEditors();
  }

  void _resetCurve() {
    final base = <Offset>[const Offset(0, 0), const Offset(1, 1)];
    _setPts(base);
    _onSelectPoint(null);
    widget.onCommit();
    _syncEditors();
  }

  @override
  void initState() {
    super.initState();
    _loadHistogram();
    _syncEditors();
  }

  @override
  void didUpdateWidget(covariant CurvesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _loadHistogram();
    _syncEditors();
  }

  @override
  void dispose() {
    _xCtl.dispose();
    _yCtl.dispose();
    _xFocus.dispose();
    _yFocus.dispose();
    super.dispose();
  }

  void _onSelectPoint(int? idx) {
    setState(() => _selIdx = idx);
    _syncEditors();
  }

  void _syncEditors() {
    // 正在编辑时不要回填
    if (_xFocus.hasFocus || _yFocus.hasFocus) return;

    final pts = _pts;
    if (_selIdx == null || _selIdx! < 0 || _selIdx! >= pts.length) {
      _xCtl.text = '';
      _yCtl.text = '';
      return;
    }
    final p = pts[_selIdx!];
    _xCtl.text = (p.dx * 255).round().toString();
    _yCtl.text = (p.dy * 255).round().toString();
  }

  /// 输入阶段允许为空；提交阶段强校验并写回
  void _applyEditors({bool commit = false, bool allowEmpty = false}) {
    final pts = List<Offset>.from(_pts);
    if (_selIdx == null || _selIdx! < 0 || _selIdx! >= pts.length) return;

    final xText = _xCtl.text.trim();
    final yText = _yCtl.text.trim();

    if (allowEmpty && (xText.isEmpty || yText.isEmpty)) {
      setState(() {}); // 仅重绘高亮等
      return;
    }

    final xi0 = int.tryParse(xText);
    final yi0 = int.tryParse(yText);
    if (xi0 == null || yi0 == null) return;

    int xi = xi0.clamp(0, 255);
    int yi = yi0.clamp(0, 255);

    // X 约束：端点锁 X，非端点确保单调
    if (!(_selIdx == 0 || _selIdx == pts.length - 1)) {
      final left  = ((pts[_selIdx! - 1].dx * 255).round()) + 1;
      final right = ((pts[_selIdx! + 1].dx * 255).round()) - 1;
      xi = xi.clamp(left, right);
    }

    final nx = (_selIdx == 0) ? 0.0 : (_selIdx == pts.length - 1) ? 1.0 : xi / 255.0;
    final ny = yi / 255.0;

    pts[_selIdx!] = Offset(nx, ny);
    _setPts(pts);

    if (commit) widget.onCommit();
    setState(() {});
  }

  void _deleteSelected() {
    final pts = List<Offset>.from(_pts);
    if (_selIdx == null) return;
    final i = _selIdx!;
    if (i <= 0 || i >= pts.length - 1) return; // 端点不删
    pts.removeAt(i);
    _setPts(pts);
    _onSelectPoint(null);
    widget.onCommit();
  }

  @override
  Widget build(BuildContext context) {
    final pts = _pts;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶栏：通道 + 模式 + Auto + 重置（可横向滚）
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                DropdownButton<LevelsChannel>(
                  value: _channel,
                  dropdownColor: const Color(0xFF1E1E1E),
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: LevelsChannel.rgb,   child: Text('RGB')),
                    DropdownMenuItem(value: LevelsChannel.red,   child: Text('红色')),
                    DropdownMenuItem(value: LevelsChannel.green, child: Text('绿色')),
                    DropdownMenuItem(value: LevelsChannel.blue,  child: Text('蓝色')),
                  ],
                  onChanged: (c) {
                    setState(() => _channel = c ?? LevelsChannel.rgb);
                    _loadHistogram();
                    _onSelectPoint(null);
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<CurveMode>(
                  value: _mode,
                  dropdownColor: const Color(0xFF1E1E1E),
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: CurveMode.spline, child: Text('Spline')),
                    DropdownMenuItem(value: CurveMode.linear, child: Text('Linear')),
                  ],
                  onChanged: (m) => setState(() => _mode = m ?? CurveMode.spline),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _loadingHist ? null : _runAuto,
                  icon: _loadingHist
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Auto'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _resetCurve,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重置'),
                ),
                if (_selIdx != null) ...[
                  const SizedBox(width: 12),
                  const Text('点:', style: TextStyle(color: Colors.white54)),
                  const SizedBox(width: 4),
                  Text('$_selIdx', style: const TextStyle(color: Colors.white54)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 曲线图：抢占手势，阻止冒泡到父级滚动
          SizedBox(
            height: 220,
            width: double.infinity,
            child: _CurvesGraph(
              mode: _mode,
              points: pts,
              histogram: _hist,
              selectedIndex: _selIdx,
              onSelect: _onSelectPoint,
              onChanged: (p) { _setPts(p); setState(() {}); _syncEditors(); },
              onCommit: () { widget.onCommit(); _syncEditors(); },
            ),
          ),

          const SizedBox(height: 8),

          // 精确输入：X(in)/Y(out) + 删除（初始化禁用；选中才启用）
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _NumberBox(
                label: 'X (in)',
                controller: _xCtl,
                focusNode: _xFocus,
                enabled: _selIdx != null && _selIdx! > 0 && _selIdx! < _pts.length - 1, // 非端点可改 X
                onSubmitted: (_) => _applyEditors(commit: true),
                onChanged: (_) => _applyEditors(allowEmpty: true),
              ),
              _NumberBox(
                label: 'Y (out)',
                controller: _yCtl,
                focusNode: _yFocus,
                enabled: _selIdx != null, // 端点允许改 Y
                onSubmitted: (_) => _applyEditors(commit: true),
                onChanged: (_) => _applyEditors(allowEmpty: true),
              ),
              TextButton.icon(
                onPressed: (_selIdx != null && _selIdx! > 0 && _selIdx! < _pts.length - 1)
                    ? _deleteSelected
                    : null,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除点'),
              ),
            ],
          )
        ],
      ),
    );
  }
}

/// ========================
/// 图形控件：曲线 + 直方图 + 交互
/// ========================
class _CurvesGraph extends StatefulWidget {
  const _CurvesGraph({
    required this.mode,
    required this.points,
    required this.histogram,
    required this.onChanged,
    required this.onCommit,
    required this.selectedIndex,
    required this.onSelect,
  });

  final CurveMode mode;
  final List<Offset> points;      // 0..1，包含端点
  final List<int>? histogram;     // 256 桶，可空
  final ValueChanged<List<Offset>> onChanged;
  final VoidCallback onCommit;

  final int? selectedIndex;
  final ValueChanged<int?> onSelect;

  @override
  State<_CurvesGraph> createState() => _CurvesGraphState();
}

class _CurvesGraphState extends State<_CurvesGraph> {
  static const double _dotRadius = 7.5;  // 控制点视觉半径（更好拖）
  static const double _hitRadius = 20.0; // 命中半径（更好点中）

  late List<Offset> _pts;
  int? _dragIndex;

  @override
  void initState() {
    super.initState();
    _pts = List<Offset>.from(widget.points);
  }

  @override
  void didUpdateWidget(covariant _CurvesGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _pts = List<Offset>.from(widget.points);
    }
  }

  Rect _graphRect(Size size) {
    const pad = 8.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2 - 16; // 预留底部文本区
    return Rect.fromLTWH(pad, pad, w, h);
  }

  Offset _toScreen(Rect r, Offset p) => Offset(r.left + p.dx * r.width, r.bottom - p.dy * r.height);
  Offset _fromScreen(Rect r, Offset s) => Offset(
    ((s.dx - r.left) / r.width).clamp(0.0, 1.0),
    (1.0 - (s.dy - r.top) / r.height).clamp(0.0, 1.0),
  );

  int _hitTest(Rect r, Offset pos) {
    for (int i = 0; i < _pts.length; i++) {
      final p = _toScreen(r, _pts[i]);
      if ((p - pos).distance <= _hitRadius) return i; // 命中小圈圈
    }
    return -1;
  }

  int _insertPoint(Rect r, Offset pos) {
    final p = _fromScreen(r, pos);
    int idx = 0;
    while (idx < _pts.length && _pts[idx].dx < p.dx) idx++;
    if (idx == 0) idx = 1;
    if (idx == _pts.length) idx = _pts.length - 1;
    _pts.insert(idx, p);
    widget.onChanged(List<Offset>.from(_pts));
    return idx;
  }

  void _removePoint(int i) {
    if (i <= 0 || i >= _pts.length - 1) return; // 不删端点
    _pts.removeAt(i);
    widget.onChanged(List<Offset>.from(_pts));
  }

  void _movePoint(Rect r, int i, Offset pos) {
    final p = _fromScreen(r, pos);
    double x = p.dx, y = p.dy;
    if (i == 0) { x = 0; }                          // 端点锁 X
    if (i == _pts.length - 1) { x = 1; }
    final leftX  = i > 0 ? _pts[i - 1].dx + 1e-4 : 0.0; // 单调不降
    final rightX = i < _pts.length - 1 ? _pts[i + 1].dx - 1e-4 : 1.0;
    x = x.clamp(leftX, rightX);
    _pts[i] = Offset(x, y);
    widget.onChanged(List<Offset>.from(_pts));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // ✅ 吃掉命中区域，避免事件冒泡
        onPanDown: (_) {},                // ✅ 提前入场，占住手势竞技场
        onTapDown: (_) {},                // ✅ 防止父级收到 tap
        onDoubleTapDown: (d) {
          final r = _graphRect(context.size!);
          final i = _hitTest(r, d.localPosition);
          if (i >= 0) { _removePoint(i); widget.onSelect(null); }
        },
        onLongPressStart: (d) {
          final r = _graphRect(context.size!);
          final i = _hitTest(r, d.localPosition);
          if (i >= 0) { _removePoint(i); widget.onSelect(null); }
        },
        onTapUp: (d) {
          final r = _graphRect(context.size!);
          final i = _hitTest(r, d.localPosition);
          if (i == -1) {
            final idx = _insertPoint(r, d.localPosition);
            widget.onSelect(idx);
          } else {
            widget.onSelect(i);
          }
        },
        onPanStart: (d) {
          final r = _graphRect(context.size!);
          final i = _hitTest(r, d.localPosition);
          if (i >= 0) { _dragIndex = i; widget.onSelect(i); }
        },
        onPanUpdate: (d) {
          if (_dragIndex == null) return;
          final r = _graphRect(context.size!);
          _movePoint(r, _dragIndex!, d.localPosition);
          setState(() {});
        },
        onPanEnd: (_) {
          _dragIndex = null;
          widget.onCommit();
        },
        child: CustomPaint(
          painter: _CurvesPainter(
            mode: widget.mode,
            points: _pts,
            histogram: widget.histogram,
            selectedIndex: widget.selectedIndex,
          ),
        ),
      ),
    );
  }
}

class _CurvesPainter extends CustomPainter {
  _CurvesPainter({
    required this.mode,
    required this.points,
    required this.histogram,
    required this.selectedIndex,
  });
  final CurveMode mode;
  final List<Offset> points;     // 原始点（含端点）
  final List<int>? histogram;
  final int? selectedIndex;

  static const double _dotRadius = 7.5;

  Rect _graphRect(Size size) {
    const pad = 8.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2 - 16;
    return Rect.fromLTWH(pad, pad, w, h);
  }

  Offset _toScreen(Rect r, Offset p) => Offset(r.left + p.dx * r.width, r.bottom - p.dy * r.height);

  @override
  void paint(Canvas canvas, Size size) {
    final r = _graphRect(size);

    // 背板
    final bg = Paint()..color = const Color(0xFF1B1B1B);
    canvas.drawRect(r, bg);
    // 网格
    final grid = Paint()..color = const Color(0x22FFFFFF)..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final x = r.left + r.width * i / 4;
      final y = r.top + r.height * i / 4;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), grid);
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
    }

    // 直方图
    if (histogram != null && histogram!.isNotEmpty) {
      final maxv = histogram!.reduce(math.max).toDouble().clamp(1.0, double.infinity);
      final barW = r.width / 256.0;
      final pHist = Paint()..color = const Color(0x33FFFFFF);
      for (int i = 0; i < 256; i++) {
        final v = histogram![i] / maxv;
        final x = r.left + i * barW;
        final h = r.height * v;
        canvas.drawRect(Rect.fromLTWH(x, r.bottom - h, barW, h), pHist);
      }
    }

    // 曲线
    final ptsN = CurvesEngine.normalizePoints(points);
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i <= 64; i++) {
      final x = i / 64.0;
      final y = _eval(ptsN, x, mode);
      final p = _toScreen(r, Offset(x, y));
      if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);

    // 选中点十字辅助线
    if (selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < points.length) {
      final sp = _toScreen(r, points[selectedIndex!]);
      final guide = Paint()..color = const Color(0x44FFFFFF)..strokeWidth = 1;
      canvas.drawLine(Offset(sp.dx, r.top), Offset(sp.dx, r.bottom), guide);
      canvas.drawLine(Offset(r.left, sp.dy), Offset(r.right, sp.dy), guide);
    }

    // 控制点
    final dotFill = Paint()..color = Colors.white;
    final dotSel  = Paint()..color = const Color(0xFF00E5FF);
    final dotStroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < points.length; i++) {
      final s = _toScreen(r, points[i]);
      canvas.drawCircle(s, _dotRadius, (selectedIndex == i) ? dotSel : dotFill);
      canvas.drawCircle(s, _dotRadius, dotStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvesPainter old) {
    return old.mode != mode ||
        old.points != points ||
        old.histogram != histogram ||
        old.selectedIndex != selectedIndex;
  }

  // 评估曲线 y(x)（用规范化点）
  double _eval(List<Offset> pts, double x, CurveMode mode) {
    if (mode == CurveMode.linear) {
      int seg = 0;
      while (seg < pts.length - 2 && x > pts[seg + 1].dx) seg++;
      final a = pts[seg], b = pts[seg + 1];
      final t = ((x - a.dx) / (b.dx - a.dx)).clamp(0.0, 1.0);
      return (a.dy + (b.dy - a.dy) * t).clamp(0.0, 1.0);
    } else {
      final n = pts.length - 1;
      final h = List<double>.filled(n, 0);
      final m = List<double>.filled(n, 0);
      for (int i = 0; i < n; i++) {
        final dx = pts[i + 1].dx - pts[i].dx;
        h[i] = dx;
        m[i] = (pts[i + 1].dy - pts[i].dy) / dx;
      }
      final tang = List<double>.filled(n + 1, 0);
      tang[0] = m[0];
      tang[n] = m[n - 1];
      for (int i = 1; i < n; i++) {
        if (m[i - 1] * m[i] <= 0) {
          tang[i] = 0;
        } else {
          final w1 = 1 + h[i] / (h[i - 1] + 1e-9);
          final w2 = 1 + h[i - 1] / (h[i] + 1e-9);
          tang[i] = (w1 + w2) / (w1 / m[i - 1] + w2 / m[i]);
        }
      }
      if (tang[0].abs() > 3 * m[0].abs()) tang[0] = 3 * m[0];
      if (tang[n].abs() > 3 * m[n - 1].abs()) tang[n] = 3 * m[n - 1];

      int seg = 0;
      while (seg < n - 1 && x > pts[seg + 1].dx) seg++;
      final x0 = pts[seg].dx, x1 = pts[seg + 1].dx;
      final y0 = pts[seg].dy, y1 = pts[seg + 1].dy;
      final hseg = x1 - x0;
      final s = ((x - x0) / hseg).clamp(0.0, 1.0);

      final h00 = (2 * s * s * s - 3 * s * s + 1);
      final h10 = (s * s * s - 2 * s * s + s);
      final h01 = (-2 * s * s * s + 3 * s * s);
      final h11 = (s * s * s - s * s);
      final y = h00 * y0 + h10 * hseg * tang[seg] + h01 * y1 + h11 * hseg * tang[seg + 1];
      return y.clamp(0.0, 1.0);
    }
  }
}

/// ====== 小组件：数字输入框 (0..255) ======
class _NumberBox extends StatelessWidget {
  const _NumberBox({
    required this.label,
    required this.controller,
    required this.enabled,
    this.onSubmitted,
    this.onChanged,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          TextField(
            focusNode: focusNode,
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}$')),
            ],
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              hintText: enabled ? '0..255' : '',
              hintStyle: const TextStyle(color: Colors.white30),
              suffixIcon: enabled
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 16, color: Colors.white38),
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');   // 通知上层：现在是空
                },
              )
                  : null,
            ),
            onSubmitted: onSubmitted,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
