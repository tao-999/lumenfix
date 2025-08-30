import 'package:flutter/material.dart';

class LipPaletteSheet extends StatelessWidget {
  const LipPaletteSheet({super.key, required this.initial});
  final Color initial;

  // —— 色系分组 —— //
  Map<String, List<Color>> _families() {
    List<Color> band(double hStart, double hEnd,
        {List<double>? sats, List<double>? vals}) {
      final sList = sats ?? const [0.6, 0.75, 0.9, 1.0];
      final vList = vals ?? const [0.6, 0.75, 0.9];
      final step = 6; // hue 分段
      final List<Color> out = [];
      for (int i = 0; i <= step; i++) {
        final h = hStart + (hEnd - hStart) * (i / step);
        for (final s in sList) {
          for (final v in vList) {
            out.add(HSVColor.fromAHSV(1, h, s, v).toColor());
          }
        }
      }
      return out;
    }

    return {
      '红调': band(350, 10),
      '粉色': band(330, 350),
      '珊瑚/橘': band(10, 30),
      '裸棕': band(10, 30, sats: const [0.25, 0.4, 0.55], vals: const [0.55, 0.7, 0.85]),
      '浆果': band(300, 330),
      '紫调': band(270, 300),
      '清透': band(330, 10, sats: const [0.15, 0.25, 0.35], vals: const [0.75, 0.85, 0.95]),
    };
  }

  @override
  Widget build(BuildContext context) {
    final fam = _families();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('选择唇彩'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: fam.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, idx) {
          final name = fam.keys.elementAt(idx);
          final colors = fam[name]!;
          return _FamilySection(
            title: name,
            colors: colors,
            initial: initial,
            onPick: (c) => Navigator.pop(context, c),
          );
        },
      ),
    );
  }
}

class _FamilySection extends StatelessWidget {
  const _FamilySection({
    required this.title,
    required this.colors,
    required this.initial,
    required this.onPick,
  });

  final String title;
  final List<Color> colors;
  final Color initial;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 10,
          children: colors.map((c) {
            final selected = c.value == initial.value;
            return GestureDetector(
              onTap: () => onPick(c),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.white : Colors.white24,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0,1))
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
