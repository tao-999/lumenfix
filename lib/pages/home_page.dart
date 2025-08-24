// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'camera_page.dart';
import 'beautify_page.dart';
import 'portrait_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      _MenuItem(
        title: '相机',
        subtitle: '拍摄与即时预览',
        icon: Icons.photo_camera_outlined,
        color: Colors.blueAccent,
        builder: (_) => const CameraPage(),
      ),
      _MenuItem(
        title: '图片美化',
        subtitle: '调色 / 滤镜 / 裁剪',
        icon: Icons.auto_fix_high_outlined,
        color: Colors.purpleAccent,
        builder: (_) => const BeautifyPage(),
      ),
      _MenuItem(
        title: '人像美容',
        subtitle: '磨皮 / 瘦脸 / 分割',
        icon: Icons.face_3_outlined,
        color: Colors.orangeAccent,
        builder: (_) => const PortraitPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('LumenFix'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final cross = isWide ? 3 : 2;

          // ✅ 用固定主轴高度，避免 childAspectRatio 造成纵向不够
          final textScale = MediaQuery.of(context).textScaleFactor;
          final baseHeight = isWide ? 180.0 : 200.0;
          final itemHeight = baseHeight * (textScale > 1.0 ? (textScale * 1.05) : 1.0);

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: itemHeight, // ✅ 关键：给够高度
            ),
            itemBuilder: (context, index) => _MenuCard(item: items[index]),
          );
        },
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.item});
  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      elevation: 2,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: item.builder),
        ),
        child: Center(
          // ✅ Center + min，内容不再强撑满高
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: item.color.withOpacity(0.18),
                  child: Icon(item.icon, size: 34, color: item.color),
                ),
                const SizedBox(height: 10), // 稍微收紧间距
                Text(
                  item.title,
                  style: t.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                  maxLines: 1,                           // ✅ 防止换行增高
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Opacity(
                  opacity: 0.70,
                  child: Text(
                    item.subtitle,
                    style: t.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                    maxLines: 2,                         // ✅ 最多两行
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
