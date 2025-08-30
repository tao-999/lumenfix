// lib/widgets/face/panels/panel_common.dart
import 'package:flutter/material.dart';

/// 人脸美容参数（子面板与 Sheet 共用）
class FaceParams {
  double skinSmooth;   // 磨皮 0..1
  double whitening;    // 美白 0..1
  double skinTone;     // 肤色 -1..+1（冷→暖）
  double eyeScale;     // 眼睛放大 0..1
  double jawSlim;      // 瘦脸 0..1
  double noseThin;     // 瘦鼻 0..1
  Color  lipColor;     // 唇色
  double lipAlpha;     // 唇彩强度 0..1（UI 限 0..0.5）
  bool   lipOn;        // ⭐ 是否启用唇彩（选色即开启）
  bool   acneMode;     // 祛痘点按模式
  double acneSize;     // 祛痘半径

  FaceParams({
    this.skinSmooth = .2,
    this.whitening  = .1,
    this.skinTone   = 0,
    this.eyeScale   = 0,
    this.jawSlim    = 0,
    this.noseThin   = 0,
    this.lipColor   = const Color(0xFFDE6A6A),
    this.lipAlpha   = 0.0,     // ⭐ 默认 0，避免“未选色就见效”
    this.lipOn      = false,   // ⭐ 默认关闭；选色时置 true
    this.acneMode   = false,
    this.acneSize   = 18,
  });

  FaceParams copyWith({
    double? skinSmooth, double? whitening, double? skinTone,
    double? eyeScale, double? jawSlim, double? noseThin,
    Color? lipColor, double? lipAlpha, bool? lipOn,
    bool? acneMode, double? acneSize,
  }) => FaceParams(
    skinSmooth: skinSmooth ?? this.skinSmooth,
    whitening : whitening  ?? this.whitening,
    skinTone  : skinTone   ?? this.skinTone,
    eyeScale  : eyeScale   ?? this.eyeScale,
    jawSlim   : jawSlim    ?? this.jawSlim,
    noseThin  : noseThin   ?? this.noseThin,
    lipColor  : lipColor   ?? this.lipColor,
    lipAlpha  : lipAlpha   ?? this.lipAlpha,
    lipOn     : lipOn      ?? this.lipOn,      // ⭐ 别漏
    acneMode  : acneMode   ?? this.acneMode,
    acneSize  : acneSize   ?? this.acneSize,
  );
}

/// 面板分组
enum FaceTab { skin, shape, makeup }

/// —— 公共 UI 小部件（统一白色系） —— ///
class SliderTile extends StatelessWidget {
  const SliderTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.onChanged,
  });

  final IconData icon;
  final String title;
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final vStr = (max - min) <= 2
        ? value.toStringAsFixed(2)
        : value.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 0, color: Colors.transparent), // 对齐占位
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          SizedBox(
            width: 220,
            child: Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: Colors.white,
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      overlayColor: Colors.white24,
                      valueIndicatorColor: Colors.white,
                      valueIndicatorTextStyle: const TextStyle(color: Colors.black),
                    ),
                    child: Slider(
                      value: value.clamp(min, max),
                      min: min, max: max, divisions: divisions,
                      onChanged: onChanged, // 传 null 可禁用
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Text(
                    vStr,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SwitchTile extends StatelessWidget {
  const SwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          SwitchTheme(
            data: SwitchTheme.of(context).copyWith(
              trackColor: MaterialStateProperty.resolveWith((s) =>
              s.contains(MaterialState.selected) ? Colors.white54 : Colors.white24),
              thumbColor: MaterialStateProperty.resolveWith((s) =>
              s.contains(MaterialState.selected) ? Colors.white : Colors.white70),
            ),
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class SegTabs extends StatelessWidget {
  const SegTabs({
    super.key,
    required this.current,
    required this.onChange,
  });

  final FaceTab current;
  final ValueChanged<FaceTab> onChange;

  @override
  Widget build(BuildContext context) {
    final items = const [
      (FaceTab.skin,  Icons.spa,                 '美肤'),
      (FaceTab.shape, Icons.face_3,              '塑形'),
      (FaceTab.makeup,Icons.face_retouching_natural, '上妆'),
    ];
    return Row(
      children: items.map((e) {
        final selected = e.$1 == current;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton.icon(
              onPressed: () => onChange(e.$1),
              icon: Icon(e.$2, size: 16, color: Colors.white),
              label: Text(
                e.$3,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(color: selected ? Colors.white : Colors.white24),
                foregroundColor: Colors.white,
                overlayColor: Colors.white12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ColorRow extends StatelessWidget {
  const ColorRow({
    super.key,
    required this.title,
    required this.selected,
    required this.presets,
    required this.onPick,
  });

  final String title;
  final Color selected;
  final List<Color> presets;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.color_lens, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: presets.map((c) {
                final sel = c.value == selected.value;
                return GestureDetector(
                  onTap: () => onPick(c),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: Border.all(
                        color: sel ? Colors.white : Colors.white24,
                        width: sel ? 2 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
