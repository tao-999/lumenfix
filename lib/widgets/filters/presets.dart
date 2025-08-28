// lib/widgets/filters/presets.dart
import 'dart:ui' show Color;

/// 调色滤镜分类（与“效果类滤镜”分开）
enum FilterCategory {
  cinematic,   // 电影感
  film,        // 胶片
  vintage,     // 复古
  portrait,    // 人像
  landscape,   // 风光
  night,       // 夜景
  bw,          // 黑白
  duotone,     // 双色调
}

enum CurveType { none, soft, hard, film, matte }

/// —— 调色滤镜的参数模型（纯数据，给引擎使用）——
class FilterPreset {
  final String id;
  final String name;                 // 中文名（UI 展示）
  final FilterCategory cat;

  // —— 基础色调（统一在 LUT 流程里做）——
  final double exposureEv;           // 曝光 EV（-2..+2）
  final double brightness;           // 亮度（-1..+1）
  final double contrast;             // 对比（-1..+1）
  final double matte;                // 抬黑（0..1）
  final CurveType curve;             // 曲线风格

  // —— 色彩 —— //
  final double saturation;           // 饱和（-1..+1）
  final double vibrance;             // 自然饱和（-1..+1）
  final double temperature;          // 色温（-1..+1，负冷正暖）
  final double tint;                 // 色调（-1..+1，负绿正洋红）
  final bool bw;                     // 黑白开关

  // —— 双色调 —— //
  final Color? duoA;                 // 阴影色
  final Color? duoB;                 // 高光色
  final double duoAmount;            // 双色调强度 0..1

  // —— 扩展：更强的风格化调色（新版引擎支持）——
  final double tealOrange;           // 0..1 “青橙”分离强度（电影感）
  final double hueShift;             // -180..180 全局色相旋转（度）
  final double splitAmount;          // 0..1 分离色调强度
  final double splitBalance;         // -1..1 分离色调平衡（负偏阴影，正偏高光）
  final Color? splitShadow;          // 分离色调阴影色
  final Color? splitHighlight;       // 分离色调高光色

  const FilterPreset({
    required this.id,
    required this.name,
    required this.cat,
    this.exposureEv = 0.0,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.matte = 0.0,
    this.curve = CurveType.none,
    this.saturation = 0.0,
    this.vibrance = 0.0,
    this.temperature = 0.0,
    this.tint = 0.0,
    this.bw = false,
    this.duoA,
    this.duoB,
    this.duoAmount = 0.0,

    // 扩展（默认 0 / null，完全兼容旧数据）
    this.tealOrange = 0.0,
    this.hueShift = 0.0,
    this.splitAmount = 0.0,
    this.splitBalance = 0.0,
    this.splitShadow,
    this.splitHighlight,
  });

  /// 给 compute 使用：跨 isolate 的纯 Map
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'cat': cat.index,
    'exposureEv': exposureEv,
    'brightness': brightness,
    'contrast': contrast,
    'matte': matte,
    'curve': curve.index,
    'saturation': saturation,
    'vibrance': vibrance,
    'temperature': temperature,
    'tint': tint,
    'bw': bw,
    'duoA': duoA?.value,
    'duoB': duoB?.value,
    'duoAmount': duoAmount,

    'tealOrange': tealOrange,
    'hueShift': hueShift,
    'splitAmount': splitAmount,
    'splitBalance': splitBalance,
    'splitShadow': splitShadow?.value,
    'splitHighlight': splitHighlight?.value,
  };
}