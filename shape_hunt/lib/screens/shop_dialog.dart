import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_button.dart';

class _Pack {
  final int n;
  final String title;
  final String sub;
  final String price;
  final bool hot;
  const _Pack(this.n, this.title, this.sub, this.price, this.hot);
}

const List<_Pack> _packs = [
  _Pack(4, '4 hak', 'Bugün devam et', '0,99 TL', false),
  _Pack(12, '12 hak', 'En çok tercih edilen', '2,49 TL', true),
  _Pack(40, '40 hak', 'Bir hafta yeter', '6,99 TL', false),
];

/// NOT: Bu ekrandaki satin alma tamamen sahte (mock) - gercek bir odeme
/// altyapisina (IAP/store) baglanmiyor, sadece can sayisini yerel olarak artirir.
class ShopDialog extends StatelessWidget {
  final GameController controller;
  const ShopDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x80787EC3),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
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
              Text('⚡', style: baloo(34, FontWeight.w800, AppColors.goldInkAlt)),
              const SizedBox(height: 3),
              Text('Günlük hakkın bitti', style: baloo(22, FontWeight.w800, AppColors.ink)),
              const SizedBox(height: 3),
              Text(
                'Yarın 4 hak yeniden yüklenir ya da paket al',
                textAlign: TextAlign.center,
                style: baloo(12, FontWeight.w600, AppColors.inkPale, height: 1.3),
              ),
              const SizedBox(height: 14),
              for (final p in _packs) ...[
                CandyButton(
                  onTap: () => controller.buy(p.n),
                  height: 60,
                  borderRadius: 18,
                  gradient: p.hot
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFF8E2), Color(0xFFFFDF95)],
                        )
                      : LinearGradient(colors: [Colors.white.withOpacity(0.75), Colors.white.withOpacity(0.75)]),
                  depthColor: p.hot ? const Color(0xFFC8961E) : const Color(0x59969CCD),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Text('⚡', style: baloo(19, FontWeight.w800, p.hot ? const Color(0xFFC8940F) : AppColors.inkFaint)),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.title, style: baloo(17, FontWeight.w800, p.hot ? AppColors.goldInk : AppColors.inkSoft)),
                              Text(p.sub, style: baloo(10, FontWeight.w600, p.hot ? const Color(0xFFA5791A) : AppColors.inkFaint)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFE4FFD9), Color(0xFFA8E86A)],
                            ),
                          ),
                          child: Text(p.price, style: baloo(13, FontWeight.w800, AppColors.greenInk)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
              ],
              TextButton(
                onPressed: controller.closeShop,
                child: Text(
                  'Şimdi değil',
                  style: baloo(13, FontWeight.w700, AppColors.inkPale).copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
