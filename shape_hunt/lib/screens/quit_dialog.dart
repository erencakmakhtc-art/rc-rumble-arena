import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_button.dart';

class QuitDialog extends StatelessWidget {
  final GameController controller;
  const QuitDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x80787EC3),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.95), width: 3),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFE7EAFF)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Çıkmak istediğine emin misin?',
              textAlign: TextAlign.center,
              style: baloo(22, FontWeight.w800, AppColors.ink, height: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu turdaki süreler kaydedilmez, hakkın geri gelmez.',
              textAlign: TextAlign.center,
              style: baloo(12, FontWeight.w600, AppColors.inkPale, height: 1.35),
            ),
            const SizedBox(height: 10),
            CandyButton(
              onTap: controller.confirmQuit,
              height: 54,
              borderRadius: 18,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFDCAE), Color(0xFFFF9F3D)],
              ),
              depthColor: const Color(0xFFD1701A),
              child: Text('Evet, çık', style: baloo(19, FontWeight.w800, AppColors.orangeInk)),
            ),
            const SizedBox(height: 8),
            CandyButton(
              onTap: controller.cancelQuit,
              height: 54,
              borderRadius: 18,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFDFDFF), Color(0xFFDFE3F8)],
              ),
              depthColor: const Color(0x99969CCD),
              child: Text('Devam et', style: baloo(19, FontWeight.w800, AppColors.inkSoft)),
            ),
          ],
        ),
      ),
    );
  }
}
