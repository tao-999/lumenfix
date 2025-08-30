import 'package:flutter/material.dart';
import '../engine/face_regions.dart';
import 'panel_common.dart';
import 'skin_panel.dart';
import 'shape_panel.dart';
import 'makeup_panel.dart';

/// 下方面板入口（只负责分组切换与承载子面板）
class FacePanel extends StatefulWidget {
  const FacePanel({
    super.key,
    required this.params,
    required this.onChanged,
    required this.onTabChanged,
    this.regions,
  });

  final FaceParams params;
  final ValueChanged<FaceParams> onChanged;
  final ValueChanged<FaceTab> onTabChanged;
  final FaceRegions? regions;

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
                setState(() => _tab = v); // 面板内部切换
                widget.onTabChanged(v);    // 通知父级选择了哪个功能
              },
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: switch (_tab) {
              FaceTab.skin   => SkinPanel(params: widget.params, onChanged: _emit),
              FaceTab.shape  => ShapePanel(params: widget.params, onChanged: _emit),
              FaceTab.makeup => MakeupPanel(
                params: widget.params,
                onChanged: _emit,
                regions: widget.regions, // 仅供提示用
              ),
            },
          ),
        ],
      ),
    );
  }
}
