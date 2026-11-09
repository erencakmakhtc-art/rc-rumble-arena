import 'package:flutter/material.dart';

/// Bayragin nasil cizilecegini belirten basit desen turleri.
enum FlagStyle { solid, stripesH, stripesV, circleOnWhite, stripesHRepeat }

class CountryDef {
  final String name;
  final FlagStyle style;
  final List<Color> colors;

  /// stripesH icin ozel oran (orn. Ispanya 7:11:7). Bos ise esit boluner.
  final List<int>? flexes;

  const CountryDef(this.name, this.style, this.colors, {this.flexes});
}

/// Orijinal tasarimdaki FLAGS nesnesinin (basitlestirilmis gradyan) Flutter karsiligi.
final Map<String, CountryDef> kCountries = {
  'TR': const CountryDef('Türkiye', FlagStyle.solid, [Color(0xFFE30A17), Color(0xFFC2000E)]),
  'DE': const CountryDef('Almanya', FlagStyle.stripesH, [Color(0xFF1A1A1A), Color(0xFFDD0000), Color(0xFFFFCE00)]),
  'JP': const CountryDef('Japonya', FlagStyle.circleOnWhite, [Color(0xFFE02233)]),
  'FR': const CountryDef('Fransa', FlagStyle.stripesV, [Color(0xFF0B4EA2), Colors.white, Color(0xFFE02233)]),
  'BR': const CountryDef('Brezilya', FlagStyle.solid, [Color(0xFF009B3A), Color(0xFF007A2E)]),
  'US': const CountryDef('ABD', FlagStyle.stripesHRepeat, [Color(0xFFC1121F), Colors.white]),
  'KR': const CountryDef('Kore', FlagStyle.circleOnWhite, [Color(0xFF2F6FD0)]),
  'ES': const CountryDef('İspanya', FlagStyle.stripesH, [Color(0xFFC60B1E), Color(0xFFFFC400), Color(0xFFC60B1E)], flexes: [7, 11, 7]),
  'NL': const CountryDef('Hollanda', FlagStyle.stripesH, [Color(0xFFAE1C28), Colors.white, Color(0xFF21468B)]),
};

const List<String> kCountryCodes = ['TR', 'DE', 'JP', 'FR', 'BR', 'US', 'KR', 'ES', 'NL'];
