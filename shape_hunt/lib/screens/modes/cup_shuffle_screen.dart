import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/arena_base.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/arena_view.dart';
import '../../widgets/mini_kit.dart';
import '../../widgets/mode_host.dart';

const int _kCupRounds = 8;

/// Bu kadar yanlista oyun biter (yani en fazla 1 hata hakki var).
const int _kCupMaxErrors = 2;

/// Secim icin taninan sure (ms).
const double _kPickTimeoutMs = 4000;

/// Tur plani: bardak sayisi, hamle sayisi, hamle suresi, ikili hamle ve
/// sahte hamle (yaklasip geri donme) olasiligi.
class CupRound {
  final int cups;
  final int swaps;
  final double swapMs;
  final double doubles;
  final double fakes;
  const CupRound(this.cups, this.swaps, this.swapMs, this.doubles, this.fakes);
}

const List<CupRound> _kCupPlan = [
  CupRound(3, 5, 420, 0.0, 0.0),
  CupRound(3, 7, 360, 0.0, 0.1),
  CupRound(4, 8, 320, 0.2, 0.1),
  CupRound(4, 9, 290, 0.3, 0.15),
  CupRound(4, 10, 260, 0.35, 0.15),
  CupRound(5, 11, 260, 0.4, 0.2),
  CupRound(5, 12, 245, 0.45, 0.2),
  CupRound(5, 14, 230, 0.5, 0.2),
];

enum CupStage { show, lower, shuffle, pick, reveal }

class Cup {
  int slot;
  int from = 0;
  int to = 0;

  /// +1 one (asagi, buyuk), -1 arkaya (yukari, kucuk) dogru kavis.
  double arc = 0;
  bool moving = false;
  bool fake = false;
  Cup(this.slot);
}

class CupMove {
  final int a;
  final int b;
  final bool fake;
  const CupMove(this.a, this.b, this.fake);
}

class CupShuffleController extends ArenaGameController {
  @override
  bool get timed => false;

  @override
  int get durationMs => 600000;

  int round = 0;
  CupStage stage = CupStage.show;
  double stageMs = 0;
  List<Cup> cups = [];
  int ballCup = 0;
  List<List<CupMove>> _steps = [];
  int _stepIdx = 0;
  int? pickedCup;
  bool? lastCorrect;
  int errors = 0;
  int correct = 0;
  bool completed = false;
  double _pickStart = 0;

  CupRound get cfg => _kCupPlan[(round - 1).clamp(0, _kCupPlan.length - 1)];

  // ---- geometri (ressam ve dokunus ayni degerleri kullanir) ----

  double get baseY => field.height * 0.58;
  double get cupW => min(field.width / (cfg.cups + 1) * 0.8, 92.0);
  double get cupH => cupW * 1.1;
  double slotX(int s) => field.width * (s + 1) / (cfg.cups + 1);

  /// Bardagin anlik konumu: (x, y, olcek).
  (double, double, double) cupPose(Cup c) {
    if (stage == CupStage.shuffle && c.moving) {
      var e = (stageMs / cfg.swapMs).clamp(0.0, 1.0).toDouble();
      final q = -2 * e + 2;
      e = e < 0.5 ? 2 * e * e : 1 - q * q / 2;
      final travel = c.fake ? sin(pi * e) * 0.45 : e;
      final x = slotX(c.from) + (slotX(c.to) - slotX(c.from)) * travel;
      final s = sin(pi * e);
      return (x, baseY + c.arc * s * field.height * 0.06, 1 + 0.08 * c.arc * s);
    }
    return (slotX(c.slot), baseY, 1.0);
  }

  /// Bardagin ne kadar kaldirildigi (px).
  double liftOf(int index) {
    final full = cupH * 0.9;
    return switch (stage) {
      CupStage.show => index == ballCup ? full : 0.0,
      CupStage.lower => index == ballCup ? full * (1 - (stageMs / 280).clamp(0.0, 1.0).toDouble()) : 0.0,
      CupStage.reveal => full * (stageMs / 200).clamp(0.0, 1.0).toDouble(),
      _ => 0.0,
    };
  }

  // ---- akis ----

  @override
  void resetArena() {
    round = 0;
    errors = 0;
    correct = 0;
    completed = false;
    _startRound();
  }

  void _startRound() {
    round += 1;
    final n = cfg.cups;
    cups = [for (var i = 0; i < n; i++) Cup(i)];
    ballCup = rng.nextInt(n);
    pickedCup = null;
    lastCorrect = null;
    _steps = _makeSteps();
    _stepIdx = 0;
    stage = CupStage.show;
    stageMs = 0;
    safeNotify();
  }

  List<List<CupMove>> _makeSteps() {
    final c = cfg;
    final n = c.cups;
    final steps = <List<CupMove>>[];
    for (var i = 0; i < c.swaps; i++) {
      final slots = List<int>.generate(n, (k) => k)..shuffle(rng);
      if (rng.nextDouble() < c.fakes) {
        steps.add([CupMove(slots[0], slots[1], true)]);
        continue;
      }
      final step = [CupMove(slots[0], slots[1], false)];
      if (n >= 4 && rng.nextDouble() < c.doubles) step.add(CupMove(slots[2], slots[3], false));
      steps.add(step);
    }
    return steps;
  }

  void _go(CupStage s) {
    stage = s;
    stageMs = 0;
    safeNotify();
  }

  void _beginStep() {
    for (final cup in cups) {
      cup.moving = false;
      cup.fake = false;
    }
    for (final m in _steps[_stepIdx]) {
      final ca = cups.firstWhere((x) => x.slot == m.a);
      final cb = cups.firstWhere((x) => x.slot == m.b);
      ca
        ..moving = true
        ..from = m.a
        ..to = m.b
        ..arc = 1
        ..fake = m.fake;
      cb
        ..moving = true
        ..from = m.b
        ..to = m.a
        ..arc = -1
        ..fake = m.fake;
    }
  }

  void _endStep() {
    for (final cup in cups) {
      if (cup.moving && !cup.fake) cup.slot = cup.to;
      cup.moving = false;
      cup.fake = false;
    }
  }

  @override
  void update(double dtMs) {
    stageMs += dtMs;
    switch (stage) {
      case CupStage.show:
        if (stageMs >= 1000) _go(CupStage.lower);
      case CupStage.lower:
        if (stageMs >= 280) {
          _go(CupStage.shuffle);
          _beginStep();
        }
      case CupStage.shuffle:
        if (stageMs >= cfg.swapMs) {
          _endStep();
          _stepIdx += 1;
          if (_stepIdx >= _steps.length) {
            _go(CupStage.pick);
            _pickStart = playMs;
          } else {
            stageMs -= cfg.swapMs;
            _beginStep();
          }
        }
      case CupStage.pick:
        if (stageMs >= _kPickTimeoutMs) _resolve(null);
      case CupStage.reveal:
        if (stageMs >= 1100) _afterReveal();
    }
  }

  void tap(int pointer, Offset pos) {
    if (stage != CupStage.pick || phase != MiniPhase.play || menuOpen) return;
    if (pos.dy < baseY - cupH * 1.2 || pos.dy > baseY + cupH * 0.9) return;
    int? best;
    var bestD = double.infinity;
    for (var i = 0; i < cups.length; i++) {
      final d = (cupPose(cups[i]).$1 - pos.dx).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best == null || bestD > cupW * 0.75) return;
    _resolve(best);
  }

  void _resolve(int? index) {
    pickedCup = index;
    final ok = index != null && index == ballCup;
    lastCorrect = ok;
    final (x, y, _) = cupPose(cups[ballCup]);
    if (ok) {
      correct += 1;
      bumpStreak();
      var gained = 100;
      final rt = playMs - _pickStart;
      if (rt < 1500) gained += ((1500 - rt) / 1500 * 50).round();
      String? label;
      if (streak % 4 == 0) {
        gained += 100;
        label = 'Seri x$streak! +$gained';
      }
      addPoints(gained, label: label);
      addFloat('+$gained', Offset(x, y - cupH), Colors.white, size: 20);
      AudioManager.instance.playCorrect();
    } else {
      errors += 1;
      breakStreak();
      addFloat(index == null ? 'Süre doldu!' : 'Yanlış!', Offset(x, y - cupH), const Color(0xFFFFD0D0), size: 20);
      AudioManager.instance.playWrong();
    }
    _go(CupStage.reveal);
  }

  void _afterReveal() {
    if (errors >= _kCupMaxErrors) {
      endRun();
    } else if (round >= _kCupRounds) {
      completed = true;
      endRun();
    } else {
      _startRound();
    }
  }

  @override
  bool get passed => completed && errors < _kCupMaxErrors;

  @override
  String get headlineLabel {
    if (passed) return 'Toplam puanın';
    return '$_kCupMaxErrors kez yanlış bardak';
  }

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('DOĞRU', '$correct/$_kCupRounds'),
        MiniStat('TUR', '$round/$_kCupRounds'),
        MiniStat('HATA', '$errors/$_kCupMaxErrors'),
      ];

  @override
  String get verdict {
    if (errors == 0) return 'Sekiz turda da topu gözünden kaçırmadın. Kartal göz!';
    return 'Hızlanan karıştırmaya rağmen takip ettin. Sahte hamlelere dikkat!';
  }
}

class CupShuffleScreen extends StatelessWidget {
  final GameController app;
  const CupShuffleScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<CupShuffleController>(
      app: app,
      mode: GameMode.cupShuffle,
      create: CupShuffleController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'TUR', value: '${c.round}/$_kCupRounds'),
        HudPill(label: 'HATA', value: '${c.errors}/$_kCupMaxErrors', highlight: c.errors >= 1),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(controller: c, painter: _CupPainter(c), onDown: c.tap),
    );
  }
}

class _CupPainter extends CustomPainter {
  final CupShuffleController c;
  _CupPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    paintPlayfield(canvas, size, const [Color(0xFF6FBF8E), Color(0xFF2F7A52)]);
    if (c.cups.isEmpty || size.isEmpty) return;

    final tableY = c.baseY + c.cupH / 2;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width / 2, tableY), width: size.width * 0.95, height: c.cupH * 0.5),
      Paint()..color = Colors.black.withOpacity(0.10),
    );

    final String prompt = switch (c.stage) {
      CupStage.show || CupStage.lower => 'Topu takip et!',
      CupStage.shuffle => '',
      CupStage.pick => 'Top hangi bardağın altında?',
      CupStage.reveal => c.lastCorrect == true ? 'Doğru!' : 'Buradaydı!',
    };
    if (prompt.isNotEmpty) {
      paintLabel(canvas, prompt, Offset(size.width / 2, size.height * 0.16), 20, Colors.white);
    }

    // Top: bardaginin tabaninda durur ve karistirmada bardakla birlikte
    // hareket eder (kavisli hamlede bardagin altindan gorunmesin).
    final (bx, by, bs) = c.cupPose(c.cups[c.ballCup]);
    final ballR = c.cupW * 0.24 * bs;
    paintGlossBall(
      canvas,
      Offset(bx, by + c.cupH * bs / 2 - ballR),
      ballR,
      const Color(0xFFFFF3B0),
      const Color(0xFFFFB300),
    );

    // Derinlik sirasi: arkaya gidenler once, one gelenler en son.
    final order = List<int>.generate(c.cups.length, (i) => i)
      ..sort((a, b) {
        double key(Cup x) => (c.stage == CupStage.shuffle && x.moving) ? x.arc : 0;
        return key(c.cups[a]).compareTo(key(c.cups[b]));
      });
    for (final i in order) {
      final cup = c.cups[i];
      final (x, y, s) = c.cupPose(cup);
      Color? ring;
      if (c.stage == CupStage.reveal && c.pickedCup == i) {
        ring = c.lastCorrect == true ? const Color(0xFF7CFFB0) : AppColors.red;
      }
      _cup(canvas, Offset(x, y - c.liftOf(i)), c.cupW * s, c.cupH * s, ring);
    }
    paintFloats(canvas, c.floats);
  }

  void _cup(Canvas canvas, Offset center, double w, double h, Color? ring) {
    final top = center.dy - h / 2;
    final bottom = center.dy + h / 2;
    final path = Path()
      ..moveTo(center.dx - w * 0.3, top)
      ..quadraticBezierTo(center.dx, top - h * 0.06, center.dx + w * 0.3, top)
      ..lineTo(center.dx + w * 0.5, bottom)
      ..lineTo(center.dx - w * 0.5, bottom)
      ..close();
    final rect = Rect.fromLTRB(center.dx - w / 2, top, center.dx + w / 2, bottom);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFF8A80), Color(0xFFE53935), Color(0xFFB71C1C)],
        ).createShader(rect),
    );
    // Parlaklik seridi
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - w * 0.2, top + h * 0.1)
        ..lineTo(center.dx - w * 0.12, top + h * 0.1)
        ..lineTo(center.dx - w * 0.24, bottom - h * 0.12)
        ..lineTo(center.dx - w * 0.34, bottom - h * 0.12)
        ..close(),
      Paint()..color = Colors.white.withOpacity(0.35),
    );
    // Agiz kenari
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, bottom), width: w * 1.02, height: h * 0.14),
      Paint()..color = const Color(0xFF8E1616),
    );
    if (ring != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = ring,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CupPainter old) => old.c != c;
}
