import 'package:flutter/material.dart';

/// Orijinal tasarimdaki renk paletinin (CSS hex degerleri) Flutter karsiligi.
class AppColors {
  AppColors._();

  static const bgOuter = Color(0xFFC9CDF0);
  static const bgTop1 = Color(0xFFF0F1FD);
  static const bgTop2 = Color(0xFFDCDFF8);
  static const bgTop3 = Color(0xFFC4C9EF);

  static const ink = Color(0xFF3F4478);
  static const inkSoft = Color(0xFF4D5288);
  static const inkMuted = Color(0xFF7B80B2);
  static const inkFaint = Color(0xFF9BA0CB);
  static const inkPale = Color(0xFF8D92C0);

  static const goldInk = Color(0xFF7A4A00);
  static const goldInkAlt = Color(0xFF8A5A00);

  static const greenInk = Color(0xFF356810);
  static const greenInkAlt = Color(0xFF3D7514);

  static const orangeInk = Color(0xFF7A3F00);

  static const red = Color(0xFFFF5A5A);
}

class AppGradients {
  AppGradients._();

  static const background = RadialGradient(
    center: Alignment(0, -1),
    radius: 1.25,
    colors: [AppColors.bgTop1, AppColors.bgTop2, AppColors.bgTop3],
    stops: [0.0, 0.5, 1.0],
  );

  static const card = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFDFDFF), Color(0xFFE3E6FA)],
  );

  static const gold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF6D8), Color(0xFFFFD464)],
  );

  static const green = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE4FFD9), Color(0xFFA8E86A)],
  );

  static const orange = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFDCAE), Color(0xFFFF9F3D)],
  );
}

/// Orijinal tasarimdaki 'Baloo 2' fontunu kullanan kisa yol.
///
/// Font artik uygulamayla birlikte gonderiliyor (assets/fonts/), calisma
/// zamaninda internetten indirilmiyor. Bu sayede:
///  - soguk baslangicta font degisimi (FOUT) yasanmiyor,
///  - offline/CI ortamlarinda sessizce sistem fontuna dusulmuyor,
///  - gereksiz bir ag bagimliligi kalmiyor.
///
/// Dosya degisken (variable) bir font oldugu icin agirlik [FontVariation]
/// ile de bildirilir; boylece w600/w700/w800 gercekten farkli kalinlikta
/// render edilir (sahte kalinlastirma olmaz).
double _wghtOf(FontWeight w) {
  // FontWeight.w100 -> index 0, w900 -> index 8. Degisken font ekseni 100..900.
  return ((w.index + 1) * 100).toDouble();
}

TextStyle baloo(
  double size,
  FontWeight weight,
  Color color, {
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: 'Baloo2',
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', _wghtOf(weight))],
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}
