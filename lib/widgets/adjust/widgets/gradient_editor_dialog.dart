// lib/widgets/adjust/widgets/gradient_editor_dialog.dart
import 'package:flutter/material.dart';
import '../params/gradient_map_params.dart';
import 'color_picker_dialog.dart';

Future<List<GradientStop>?> showGradientEditorDialog({
  required BuildContext context,
  required List<GradientStop> init,
}) {
  return showDialog<List<GradientStop>>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _GradientEditorDialog(init: init),
  );
}

class _GradientEditorDialog extends StatefulWidget {
  const _GradientEditorDialog({required this.init});
  final List<GradientStop> init;

  @override
  State<_GradientEditorDialog> createState() => _GradientEditorDialogState();
}

class _GradientEditorDialogState extends State<_GradientEditorDialog> {
  late List<GradientStop> _stops;

  @override
  void initState() {
    super.initState();
    _stops = widget.init.map((e) => e).toList();
    if (_stops.length < 2) {
      _stops = const [
        GradientStop(pos: 0, color: Color(0xFF000000)),
        GradientStop(pos: 1, color: Color(0xFFFFFFFF)),
      ];
    }
    _normalize();
  }

  void _normalize() {
    _stops.sort((a, b) => a.pos.compareTo(b.pos));
    // clamp
    _stops = _stops
        .map((e) =>
        e.copyWith(pos: e.pos.clamp(0.0, 1.0)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final grad = LinearGradient(
      colors: _stops.map((e) => e.color).toList(),
      stops: _stops.map((e) => e.pos).toList(),
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFF1E1E1E),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 预览条
              Container(
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24),
                  gradient: grad,
                ),
              ),
              const SizedBox(height: 12),

              // 列表
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (int i = 0; i < _stops.length; i++)
                        _StopRow(
                          stop: _stops[i],
                          onChange: (s) {
                            setState(() {
                              _stops[i] = s;
                              _normalize();
                            });
                          },
                          onRemove: _stops.length <= 2
                              ? null
                              : () => setState(() {
                            _stops.removeAt(i);
                          }),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
              // 按钮行
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _stops.length >= 8
                        ? null
                        : () => setState(() {
                      _stops.add(const GradientStop(
                          pos: 0.5, color: Color(0xFF808080)));
                    }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('添加色标'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, List<GradientStop>.from(_stops)),
                    child: const Text('确定'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.onChange,
    this.onRemove,
  });

  final GradientStop stop;
  final ValueChanged<GradientStop> onChange;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final c = await showBwTintColorPicker(context, stop.color);
              if (c != null) onChange(stop.copyWith(color: c));
            },
            child: Container(
              width: 28,
              height: 20,
              decoration: BoxDecoration(
                color: stop.color,
                border: Border.all(color: Colors.white38),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('位置', style: TextStyle(color: Colors.white70)),
          Expanded(
            child: Slider(
              value: stop.pos,
              min: 0,
              max: 1,
              onChanged: (v) => onChange(stop.copyWith(pos: v)),
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
              onPressed: onRemove,
              tooltip: '删除色标',
            )
        ],
      ),
    );
  }
}
