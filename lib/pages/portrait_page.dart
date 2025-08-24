import 'package:flutter/material.dart';

class PortraitPage extends StatelessWidget {
  const PortraitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('人像美容')),
      body: const Center(
        child: Text('人像美容模块（分割/磨皮/瘦脸 入口页）'),
      ),
    );
  }
}
