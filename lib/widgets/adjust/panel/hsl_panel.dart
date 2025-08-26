import 'package:flutter/material.dart';
import '../common.dart';
import '../params/hsl_params.dart';

/// HSL 面板（下拉选择色域 + H/S/L 滑条 + 着色）
/// 根用 Column，滚动交给外层的 ListView，避免 Vertical viewport 报错。
class HslPanel extends StatefulWidget {
  const HslPanel({
    super.key,
    required this.value,       // ✅ 统一与其他面板：value
    required this.onChanged,
    required this.onCommit,
  });

  final HslParams value;
  final ValueChanged<HslParams> onChanged;
  final VoidCallback onCommit;

  @override
  State<HslPanel> createState() => _HslPanelState();
}

class _HslPanelState extends State<HslPanel> {
  static const List<HslBand> _bands = <HslBand>[
    HslBand.master,
    HslBand.red,
    HslBand.yellow,
    HslBand.green,
    HslBand.cyan,
    HslBand.blue,
    HslBand.magenta,
  ];

  static const Map<HslBand, String> _bandLabel = {
    HslBand.master:  '全部',
    HslBand.red:     '红',
    HslBand.yellow:  '黄',
    HslBand.green:   '绿',
    HslBand.cyan:    '青',
    HslBand.blue:    '蓝',
    HslBand.magenta: '洋红',
  };

  HslBand _current = HslBand.master;

  @override
  Widget build(BuildContext context) {
    final HslBandAdjust curr =
        widget.value.bands[_current] ?? const HslBandAdjust();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // —— 色域下拉 —— //
          _SectionCard(
            title: '色域',
            child: Row(
              children: [
                const Text('选择色域', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<HslBand>(
                      value: _current,
                      isExpanded: true,
                      onChanged: (HslBand? b) {
                        if (b == null) return;
                        setState(() => _current = b);
                      },
                      items: _bands.map((b) {
                        return DropdownMenuItem<HslBand>(
                          value: b,
                          child: Text(
                            _bandLabel[b]!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
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

          // —— 当前色域：H / S / L —— //
          _SectionCard(
            title: '色相 / 饱和度 / 亮度（${_bandLabel[_current]}）',
            child: Column(
              children: [
                CommonSlider(
                  label: '色相 (°)',
                  value: curr.hueDeg,
                  min: -180, max: 180, neutral: 0,
                  onChanged: (v) => _setBand(_current, curr.copyWith(hueDeg: v)),
                  onCommit: widget.onCommit,
                ),
                CommonSlider(
                  label: '饱和度 (%)',
                  value: curr.satPercent,
                  min: -100, max: 100, neutral: 0,
                  onChanged: (v) => _setBand(_current, curr.copyWith(satPercent: v)),
                  onCommit: widget.onCommit,
                ),
                CommonSlider(
                  label: '亮度 (%)',
                  value: curr.lightPercent,
                  min: -100, max: 100, neutral: 0,
                  onChanged: (v) => _setBand(_current, curr.copyWith(lightPercent: v)),
                  onCommit: widget.onCommit,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // —— 着色 Colorize —— //
          _SectionCard(
            title: '着色 (Colorize)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RowSwitch(
                  label: '启用着色',
                  value: widget.value.colorize,
                  onChanged: (on) => _setColorize(enable: on),
                ),
                const SizedBox(height: 6),
                IgnorePointer(
                  ignoring: !widget.value.colorize,
                  child: Opacity(
                    opacity: widget.value.colorize ? 1.0 : 0.5,
                    child: Column(
                      children: [
                        CommonSlider(
                          label: '色相 (°)',
                          value: widget.value.colorizeHueDeg,
                          min: 0, max: 360, neutral: 0,
                          onChanged: (v) => _setColorize(hue: v),
                          onCommit: widget.onCommit,
                        ),
                        CommonSlider(
                          label: '饱和度 (%)',
                          value: widget.value.colorizeSatPercent,
                          min: 0, max: 100, neutral: 50, // 更接近 PS
                          onChanged: (v) => _setColorize(sat: v),
                          onCommit: widget.onCommit,
                        ),
                        CommonSlider(
                          label: '亮度 (%)',
                          value: widget.value.colorizeLightPercent,
                          min: -100, max: 100, neutral: 0,
                          onChanged: (v) => _setColorize(light: v),
                          onCommit: widget.onCommit,
                        ),
                        CommonSlider(
                          label: '羽化 (°)',
                          value: widget.value.featherDeg,
                          min: 0, max: 90, neutral: 30,
                          onChanged: (v) => _setColorize(feather: v),
                          onCommit: widget.onCommit,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ===== 内部：状态上抛 ===== */

  void _setBand(HslBand band, HslBandAdjust adj) {
    final map = Map<HslBand, HslBandAdjust>.from(widget.value.bands);
    map[band] = adj;
    widget.onChanged(widget.value.copyWith(bands: map));
  }

  void _setColorize({
    bool? enable,
    double? hue,
    double? sat,
    double? light,
    double? feather,
  }) {
    widget.onChanged(widget.value.copyWith(
      colorize: enable ?? widget.value.colorize,
      colorizeHueDeg: hue ?? widget.value.colorizeHueDeg,
      colorizeSatPercent: sat ?? widget.value.colorizeSatPercent,
      colorizeLightPercent: light ?? widget.value.colorizeLightPercent,
      featherDeg: feather ?? widget.value.featherDeg,
    ));
  }
}

/* ===== 小组件 ===== */

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
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _RowSwitch extends StatelessWidget {
  const _RowSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
