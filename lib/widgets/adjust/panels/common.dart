// lib/widgets/adjust/panels/common.dart
import 'package:flutter/material.dart';

// ⚠️ 这里按你当前项目的模型文件名/路径改：
// 你的模型文件在 lib/widgets/adjust/adjust_params.dart
import '../adjust_params.dart';

/// 列表容器：带 Scrollbar + 分隔间距
class CommonScroller extends StatelessWidget {
  final List<Widget> children;
  const CommonScroller({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      interactive: true,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: children.length,
        itemBuilder: (_, i) => children[i],
        separatorBuilder: (_, __) => const SizedBox(height: 4),
      ),
    );
  }
}

/// 通用滑杆：双击回中性值；右侧显示数值；不显示 +/-
/// 用法示例：
/// CommonSlider(label:'强度', value:x, min:0, max:100, neutral:0,
///   onChanged:(v)=> onChanged(params.clone()..bloom = b.copyWith(intensity:v)),
///   onCommit: ()=> onChangeEnd(params), decimals:0)
class CommonSlider extends StatelessWidget {
  const CommonSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.neutral,
    required this.onChanged,
    this.onCommit,
    this.decimals,
    this.labelWidth = 92,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double neutral;
  final ValueChanged<double> onChanged;
  /// 手指松开时触发；一般直接传 `() => onChangeEnd(params)`
  final VoidCallback? onCommit;
  final int? decimals;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final dec = decimals ?? ((max - min) <= 4 ? 2 : 0);
    final v = value.clamp(min, max).toDouble();

    void _reset() {
      onChanged(neutral);
      onCommit?.call();
    }

    return GestureDetector(
      onDoubleTap: _reset,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Slider(
              value: v,
              min: min,
              max: max,
              divisions: 100,
              label: v.toStringAsFixed(dec),
              onChanged: onChanged,
              onChangeEnd: (_) => onCommit?.call(),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              v.toStringAsFixed(dec),
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// 横向子级标签栏（HSL/曲线通道等）
class CommonSubTabs extends StatelessWidget {
  final List<Widget> tabs;
  final double height;
  const CommonSubTabs({super.key, required this.tabs, this.height = 34});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: tabs.length,
        itemBuilder: (_, i) => tabs[i],
        separatorBuilder: (_, __) => const SizedBox(width: 8),
      ),
    );
  }
}

/// 通用可选中 Chip（和你顶部 tab 的视觉一致）
class CommonChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  final bool showCheck;
  const CommonChip({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
    this.showCheck = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && showCheck)
              const Icon(Icons.check, size: 14, color: Colors.white),
            if (selected && showCheck) const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// 小分组标题（例如“范围”“阴影”“高光”等）
/// 用法：CommonSection('阴影')；也可带副标题/右侧自定义控件
class CommonSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const CommonSection(
      this.title, {
        super.key,
        this.subtitle,
        this.trailing,
        this.padding = const EdgeInsets.only(top: 6, bottom: 2),
      });

  @override
  Widget build(BuildContext context) {
    final titleStyle = const TextStyle(
      color: Colors.white60,
      fontWeight: FontWeight.bold,
    );
    final subStyle = const TextStyle(
      color: Colors.white38,
      fontSize: 12,
    );

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment:
        subtitle == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: subStyle),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/* =========================
   Model copyWith 扩展区
   =========================
   你的模型里没自带 copyWith，我在这集中补齐。
   任何面板只要 import 'common.dart' 就能用 b.copyWith(...)
*/

extension GradeWheelX on GradeWheel {
  GradeWheel copyWith({double? hue, double? sat, double? lum}) =>
      GradeWheel(hue: hue ?? this.hue, sat: sat ?? this.sat, lum: lum ?? this.lum);
}

extension ColorGradeX on ColorGrade {
  ColorGrade copyWith({
    GradeWheel? shadows,
    GradeWheel? mids,
    GradeWheel? highs,
    double? sp,   // shadowPivot
    double? hp,   // highPivot
    double? sf,   // softness
  }) => ColorGrade(
    shadows: shadows ?? this.shadows,
    mids: mids ?? this.mids,
    highs: highs ?? this.highs,
    shadowPivot: sp ?? shadowPivot,
    highPivot: hp ?? highPivot,
    softness: sf ?? softness,
  );
}

extension SplitToningX on SplitToning {
  SplitToning copyWith({
    double? hHue, double? hSat,
    double? sHue, double? sSat,
    double? balance,
  }) => SplitToning(
    hHue: hHue ?? this.hHue,
    hSat: hSat ?? this.hSat,
    sHue: sHue ?? this.sHue,
    sSat: sSat ?? this.sSat,
    balance: balance ?? this.balance,
  );
}

extension VignetteX on Vignette {
  Vignette copyWith({
    double? amount, double? radius, double? roundness,
    double? feather, double? cx, double? cy,
  }) => Vignette(
    amount: amount ?? this.amount,
    radius: radius ?? this.radius,
    roundness: roundness ?? this.roundness,
    feather: feather ?? this.feather,
    cx: cx ?? this.cx,
    cy: cy ?? this.cy,
  );
}

extension GrainX on Grain {
  Grain copyWith({double? amount, double? size, double? roughness}) =>
      Grain(amount: amount ?? this.amount, size: size ?? this.size, roughness: roughness ?? this.roughness);
}

extension BloomX on Bloom {
  Bloom copyWith({double? threshold, double? intensity, num? radius}) =>
      Bloom(
        threshold: threshold ?? this.threshold,
        intensity: intensity ?? this.intensity,
        radius: (radius ?? this.radius).toDouble(),
      );
}

extension UsmX on Usm {
  Usm copyWith({double? amount, double? radius, double? threshold}) =>
      Usm(amount: amount ?? this.amount, radius: radius ?? this.radius, threshold: threshold ?? this.threshold);
}

extension DenoiseAdvX on DenoiseAdv {
  DenoiseAdv copyWith({double? luma, double? chroma}) =>
      DenoiseAdv(luma: luma ?? this.luma, chroma: chroma ?? this.chroma);
}

extension LensX on Lens {
  Lens copyWith({double? distortion, double? vignettingComp, double? caRed, double? caBlue}) =>
      Lens(
        distortion: distortion ?? this.distortion,
        vignettingComp: vignettingComp ?? this.vignettingComp,
        caRed: caRed ?? this.caRed,
        caBlue: caBlue ?? this.caBlue,
      );
}

// 如果你已把几何裁剪移除，可删掉 crop 字段
extension GeometryX on Geometry {
  Geometry copyWith({
    double? rotate, double? perspX, double? perspY, double? scale, List<double>? crop,
  }) => Geometry(
    rotate: rotate ?? this.rotate,
    perspX: perspX ?? this.perspX,
    perspY: perspY ?? this.perspY,
    scale: scale ?? this.scale,
    crop: crop ?? this.crop,
  );
}

extension LutConfigX on LutConfig {
  LutConfig copyWith({String? id, double? strength}) =>
      LutConfig(id: id ?? this.id, strength: strength ?? this.strength);
}
