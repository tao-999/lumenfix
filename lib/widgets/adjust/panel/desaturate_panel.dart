import 'package:flutter/material.dart';
import '../params/desaturate_params.dart';

class DesaturatePanel extends StatelessWidget {
  const DesaturatePanel({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
  });

  final DesaturateParams value;
  final ValueChanged<DesaturateParams> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: InkWell(
        onTap: () {
          onChanged(value.copyWith(enabled: !value.enabled));
          onCommit();
        },
        child: Row(
          children: [
            Checkbox(
              value: value.enabled,
              onChanged: (on) {
                onChanged(value.copyWith(enabled: on ?? false));
                onCommit();
              },
            ),
            const SizedBox(width: 6),
            const Text('去色', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
