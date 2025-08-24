import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const LumenFixApp());
}

class LumenFixApp extends StatelessWidget {
  const LumenFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LumenFix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
