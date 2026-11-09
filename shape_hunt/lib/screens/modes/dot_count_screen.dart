import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/trial_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';
import '../../widgets/mode_host.dart';
import '../../widgets/trial_kit.dart';

/// Gecme sarti: 20 saniyede (3 hata yapmadan) ulasilmasi gereken puan.
const int _kDotTarget = 2000;

const Color _kDotInkA = Color(0xFF3F4478);
const Color _kDotInkB = Color(0xFFE8559C);

class DotCountController extends TrialGameController {
  /// Nokta ve tuzak kare konumlari 0..1 araliginda (kare alana oranli).
  List<Offset> dots = [];
  List<Color> dotColors = [];
  List<Offset> decoys = [];
  double dotR = 0.05;
  int count = 0;
  List<int> options = const [];
  int? pickedIndex;

  @override
  int get targetPoints => _kDotTarget;

  @override
  int get fastMs => 1100;

  /// Cevap penceresi (gosterim dahil) 2,4 sn'den 1,6 sn'ye daralir.
  @override
  int trialWindowMs(double progress) => (2400 - 800 * progress).round();

  /// Noktalarin gorunme suresi 450ms'den 250ms'ye iner.
  int get flashMs => (450 - 200 * progress).round();

  /// Noktalar ilk anda gorunur; cevaptan sonra (ogretici) yeniden gosterilir.
  bool get dotsVisible =>
      dots.isNotEmpty && (feedback != TrialFeedback.none || trialElapsedMs < flashMs);

  @override
  void resetTrialState() {
    dots = [];
    dotColors = [];
    decoys = [];
    options = const [];
    pickedIndex = null;
  }

  @override
  void buildTrial() {
    pickedIndex = null;
    final p = progress;

    // Nokta sayisi 4-8 araligindan 7-13 araligina cikar.
    final lo = 4 + (3 * p).round();
    final hi = 8 + (5 * p).round();
    count = lo + rng.nextInt(hi - lo + 1);
    dotR = 0.05 - 0.012 * p;

    final occupied = <Offset>[];
    dots = _place(occupied, count);
    // 5. saniyeden sonra iki renk karisik (hepsi sayilir).
    final twoTone = elapsedMs > 5000;
    dotColors = [
      for (var i = 0; i < count; i++) twoTone && rng.nextBool() ? _kDotInkB : _kDotInkA,
    ];
    // 8. saniyeden sonra sayilmamasi gereken gri kareler.
    decoys = elapsedMs > 8000 ? _place(occupied, 1 + rng.nextInt(3)) : [];

    // Secenekler: dogru sayi + ±2 / ±3 uzaklikta yakin sayilar.
    final offs = [-3, -2, 2, 3]..shuffle(rng);
    final set = <int>{count};
    for (final o in offs) {
      if (set.length == 4) break;
      if (count + o >= 1) set.add(count + o);
    }
    var extra = 4;
    while (set.length < 4) {
      set.add(count + extra);
      extra += 1;
    }
    options = set.toList()..shuffle(rng);

    // Noktalarin tam zamaninda kaybolmasi icin (sayac 40 ms'de bir calisir).
    own(Timer(Duration(milliseconds: flashMs), safeNotify));
  }

  List<Offset> _place(List<Offset> occupied, int n) {
    final out = <Offset>[];
    final minD = dotR * 2.7;
    for (var k = 0; k < n; k++) {
      var pos = const Offset(0.5, 0.5);
      for (var t = 0; t < 60; t++) {
        pos = Offset(0.08 + rng.nextDouble() * 0.84, 0.08 + rng.nextDouble() * 0.84);
        if (occupied.every((o) => (o - pos).distance >= minD)) break;
      }
      occupied.add(pos);
      out.add(pos);
    }
    return out;
  }

  void pick(int i) {
    if (!acceptingInput || i >= options.length) return;
    pickedIndex = i;
    answer(options[i] == count);
  }

  @override
  String get verdict {
    if (errors == 0) return 'Bir bakışta saydın, hiç yanılmadın. Kartal göz!';
    return 'Hedefi geçtin! Noktaları küçük gruplar halinde görmeyi dene.';
  }
}

class DotCountScreen extends StatelessWidget {
  final GameController app;
  const DotCountScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<DotCountController>(
      app: app,
      mode: GameMode.dotCount,
      create: DotCountController.new,
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
        Widget option(int i) {
          if (i >= c.options.length) return const Expanded(child: SizedBox(height: 68));
          return Expanded(
            child: TrialChoice(
              height: 68,
              state: choiceStateOf(
                picked: c.pickedIndex == i,
                isAnswer: c.options[i] == c.count,
                feedback: c.feedback,
              ),
              onDown: () => c.pick(i),
              child: Text('${c.options[i]}', style: baloo(32, FontWeight.w800, AppColors.ink)),
            ),
          );
        }

        return Column(
          children: [
            const Spacer(),
            LayoutBuilder(
              builder: (context, box) {
                final side = min(box.maxWidth, 250.0);
                return SizedBox(
                  width: side,
                  height: side,
                  child: TrialCard(
                    feedback: c.feedback,
                    child: CustomPaint(
                      size: Size(side, side),
                      painter: _DotPainter(
                        visible: c.dotsVisible,
                        dots: c.dots,
                        colors: c.dotColors,
                        decoys: c.decoys,
                        radius: c.dotR,
                        waiting: c.dots.isEmpty,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TrialWindowBar(value: c.dots.isEmpty ? 1.0 : c.windowLeft),
            const Spacer(),
            Row(children: [option(0), const SizedBox(width: 10), option(1)]),
            const SizedBox(height: 10),
            Row(children: [option(2), const SizedBox(width: 10), option(3)]),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}

class _DotPainter extends CustomPainter {
  final bool visible;
  final List<Offset> dots;
  final List<Color> colors;
  final List<Offset> decoys;
  final double radius;
  final bool waiting;

  _DotPainter({
    required this.visible,
    required this.dots,
    required this.colors,
    required this.decoys,
    required this.radius,
    required this.waiting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (!visible) {
      final tp = TextPainter(
        text: TextSpan(
          text: waiting ? 'HAZIR' : 'Kaç tane?',
          style: baloo(26, FontWeight.w800, AppColors.inkFaint),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
      tp.dispose();
      return;
    }
    final r = radius * s;
    for (final d in decoys) {
      final c = Offset(d.dx * size.width, d.dy * size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: r * 1.9, height: r * 1.9), Radius.circular(r * 0.3)),
        Paint()..color = const Color(0xFFA8ADC4),
      );
    }
    for (var i = 0; i < dots.length; i++) {
      final c = Offset(dots[i].dx * size.width, dots[i].dy * size.height);
      canvas.drawCircle(c, r, Paint()..color = i < colors.length ? colors[i] : _kDotInkA);
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) =>
      old.visible != visible || old.dots != dots || old.decoys != decoys || old.waiting != waiting;
}
