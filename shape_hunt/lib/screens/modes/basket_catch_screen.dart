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

/// Gecme sarti: 20 saniyede (3 kotu sey yakalamadan) ulasilmasi gereken puan.
const int _kBasketTarget = 1400;

/// Bu kadar kotu sey (tas / curuk elma) yakalanirsa oyun biter.
const int _kBasketMaxErrors = 3;

class FallingItem {
  final FruitKind kind;
  final double radius;
  final double speed;
  final double wobbleAmp;
  final double wobbleFreq;
  final double phase;
  final double spin;
  final double x0;
  double y;
  double ageMs = 0;

  FallingItem({
    required this.kind,
    required this.radius,
    required this.speed,
    required this.wobbleAmp,
    required this.wobbleFreq,
    required this.phase,
    required this.spin,
    required this.x0,
    required this.y,
  });

  double get x => x0 + sin(ageMs / 1000 * wobbleFreq + phase) * wobbleAmp;
  bool get bad => kind == FruitKind.rock || kind == FruitKind.rotten;
}

class BasketCatchController extends ArenaGameController {
  final List<FallingItem> items = [];
  double basketX = -1;
  double _nextSpawnMs = 0;
  int caught = 0;
  int missedGood = 0;
  int errors = 0;
  double flashBadMs = -9999;

  double get basketW => field.width * 0.26;
  double get basketTop => field.height - 70;

  @override
  void resetArena() {
    items.clear();
    basketX = -1;
    _nextSpawnMs = 400;
    caught = 0;
    missedGood = 0;
    errors = 0;
    flashBadMs = -9999;
  }

  @override
  void update(double dtMs) {
    final dt = dtMs / 1000;
    if (basketX < 0) basketX = field.width / 2;

    if (playMs >= _nextSpawnMs) {
      _spawn();
      final p = progress;
      // Dusus araligi 620ms -> 260ms.
      _nextSpawnMs = playMs + 620 - 360 * p + rng.nextInt(100);
    }

    final half = basketW / 2;
    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i];
      it.ageMs += dtMs;
      it.y += it.speed * dt;

      final atRim = it.y + it.radius >= basketTop && it.y - it.radius <= basketTop + 16;
      if (atRim && (it.x - basketX).abs() < half + it.radius * 0.3) {
        items.removeAt(i);
        _catch(it);
        if (phase != MiniPhase.play) return;
        continue;
      }
      if (it.y - it.radius > field.height) {
        items.removeAt(i);
        if (!it.bad) {
          missedGood += 1;
          breakStreak();
        }
      }
    }
  }

  void _spawn() {
    final p = progress;
    final w = field.width;
    final FruitKind kind;
    if (rng.nextDouble() < 0.25 + 0.2 * p) {
      kind = rng.nextDouble() < 0.55 ? FruitKind.rock : FruitKind.rotten;
    } else {
      final r = rng.nextDouble();
      if (r < 0.05) {
        kind = FruitKind.star;
      } else if (r < 0.2) {
        kind = FruitKind.kiwi;
      } else {
        const common = [FruitKind.apple, FruitKind.orange, FruitKind.lemon];
        kind = common[rng.nextInt(common.length)];
      }
    }
    final radius = w * (kind == FruitKind.kiwi ? 0.045 : 0.06);
    // 8. saniyeden sonra dusen seyler saga sola salinir.
    final wobble = playMs > 8000 ? w * 0.08 * p * rng.nextDouble() : 0.0;
    items.add(FallingItem(
      kind: kind,
      radius: radius,
      speed: field.height * (0.45 + 0.6 * p) * (0.85 + rng.nextDouble() * 0.3),
      wobbleAmp: wobble,
      wobbleFreq: 2 + rng.nextDouble() * 2,
      phase: rng.nextDouble() * pi * 2,
      spin: (rng.nextDouble() * 2 - 1) * 2,
      x0: radius + wobble + rng.nextDouble() * max(1.0, w - 2 * (radius + wobble)),
      y: -radius,
    ));
  }

  void _catch(FallingItem it) {
    final at = Offset(it.x, basketTop);
    if (it.bad) {
      errors += 1;
      breakStreak();
      flashBadMs = playMs;
      addPoints(-150, label: it.kind == FruitKind.rock ? 'Taş! −150' : 'Çürük! −150', good: false);
      addFloat('−150', at, AppColors.red);
      AudioManager.instance.playWrong();
      if (errors >= _kBasketMaxErrors) {
        endRun();
        return;
      }
      safeNotify();
      return;
    }
    caught += 1;
    bumpStreak();
    var gained = switch (it.kind) {
      FruitKind.star => 150,
      FruitKind.kiwi => 80,
      _ => 50,
    };
    String? label;
    if (streak % 10 == 0) {
      gained += 100;
      label = 'Seri x$streak! +$gained';
    }
    addPoints(gained, label: label);
    addFloat('+$gained', at, AppColors.ink);
    AudioManager.instance.playCorrect();
    safeNotify();
  }

  void drag(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen) return;
    final half = basketW / 2;
    basketX = pos.dx.clamp(half, field.width - half).toDouble();
  }

  @override
  bool get passed => errors < _kBasketMaxErrors && points >= _kBasketTarget;

  @override
  String get headlineLabel {
    if (passed) return 'Toplam puanın';
    if (errors >= _kBasketMaxErrors) return '$_kBasketMaxErrors kötü şey yakaladın';
    return '$_kBasketTarget puana ulaşamadın';
  }

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('YAKALANAN', '$caught'),
        MiniStat('KAÇAN', '$missedGood'),
        MiniStat('HATA', '$errors/$_kBasketMaxErrors'),
      ];

  @override
  String get verdict {
    if (errors == 0 && missedGood <= 2) return 'Sepetin mıknatıs gibi. Neredeyse hiçbir şey kaçmadı!';
    if (errors == 0) return 'Tek bir taş bile almadın. Harika seçicilik!';
    return 'Hedefi geçtin! Çürük elmalara dikkat, elmaya çok benziyorlar.';
  }
}

class BasketCatchScreen extends StatelessWidget {
  final GameController app;
  const BasketCatchScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<BasketCatchController>(
      app: app,
      mode: GameMode.basketCatch,
      create: BasketCatchController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SÜRE', value: '${c.remainingSec} sn', highlight: c.remainingSec <= 5),
        HudPill(label: 'HATA', value: '${c.errors}/$_kBasketMaxErrors', highlight: c.errors >= 2),
        HudPill(label: 'PUAN', value: '${c.points}/$_kBasketTarget', highlight: true),
      ],
      body: (c) => ArenaView(
        controller: c,
        painter: _BasketPainter(c),
        onDown: c.drag,
        onMove: c.drag,
      ),
    );
  }
}

class _BasketPainter extends CustomPainter {
  final BasketCatchController c;
  _BasketPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    paintPlayfield(canvas, size, const [Color(0xFFE3F4FF), Color(0xFFBFE3FA)]);
    // Yavasca suzulen bulutlar
    final drift = c.playMs / 1000 * 8;
    _cloud(canvas, Offset((size.width * 0.2 + drift) % (size.width + 120) - 60, size.height * 0.14), 1.0);
    _cloud(canvas, Offset((size.width * 0.75 + drift * 0.6) % (size.width + 120) - 60, size.height * 0.3), 0.75);
    _cloud(canvas, Offset((size.width * 0.45 + drift * 0.8) % (size.width + 120) - 60, size.height * 0.5), 0.6);
    // Cimen
    final grass = Rect.fromLTWH(0, size.height - 26, size.width, 26);
    canvas.drawRect(grass, Paint()..color = const Color(0xFF7CC957));

    final t = c.playMs / 1000;
    for (final it in c.items) {
      paintFruit(canvas, it.kind, Offset(it.x, it.y), it.radius, it.spin * t);
    }

    final bx = c.basketX < 0 ? size.width / 2 : c.basketX;
    _basket(canvas, bx, c.basketTop, c.basketW);

    final since = c.playMs - c.flashBadMs;
    if (since >= 0 && since < 250) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFFF5A5A).withOpacity(0.35 * (1 - since / 250)),
      );
    }
    paintFloats(canvas, c.floats);
  }

  void _cloud(Canvas canvas, Offset c0, double k) {
    final p = Paint()..color = Colors.white.withOpacity(0.75);
    canvas.drawCircle(c0, 18 * k, p);
    canvas.drawCircle(c0 + Offset(20 * k, 4 * k), 14 * k, p);
    canvas.drawCircle(c0 + Offset(-20 * k, 5 * k), 13 * k, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(c0.dx - 32 * k, c0.dy + 2 * k, c0.dx + 34 * k, c0.dy + 18 * k),
        Radius.circular(9 * k),
      ),
      p,
    );
  }

  void _basket(Canvas canvas, double cx, double top, double w) {
    const h = 48.0;
    final path = Path()
      ..moveTo(cx - w / 2, top)
      ..lineTo(cx + w / 2, top)
      ..lineTo(cx + w * 0.38, top + h)
      ..lineTo(cx - w * 0.38, top + h)
      ..close();
    final rect = Rect.fromLTWH(cx - w / 2, top, w, h);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD7A15E), Color(0xFF9C6A2E)],
        ).createShader(rect),
    );
    // Orgu cizgileri
    canvas.save();
    canvas.clipPath(path);
    final weave = Paint()
      ..color = const Color(0xFF7A4F1E).withOpacity(0.5)
      ..strokeWidth = 2;
    for (var y = top + 12; y < top + h; y += 12) {
      canvas.drawLine(Offset(cx - w / 2, y), Offset(cx + w / 2, y), weave);
    }
    for (var x = cx - w / 2; x < cx + w / 2; x += 14) {
      canvas.drawLine(Offset(x, top), Offset(x + 6, top + h), weave);
    }
    canvas.restore();
    // Kenar
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - w / 2 - 4, top - 6, w + 8, 10), const Radius.circular(5)),
      Paint()..color = const Color(0xFF8A5A24),
    );
  }

  @override
  bool shouldRepaint(covariant _BasketPainter old) => old.c != c;
}
