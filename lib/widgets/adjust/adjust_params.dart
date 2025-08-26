// lib/widgets/adjust/adjust_params.dart
// 只做聚合：所有单项类型都从 params/ 引入，避免同名不同库冲突
import 'params/params.dart' as P;

class AdjustParams {
  // —— 基础 —— //
  final P.BrightnessContrast bc;
  final P.ExposureParams exposure;
  final P.LevelsParams levels;
  final P.CurvesParams curves;
  final P.ShadowsHighlightsParams sh;

  // —— 颜色 —— //
  final P.VibranceParams vibrance;
  final P.HslParams hsl;
  final P.ColorBalanceParams colorBalance;
  final P.SelectiveColorParams selectiveColor;
  final P.BlackWhiteParams bw;
  final P.PhotoFilterParams photoFilter;

  // —— 高级调色 —— //
  final P.ChannelMixerParams mixer;
  final P.GradientMapParams gradientMap;

  // —— 特殊 —— //
  final P.DesaturateParams desaturate;   // ✅ 新增：去色
  final P.InvertParams invert;
  final P.ThresholdParams threshold;
  final P.PosterizeParams posterize;
  final P.MatchColorParams matchColor;
  final P.ReplaceColorParams replaceColor;

  const AdjustParams({
    // 基础
    this.bc = const P.BrightnessContrast(),
    this.exposure = const P.ExposureParams(),
    this.levels = const P.LevelsParams(),
    this.curves = const P.CurvesParams(),
    this.sh = const P.ShadowsHighlightsParams(),

    // 颜色
    this.vibrance = const P.VibranceParams(),
    this.hsl = P.kHslNeutral,
    this.colorBalance = const P.ColorBalanceParams(),
    this.selectiveColor = const P.SelectiveColorParams(),
    this.bw = const P.BlackWhiteParams(),
    this.photoFilter = const P.PhotoFilterParams(),

    // 高级调色
    this.mixer = const P.ChannelMixerParams(),
    this.gradientMap = const P.GradientMapParams(),

    // 特殊
    this.desaturate = const P.DesaturateParams(), // ✅ 默认关闭
    this.invert = const P.InvertParams(),
    this.threshold = const P.ThresholdParams(),
    this.posterize = const P.PosterizeParams(),
    this.matchColor = const P.MatchColorParams(),
    this.replaceColor = const P.ReplaceColorParams(),
  });

  AdjustParams copyWith({
    // 基础
    P.BrightnessContrast? bc,
    P.ExposureParams? exposure,
    P.LevelsParams? levels,
    P.CurvesParams? curves,
    P.ShadowsHighlightsParams? sh,

    // 颜色
    P.VibranceParams? vibrance,
    P.HslParams? hsl,
    P.ColorBalanceParams? colorBalance,
    P.SelectiveColorParams? selectiveColor,
    P.BlackWhiteParams? bw,
    P.PhotoFilterParams? photoFilter,

    // 高级调色
    P.ChannelMixerParams? mixer,
    P.GradientMapParams? gradientMap,

    // 特殊
    P.DesaturateParams? desaturate,
    P.InvertParams? invert,
    P.ThresholdParams? threshold,
    P.PosterizeParams? posterize,
    P.MatchColorParams? matchColor,
    P.ReplaceColorParams? replaceColor,
  }) {
    return AdjustParams(
      // 基础
      bc: bc ?? this.bc,
      exposure: exposure ?? this.exposure,
      levels: levels ?? this.levels,
      curves: curves ?? this.curves,
      sh: sh ?? this.sh,

      // 颜色
      vibrance: vibrance ?? this.vibrance,
      hsl: hsl ?? this.hsl,
      colorBalance: colorBalance ?? this.colorBalance,
      selectiveColor: selectiveColor ?? this.selectiveColor,
      bw: bw ?? this.bw,
      photoFilter: photoFilter ?? this.photoFilter,

      // 高级调色
      mixer: mixer ?? this.mixer,
      gradientMap: gradientMap ?? this.gradientMap,

      // 特殊
      desaturate: desaturate ?? this.desaturate,
      invert: invert ?? this.invert,
      threshold: threshold ?? this.threshold,
      posterize: posterize ?? this.posterize,
      matchColor: matchColor ?? this.matchColor,
      replaceColor: replaceColor ?? this.replaceColor,
    );
  }

  AdjustParams clone() => copyWith();
}
