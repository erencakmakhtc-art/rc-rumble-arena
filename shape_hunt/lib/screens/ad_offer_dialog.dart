import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_button.dart';

/// Gunluk oynama hakki bitince acilan modal.
///
/// Iki durumu var:
///  - teklif: "Hakkın bitti, reklam izleyip +3 hak kazan"
///  - izleme: sahte reklam geri sayimi (gercek SDK baglanmadi)
class AdOfferDialog extends StatelessWidget {
  final GameController controller;
  const AdOfferDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final watching = controller.adPlaying;

    return Container(
      color: const Color(0x80787EC3),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 3),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.82)],
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: watching ? _WatchingBody(controller: controller) : _OfferBody(controller: controller),
      ),
    );
  }
}

class _OfferBody extends StatelessWidget {
  final GameController controller;
  const _OfferBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
            gradient: AppGradients.gold,
          ),
          alignment: Alignment.center,
          child: Text('⚡', style: baloo(30, FontWeight.w800, AppColors.goldInk)),
        ),
        const SizedBox(height: 14),
        Text(
          'Günlük hakkın bitti',
          textAlign: TextAlign.center,
          style: baloo(22, FontWeight.w800, AppColors.ink, height: 1.1),
        ),
        const SizedBox(height: 8),
        Text(
          'Her gün $kDailyPlayLimit ücretsiz oyun hakkın var. '
          'Kısa bir reklam izleyerek $kAdRewardPlays hak daha kazanabilirsin.',
          textAlign: TextAlign.center,
          style: baloo(13, FontWeight.w600, AppColors.inkMuted, height: 1.4),
        ),
        const SizedBox(height: 18),
        CandyButton(
          onTap: controller.startAd,
          height: 54,
          borderRadius: 18,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3C4), Color(0xFFFFCE4A)],
          ),
          depthColor: const Color(0xFFC79512),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 22, color: AppColors.goldInk),
              const SizedBox(width: 8),
              Text('Reklam izle  +$kAdRewardPlays hak', style: baloo(17, FontWeight.w800, AppColors.goldInk)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: controller.closeAdOffer,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            child: Text('Şimdi değil', style: baloo(15, FontWeight.w700, AppColors.inkMuted)),
          ),
        ),
        Text(
          'Haklar her gün yeniden dolar.',
          textAlign: TextAlign.center,
          style: baloo(11, FontWeight.w600, AppColors.inkFaint),
        ),
      ],
    );
  }
}

class _WatchingBody extends StatelessWidget {
  final GameController controller;
  const _WatchingBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final left = (kAdSeconds - controller.adProgress).clamp(0, kAdSeconds);
    final pct = (controller.adProgress / kAdSeconds).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('REKLAM', style: baloo(10, FontWeight.w700, AppColors.inkFaint, letterSpacing: 2)),
        const SizedBox(height: 14),
        // Sahte reklam alani
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8E96D8), Color(0xFF5D66B0)],
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_creation_rounded, size: 36, color: Colors.white70),
              const SizedBox(height: 6),
              Text('Reklam oynatılıyor…', style: baloo(13, FontWeight.w700, Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Ilerleme cubugu
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: const Color(0x338C92C8),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFCE4A)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          left > 0 ? '$left saniye sonra ödülün hazır' : 'Ödülün veriliyor…',
          style: baloo(13, FontWeight.w700, AppColors.inkMuted),
        ),
      ],
    );
  }
}
