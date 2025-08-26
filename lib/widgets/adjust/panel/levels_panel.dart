import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../common.dart';
import '../engine/levels.dart';
import '../params/levels_params.dart';

class LevelsPanel extends StatefulWidget {
  const LevelsPanel({
    super.key,
    required this.image,     // ⬅️ 新增：用于 Auto 做直方图
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final ui.Image image;
  final LevelsParams value;
  final ValueChanged<LevelsParams> onChanged;
  final VoidCallback onCommit;

  @override
  State<LevelsPanel> createState() => _LevelsPanelState();
}

class _LevelsPanelState extends State<LevelsPanel> {
  LevelsChannel _channel = LevelsChannel.rgb;
  bool _busy = false;

  Future<void> _runAuto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final hist = await LevelsEngine.computeHistogram(widget.image, channel: _channel, sampleStep: 2);
      final out = LevelsEngine.autoFromHistogram(hist);
      widget.onChanged(out);
      widget.onCommit();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：通道 + Auto
          Row(
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
                onChanged: (c) => setState(() => _channel = c ?? LevelsChannel.rgb),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _runAuto,
                icon: _busy
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Auto'),
              ),
              const Spacer(),
              Text('通道: ${_labelOf(_channel)}', style: const TextStyle(color: Colors.white54)),
            ],
          ),

          const SizedBox(height: 8),

          // 输入：黑 / Gamma / 白
          CommonSlider(
            label: '输入黑',
            value: v.inBlack.toDouble(),
            min: 0, max: 255, neutral: 0,
            onChanged: (x) => widget.onChanged(v.copyWith(inBlack: x.round())),
            onCommit: widget.onCommit,
          ),
          CommonSlider(
            label: 'Gamma',
            value: v.gamma,
            min: 0.10, max: 3.00, neutral: 1.00,
            decimals: 2,
            onChanged: (x) => widget.onChanged(v.copyWith(gamma: x)),
            onCommit: widget.onCommit,
          ),
          CommonSlider(
            label: '输入白',
            value: v.inWhite.toDouble(),
            min: 0, max: 255, neutral: 255,
            onChanged: (x) => widget.onChanged(v.copyWith(inWhite: x.round())),
            onCommit: widget.onCommit,
          ),

          const SizedBox(height: 6),

          // 输出：黑 / 白
          CommonSlider(
            label: '输出黑',
            value: v.outBlack.toDouble(),
            min: 0, max: 255, neutral: 0,
            onChanged: (x) => widget.onChanged(v.copyWith(outBlack: x.round())),
            onCommit: widget.onCommit,
          ),
          CommonSlider(
            label: '输出白',
            value: v.outWhite.toDouble(),
            min: 0, max: 255, neutral: 255,
            onChanged: (x) => widget.onChanged(v.copyWith(outWhite: x.round())),
            onCommit: widget.onCommit,
          ),

          // 快捷设定（黑/中灰/白）
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('快捷：', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 6),
              _swatch(Colors.black, () {
                widget.onChanged(v.copyWith(inBlack: 0));
                widget.onCommit();
              }),
              _swatch(const Color(0xFF7F7F7F), () {
                // 中灰：调整 gamma 让中点靠近 0.5
                final ib = v.inBlack.toDouble();
                final iw = v.inWhite.toDouble();
                final mid = ((ib + iw) / 2).clamp(1.0, 254.0);
                final t = ((mid - ib) / (iw - ib)).clamp(1e-5, 1.0 - 1e-5);
                final gamma = (0.5).log() / t.log();
                widget.onChanged(v.copyWith(gamma: gamma.clamp(0.10, 3.0)));
                widget.onCommit();
              }),
              _swatch(Colors.white, () {
                widget.onChanged(v.copyWith(inWhite: 255));
                widget.onCommit();
              }),
            ],
          ),
        ],
      ),
    );
  }

  String _labelOf(LevelsChannel c) {
    switch (c) {
      case LevelsChannel.rgb: return 'RGB';
      case LevelsChannel.red: return '红';
      case LevelsChannel.green: return '绿';
      case LevelsChannel.blue: return '蓝';
    }
  }

  Widget _swatch(Color c, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: c, borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.white24),
        ),
      ),
    ),
  );
}

// 简单 log 扩展；也可用 dart:math
extension on double {
  double log() => (this <= 0) ? -100.0 : _ln(this);
}
double _ln(double x) {
  const int n = 12;
  final y = (x - 1) / (x + 1);
  double y2 = y * y, sum = 0.0, term = y;
  for (int k = 1; k <= n; k += 2) {
    sum += term / k;
    term *= y2;
  }
  return 2 * sum;
}
