// lib/widgets/adjust/panel/channel_mixer_panel.dart
import 'package:flutter/material.dart';
import '../common.dart';
import '../params/channel_mixer_params.dart';

class ChannelMixerPanel extends StatefulWidget {
  const ChannelMixerPanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final ChannelMixerParams value;
  final ValueChanged<ChannelMixerParams> onChanged;
  final VoidCallback onCommit;

  @override
  State<ChannelMixerPanel> createState() => _ChannelMixerPanelState();
}

class _ChannelMixerPanelState extends State<ChannelMixerPanel> {
  int _out = 0; // 0:R, 1:G, 2:B

  @override
  Widget build(BuildContext context) {
    final v = widget.value;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部：输出通道 + 单色
          Row(
            children: [
              const Text('通道:', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _out,
                onChanged: v.monochrome ? null : (i) => setState(() => _out = i ?? 0),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('红色')),
                  DropdownMenuItem(value: 1, child: Text('绿色')),
                  DropdownMenuItem(value: 2, child: Text('蓝色')),
                ],
              ),
              const SizedBox(width: 16),
              Checkbox(
                value: v.monochrome,
                onChanged: (on) {
                  widget.onChanged(v.copyWith(monochrome: on ?? false));
                  widget.onCommit();
                },
              ),
              const Text('单色', style: TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),

          // 三色系数（-200%..200%）
          _coefSlider('红色',   _getCoef(0), (nv) => _setCoef(0, nv),
              neutral: _out == 0 ? 100 : 0),
          _coefSlider('绿色',   _getCoef(1), (nv) => _setCoef(1, nv),
              neutral: _out == 1 ? 100 : 0),
          _coefSlider('蓝色',   _getCoef(2), (nv) => _setCoef(2, nv),
              neutral: _out == 2 ? 100 : 0),

          // 常量（偏置）
          _biasSlider('总量', _getBias(), _setBias),
        ],
      ),
    );
  }

  // —— 读/写：把内部 -2..2 的参数映射成 -200..200 的百分比 —— //
  double _getCoef(int comp) => widget.value.coef(_coeffRowIndex(), comp) * 100.0;
  void _setCoef(int comp, double percent) {
    final m = (percent / 100.0).clamp(-2.0, 2.0);
    widget.onChanged(widget.value.setCoef(_coeffRowIndex(), comp, m));
  }

  double _getBias() => widget.value.bias(_coeffRowIndex()) * 100.0;
  void _setBias(double percent) {
    final b = (percent / 100.0).clamp(-2.0, 2.0);
    widget.onChanged(widget.value.setBias(_coeffRowIndex(), b));
  }

  int _coeffRowIndex() {
    // 单色：用红通道那一行承载灰度系数
    return widget.value.monochrome ? 0 : _out;
  }

  Widget _coefSlider(String label, double val, ValueChanged<double> onChanged,
      {double neutral = 0}) {
    return CommonSlider(
      label: label,
      value: val,
      min: -200, max: 200, neutral: neutral,
      onChanged: onChanged,
      onCommit: widget.onCommit,
    );
  }

  Widget _biasSlider(String label, double val, ValueChanged<double> onChanged) {
    return CommonSlider(
      label: label,
      value: val,
      min: -200, max: 200, neutral: 0,
      onChanged: onChanged,
      onCommit: widget.onCommit,
    );
  }
}
