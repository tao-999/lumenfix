import 'package:flutter/material.dart';
import '../common.dart';
import '../params/color_balance_params.dart';

enum _Tone { shadows, mids, highs }

class ColorBalancePanel extends StatefulWidget {
  const ColorBalancePanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final ColorBalanceParams value;
  final ValueChanged<ColorBalanceParams> onChanged;
  final VoidCallback onCommit;

  @override
  State<ColorBalancePanel> createState() => _ColorBalancePanelState();
}

class _ColorBalancePanelState extends State<ColorBalancePanel> {
  _Tone _current = _Tone.shadows;

  @override
  Widget build(BuildContext context) {
    final wheel = _wheelOf(_current);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // —— Tone 下拉 —— //
          _SectionCard(
            title: '范围',
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_Tone>(
                      value: _current,
                      isExpanded: true,
                      onChanged: (v) => setState(() => _current = v ?? _current),
                      items: const [
                        DropdownMenuItem(
                          value: _Tone.shadows,
                          child: Text('阴影', style: TextStyle(color: Colors.white)),
                        ),
                        DropdownMenuItem(
                          value: _Tone.mids,
                          child: Text('中间调', style: TextStyle(color: Colors.white)),
                        ),
                        DropdownMenuItem(
                          value: _Tone.highs,
                          child: Text('高光', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                      dropdownColor: const Color(0xFF1E1E1E),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // —— 三个滑条 —— //
          _SectionCard(
            title: '调整',
            child: Column(
              children: [
                CommonSlider(
                  label: '青色 - 红色',
                  value: wheel.cr,
                  min: -100, max: 100, neutral: 0,
                  onChanged: (v) => _setWheel(_current, wheel.copyWith(cr: v)),
                  onCommit: widget.onCommit,
                ),
                CommonSlider(
                  label: '品红 - 绿色',
                  value: wheel.mg,
                  min: -100, max: 100, neutral: 0,
                  onChanged: (v) => _setWheel(_current, wheel.copyWith(mg: v)),
                  onCommit: widget.onCommit,
                ),
                CommonSlider(
                  label: '黄色 - 蓝色',
                  value: wheel.yb,
                  min: -100, max: 100, neutral: 0,
                  onChanged: (v) => _setWheel(_current, wheel.copyWith(yb: v)),
                  onCommit: widget.onCommit,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // —— 保留明度 —— //
          Row(
            children: [
              Checkbox(
                value: widget.value.preserveLuminosity,
                onChanged: (on) => widget.onChanged(
                  widget.value.copyWith(preserveLuminosity: on ?? true),
                ),
              ),
              const SizedBox(width: 6),
              const Text('保留明度', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  ColorBalanceWheel _wheelOf(_Tone t) {
    switch (t) {
      case _Tone.shadows: return widget.value.shadows;
      case _Tone.mids:    return widget.value.mids;
      case _Tone.highs:   return widget.value.highs;
    }
  }

  void _setWheel(_Tone t, ColorBalanceWheel w) {
    switch (t) {
      case _Tone.shadows:
        widget.onChanged(widget.value.copyWith(shadows: w));
        break;
      case _Tone.mids:
        widget.onChanged(widget.value.copyWith(mids: w));
        break;
      case _Tone.highs:
        widget.onChanged(widget.value.copyWith(highs: w));
        break;
    }
  }
}

/* ===== 小卡片 ===== */
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
