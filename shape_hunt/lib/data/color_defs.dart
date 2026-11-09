import 'package:flutter/material.dart';

/// Oyunda kullanilan renk paleti (orijinal tasarimdaki COLORS nesnesiyle birebir).
enum ShapeColorKey { orange, yellow, blue, pink, green, red, violet }

/// Her renk icin [acik, orta, koyu] tonlari - camsi (glossy) degrade icin.
final Map<ShapeColorKey, List<Color>> kColorGradients = {
  ShapeColorKey.orange: const [Color(0xFFFFCF96), Color(0xFFFF9024), Color(0xFFD95A00)],
  ShapeColorKey.yellow: const [Color(0xFFFFF0A8), Color(0xFFFFCA2E), Color(0xFFDD9200)],
  ShapeColorKey.blue: const [Color(0xFFBFE0FF), Color(0xFF3F9DFF), Color(0xFF1257C4)],
  ShapeColorKey.pink: const [Color(0xFFFFD0EC), Color(0xFFFF6DBE), Color(0xFFD62A90)],
  ShapeColorKey.green: const [Color(0xFFE6FFBD), Color(0xFFA4DD34), Color(0xFF5F9F12)],
  ShapeColorKey.red: const [Color(0xFFFFCACA), Color(0xFFFF5757), Color(0xFFCF1B33)],
  ShapeColorKey.violet: const [Color(0xFFDED3FF), Color(0xFFA487FF), Color(0xFF6543D6)],
};

final Map<ShapeColorKey, String> kColorNamesTr = {
  ShapeColorKey.orange: 'Turuncu',
  ShapeColorKey.yellow: 'Sarı',
  ShapeColorKey.blue: 'Mavi',
  ShapeColorKey.pink: 'Pembe',
  ShapeColorKey.green: 'Yeşil',
  ShapeColorKey.red: 'Kırmızı',
  ShapeColorKey.violet: 'Mor',
};
