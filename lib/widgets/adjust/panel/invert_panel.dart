// lib/widgets/adjust/panel/invert_panel.dart
import 'package:flutter/material.dart';
import '../params/invert_params.dart';

class InvertPanel extends StatelessWidget {
  const InvertPanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final InvertParams value;
  final ValueChanged<InvertParams> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: CheckboxListTile(
        value: value.enabled,
        onChanged: (on) {
          onChanged(value.copyWith(enabled: on ?? false));
          onCommit();
        },
        title: const Text('启用反相', style: TextStyle(color: Colors.white)),
        controlAffinity: ListTileControlAffinity.leading, // 复选框在最左
        dense: true,
        contentPadding: EdgeInsets.zero, // 更紧凑
        activeColor: Colors.white,       // 勾选色
        checkColor: Colors.black,        // 勾选对勾色
      ),
    );
  }
}
