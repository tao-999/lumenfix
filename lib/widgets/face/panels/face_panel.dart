import 'package:flutter/material.dart';
import 'panel_common.dart';
import 'skin_panel.dart';
import 'shape_panel.dart';
import 'makeup_panel.dart';
import '../engine/face_regions.dart';

/// 下方面板入口（只负责分组切换与承载子面板）
class FacePanel extends StatefulWidget {
  const FacePanel({
    super.key,
    required this.params,
    required this.onChanged,
    this.onTabChanged,
    this.onOverlayChanged,      // 子面板可上报一个覆盖层（虚线等）
    this.regions,               // 人脸区域
    required this.fitRect,      // 预览中图像所在矩形
    required this.imageWidth,
    required this.imageHeight,
  });

  final FaceParams params;
  final ValueChanged<FaceParams> onChanged;
  final ValueChanged<FaceTab>? onTabChanged;
  final ValueChanged<Widget?>? onOverlayChanged;

  final FaceRegions? regions;
  final Rect fitRect;
  final int imageWidth;
  final int imageHeight;

  @override
  State<FacePanel> createState() => _FacePanelState();
}

class _FacePanelState extends State<FacePanel> {
  FaceTab _tab = FaceTab.skin;

  void _emit(FaceParams p) => widget.onChanged(p);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withOpacity(0.78),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegTabs(
              current: _tab,
              onChange: (v) {
                setState(() => _tab = v);
                widget.onTabChanged?.call(v);
                // 切页时清掉上一页 overlay（由父级延后 setState）
                widget.onOverlayChanged?.call(null);
              },
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: switch (_tab) {
              FaceTab.skin => SkinPanel(
                params: widget.params,
                onChanged: _emit,
              ),
              FaceTab.shape => ShapePanel(
                params: widget.params,
                onChanged: _emit,
              ),
              FaceTab.makeup => MakeupPanel(
                params: widget.params,
                onChanged: _emit,
                regions: widget.regions,
                fitRect: widget.fitRect,
                imageWidth: widget.imageWidth,
                imageHeight: widget.imageHeight,
                onOverlayChanged: widget.onOverlayChanged,
              ),
            },
          ),
        ],
      ),
    );
  }
}
