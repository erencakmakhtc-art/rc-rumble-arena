import 'package:flutter/material.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/trial_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';
import '../../widgets/mode_host.dart';
import '../../widgets/trial_kit.dart';

/// Gecme sarti: 20 saniyede (3 hata yapmadan) ulasilmasi gereken puan.
const int _kMathTarget = 2200;

class QuickMathController extends TrialGameController {
  String text = '';
  bool isTrue = true;

  /// true: DOGRU butonu sagda (yer degistirmis).
  bool swapped = false;

  /// Oyuncunun bastigi buton (true = DOGRU).
  bool? picked;

  @override
  int get targetPoints => _kMathTarget;

  @override
  int get fastMs => 1100;

  /// Cevap penceresi 2,4 sn'den 1,5 sn'ye daralir.
  @override
  int trialWindowMs(double progress) => (2400 - 900 * progress).round();

  @override
  void resetTrialState() {
    text = '';
    picked = null;
    swapped = false;
  }

  @override
  void buildTrial() {
    picked = null;
    final (expr, value, trap) = _make(progress);
    isTrue = rng.nextBool();
    final shown = isTrue ? value : _wrong(value, trap);
    text = '$expr = $shown';
    // 5. saniyeden sonra butonlar bazen yer degistirir (renkler anlamla gider).
    swapped = elapsedMs > 5000 && rng.nextDouble() < 0.3;
  }

  /// (ifade, dogru sonuc, islem onceligi tuzagi).
  (String, int, int?) _make(double p) {
    if (elapsedMs > 6000 && rng.nextDouble() < 0.2 + 0.35 * p) {
      // Iki islemli: carpma once yapilir. Soldan saga hesaplayan tuzaga duser.
      final b = 2 + rng.nextInt(8);
      final c = 2 + rng.nextInt(8);
      if (rng.nextBool()) {
        final a = 2 + rng.nextInt(19);
        return ('$a + $b × $c', a + b * c, (a + b) * c);
      }
      final big = b * c + 1 + rng.nextInt(30);
      return ('$big − $b × $c', big - b * c, (big - b) * c);
    }
    final kind = rng.nextInt(3);
    if (kind == 0) {
      final a = 12 + rng.nextInt(58);
      final b = 7 + rng.nextInt(38);
      return ('$a + $b', a + b, null);
    }
    if (kind == 1) {
      final a = 25 + rng.nextInt(70);
      final b = 6 + rng.nextInt(a - 10);
      return ('$a − $b', a - b, null);
    }
    final hi = p > 0.4 ? 13 : 10;
    final m1 = 3 + rng.nextInt(hi - 3);
    final m2 = 3 + rng.nextInt(hi - 3);
    return ('$m1 × $m2', m1 * m2, null);
  }

  /// Dogruya cok yakin yanlis sonuc: ±1, ±2, ±10, basamak yer degisimi ya da
  /// islem onceligi tuzagi.
  int _wrong(int value, int? trap) {
    if (trap != null && trap != value && rng.nextDouble() < 0.4) return trap;
    final cands = <int>{};
    for (final d in const [1, -1, 2, -2, 10, -10]) {
      if (value + d >= 0) cands.add(value + d);
    }
    if (value >= 10 && value < 100) {
      final sw = (value % 10) * 10 + value ~/ 10;
      if (sw != value && value % 10 != 0) cands.add(sw);
    }
    cands.remove(value);
    final list = cands.toList();
    return list[rng.nextInt(list.length)];
  }

  void choose(bool saysTrue) {
    if (!acceptingInput) return;
    picked = saysTrue;
    answer(saysTrue == isTrue);
  }

  @override
  String get verdict {
    if (errors == 0 && avgReactionMs < 900) return 'Hesap makinesi gibisin. Hem hızlı hem hatasız!';
    if (errors == 0) return 'Hatasız! İşlem önceliği tuzaklarına düşmedin.';
    return 'Hedefi geçtin! Çarpmanın önce yapıldığını unutma.';
  }
}

class QuickMathScreen extends StatelessWidget {
  final GameController app;
  const QuickMathScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<QuickMathController>(
      app: app,
      mode: GameMode.quickMath,
      create: QuickMathController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(
          label: 'SÜRE',
          value: (c.remainingMs / 1000).toStringAsFixed(1),
          highlight: c.remainingMs < 5000,
        ),
        HudPill(label: 'HATA', value: '${c.errors}/${c.maxErrors}', highlight: c.errors >= 2),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) {
        Widget button(bool meansTrue) {
          return Expanded(
            child: TrialChoice(
              height: 96,
              state: choiceStateOf(
                picked: c.picked == meansTrue,
                isAnswer: c.isTrue == meansTrue,
                feedback: c.feedback,
              ),
              idleColors: meansTrue
                  ? const [Color(0xFFF1FFEA), Color(0xFFCFF3B8)]
                  : const [Color(0xFFFFF0F0), Color(0xFFFFCFCF)],
              onDown: () => c.choose(meansTrue),
              child: Text(
                meansTrue ? '✓ DOĞRU' : '✗ YANLIŞ',
                style: baloo(
                  24,
                  FontWeight.w800,
                  meansTrue ? const Color(0xFF2B7A1F) : const Color(0xFFB3261E),
                ),
              ),
            ),
          );
        }

        final left = button(!c.swapped);
        final right = button(c.swapped);
        return Column(
          children: [
            const Spacer(flex: 2),
            TrialCard(
              feedback: c.feedback,
              height: 130,
              child: c.text.isEmpty
                  ? Text('HAZIR', style: baloo(30, FontWeight.w800, AppColors.inkFaint))
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text(c.text, style: baloo(46, FontWeight.w800, AppColors.ink)),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            TrialWindowBar(value: c.text.isEmpty ? 1.0 : c.windowLeft),
            const Spacer(flex: 3),
            Row(children: [left, const SizedBox(width: 12), right]),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}
