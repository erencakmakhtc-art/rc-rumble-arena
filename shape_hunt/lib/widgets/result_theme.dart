import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sonuc ekrani (basarili / basarisiz) icin ortak renk paleti.
///
/// Tum bolumler (Sekil Avi dahil) ayni tasarim dilini kullanir; sadece
/// basari durumuna gore renkler degisir.
///
/// Kart yari saydamdir (arka plan bulanik gorseli hafif gorunur); bu yuzden
/// renkler alpha kanali ile tanimlanir.
class ResultTheme {
  final bool success;
  const ResultTheme(this.success);

  // --- Kart arka plani (yari saydam) ---
  List<Color> get cardColors => success
      ? const [Color(0xE6F0FFF2), Color(0xD9D7F2DA)]
      : const [Color(0xE6FFF0F0), Color(0xD9F8D6D6)];

  Color get cardBorder => success
      ? const Color(0xE67BC67E)
      : const Color(0xE6E57373);

  // --- Ust baslik ---
  Color get topLabelInk => success
      ? const Color(0xFF2E7D32)
      : const Color(0xFFB71C1C);

  // --- Buyuk sayi ---
  Color get headlineInk => success
      ? const Color(0xFF2E7D32)
      : const Color(0xFF8B1A1A);

  // --- Kucuk istatistik kutulari ---
  Color get statBoxBg => success
      ? const Color(0x337BC67E)
      : const Color(0x33E57373);

  Color get statLabelInk => success
      ? const Color(0xFF4E7D51)
      : const Color(0xFFA04A4A);

  Color get statValueInk => success
      ? const Color(0xFF2E5C31)
      : const Color(0xFF7A2525);

  // --- Alt aciklama (verdict / failHint) ---
  Color get verdictInk => success
      ? const Color(0xFF3D6B40)
      : const Color(0xFF8B3030);

  // --- Dunya siralamasi karti ---
  List<Color> get rankCardColors => success
      ? const [Color(0xE6FFF8E2), Color(0xD9FFE7A6)]
      : const [Color(0xE6E8E8EC), Color(0xD9CFCFD6)];

  Color get rankBorder => success
      ? const Color(0xFFFFD873)
      : const Color(0xFFB8B8C0);

  Color get rankLabelInk => success
      ? const Color(0xFFB08A2A)
      : const Color(0xFF6E6E78);

  Color get rankValueInk => success
      ? AppColors.goldInk
      : const Color(0xFF4A4A52);

  Color get rankSubInk => success
      ? const Color(0xFFA5791A)
      : const Color(0xFF6E6E78);

  Color get rankTrackBg => success
      ? const Color(0x40B48C28)
      : const Color(0x40808090);

  List<Color> get rankBarGradient => success
      ? const [Color(0xFFFFCF5C), Color(0xFFF09A12)]
      : const [Color(0xFFA0A0AA), Color(0xFF707078)];

  // --- "Yeni rekor" rozeti (her iki durumda da altin) ---
  List<Color> get recordBadgeGradient => AppGradients.gold.colors;
  Color get recordBadgeInk => AppColors.goldInk;

  // --- Tekrar oyna butonu ---
  List<Color> get retryGradient => success
      ? const [Color(0xFFE4FFD9), Color(0xFFA8E86A)]
      : const [Color(0xFFFFD6D6), Color(0xFFF08080)];

  Color get retryDepth => success
      ? const Color(0xFF5FA22A)
      : const Color(0xFFB71C1C);

  Color get retryInk => success
      ? AppColors.greenInk
      : const Color(0xFF7A1A1A);

  // --- Bolumler butonu (her zaman ayni) ---
  List<Color> get modesGradient => const [
        Color(0xFFFFDCAE),
        Color(0xFFFF9F3D),
      ];

  Color get modesDepth => const Color(0xFFD1701A);
  Color get modesInk => AppColors.orangeInk;

  // --- Yukleniyor (RankCalc) ---
  Color get loadingBoxBg => success
      ? const Color(0x33A8AFE8)
      : const Color(0x33808090);
}