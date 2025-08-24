// lib/widgets/common/empty_pick_image.dart
import 'package:flutter/material.dart';

/// 空态：提示添加图片（可选：iOS 的“编辑允许访问的照片”按钮）
/// 用法：EmptyPickImage(onPick: ..., onEditAllowed: ...);
class EmptyPickImage extends StatelessWidget {
  const EmptyPickImage({
    super.key,
    required this.onPick,
    this.onEditAllowed,
    this.title = '点击添加一张图片',
  });

  final VoidCallback onPick;
  final VoidCallback? onEditAllowed;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.add_photo_alternate_outlined, size: 56, color: c),
        const SizedBox(height: 12),
        Text(title),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.add),
          label: const Text('添加图片'),
        ),
        if (onEditAllowed != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onEditAllowed,
            icon: const Icon(Icons.privacy_tip_outlined),
            label: const Text('编辑允许访问的照片'),
          ),
        ],
      ],
    );
  }
}
