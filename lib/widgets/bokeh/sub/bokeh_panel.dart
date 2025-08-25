import 'package:flutter/material.dart';
import 'bokeh_models.dart';

class BokehPanel extends StatelessWidget {
  const BokehPanel({
    super.key,
    required this.mode,
    required this.onModeChange,
    required this.blurSigma,
    required this.onBlurChanged,
    required this.onBlurChangeEnd,
    required this.feather,
    required this.onFeatherChange,
    required this.onClearLasso,
    required this.rebuilding,
  });

  final BokehMode mode;
  final ValueChanged<BokehMode> onModeChange;

  final double blurSigma;
  final ValueChanged<double> onBlurChanged;
  final ValueChanged<double> onBlurChangeEnd;

  final double feather;
  final ValueChanged<double> onFeatherChange;

  final VoidCallback onClearLasso;
  final bool rebuilding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.85),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 模式切换
          Row(
            children: [
              _chip(
                icon: Icons.blur_circular,
                text: '椭圆',
                selected: mode == BokehMode.ellipse,
                onTap: () => onModeChange(BokehMode.ellipse),
              ),
              const SizedBox(width: 8),
              _chip(
                icon: Icons.gesture,
                text: '套索',
                selected: mode == BokehMode.lasso,
                onTap: () => onModeChange(BokehMode.lasso),
              ),
              const Spacer(),
              if (mode == BokehMode.lasso)
                TextButton.icon(
                  onPressed: onClearLasso,
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('清空'),
                ),
            ],
          ),
          const SizedBox(height: 6),

          _label('边缘羽化'),
          Slider(
            value: feather,
            min: 0,
            max: 24,
            divisions: 24,
            label: feather.toStringAsFixed(0),
            onChanged: onFeatherChange,
          ),

          const SizedBox(height: 2),
          Row(
            children: [
              _label('模糊强度'),
              const Spacer(),
              if (rebuilding)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          Slider(
            value: blurSigma,
            min: 0,
            max: 30,
            divisions: 30,
            label: blurSigma.toStringAsFixed(0),
            onChanged: onBlurChanged,     // 只更新 UI
            onChangeEnd: onBlurChangeEnd, // 松手再重建底图
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white12 : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _label(String s) =>
      Text(s, style: const TextStyle(color: Colors.white70));
}
