import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../data/color_defs.dart';
import '../data/pairs.dart';
import '../data/shape_defs.dart';
import '../data/world_countries.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_button.dart';
import '../widgets/glow_ring.dart';
import '../widgets/league_badge.dart';
import '../widgets/shape_view.dart';

/// Logoda gosterilecek sekiller: ok (arrowR/arrowD) ve pill haric, "guzel
/// duran" sekiller. Oyunun bir yon oku gibi gorunmesini engeller.
final List<ShapePair> _kLogoPairs = [
  ShapePair(ShapeKind.star5, ShapeColorKey.yellow),
  ShapePair(ShapeKind.diamond, ShapeColorKey.orange),
  ShapePair(ShapeKind.hex, ShapeColorKey.pink),
  ShapePair(ShapeKind.sparkle, ShapeColorKey.green),
  ShapePair(ShapeKind.star5, ShapeColorKey.blue),
  ShapePair(ShapeKind.circle, ShapeColorKey.red),
  ShapePair(ShapeKind.hex, ShapeColorKey.violet),
];

class HomeScreen extends StatelessWidget {
  final GameController controller;
  const HomeScreen({super.key, required this.controller});

  /// 1284310 -> "1.284.310"
  String _fmtThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final pair = _kLogoPairs[controller.logoIdx % _kLogoPairs.length];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 3),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withOpacity(0.38), Colors.white.withOpacity(0.16)],
                ),
              ),
              child: Center(child: ShapeView(pair: pair, size: 76)),
            ),
            const SizedBox(height: 22),
            Text(
              'Reflex World League',
              textAlign: TextAlign.center,
              style: baloo(32, FontWeight.w800, AppColors.ink, letterSpacing: -0.3, height: 1.05),
            ),
            const SizedBox(height: 14),
            LeagueBadge(
              tier: controller.leagueTier,
              rank: controller.globalRank,
            ),
            const SizedBox(height: 30),
            RepaintBoundary(
              child: GlowRing(
                borderRadius: 22,
                child: CandyButton(
                  onTap: controller.openModes,
                  height: 66,
                  borderRadius: 22,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE4FFD9), Color(0xFFA8E86A)],
                  ),
                  depthColor: const Color(0xFF5FA22A),
                  child: Text('Oyuna başla', style: baloo(23, FontWeight.w800, AppColors.greenInk)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            CandyButton(
              onTap: controller.openBoard,
              height: 60,
              borderRadius: 22,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFDFDFF), Color(0xFFDFE3F8)],
              ),
              depthColor: const Color(0x99969CCD),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Dünyanın En Hızlı 1000 İnsanı', style: baloo(18, FontWeight.w800, AppColors.inkSoft)),
              ),
            ),
            const SizedBox(height: 26),
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                color: Colors.white.withOpacity(0.28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⚡${controller.playsLeft}', style: baloo(14, FontWeight.w800, AppColors.goldInkAlt)),
                  const SizedBox(width: 9),
                  Container(width: 1, height: 18, color: const Color(0x668C92CD)),
                  const SizedBox(width: 9),
                  Text(flagEmoji(controller.cc ?? 'TR'), style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    controller.nick.isEmpty ? 'Misafir' : controller.nick,
                    style: baloo(14, FontWeight.w800, AppColors.inkSoft),
                  ),
                  const SizedBox(width: 9),
                  Container(width: 1, height: 18, color: const Color(0x668C92CD)),
                  const SizedBox(width: 9),
                  Text(
                    controller.signupRank == null
                        ? '#—'
                        : '#${_fmtThousands(controller.signupRank!)}. üye',
                    style: baloo(12, FontWeight.w700, AppColors.inkPale),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
