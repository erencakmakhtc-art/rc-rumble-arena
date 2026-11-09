import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/arena_base.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../models/game_mode.dart';
import '../../widgets/arena_view.dart';
import '../../widgets/mini_kit.dart';
import '../../widgets/mode_host.dart';

/// Gecme sarti: 20 saniyede bombaya dokunmadan ulasilmasi gereken puan.
const int _kFruitTarget = 2200;

class FlyingFruit {
  final FruitKind kind;
  final double radius;
  final double spin;
  Offset pos;
  Offset vel;
  double rot;
  FlyingFruit(this.kind, this.radius, this.pos, this.vel, this.rot, this.spin);
  bool get isBomb => kind == FruitKind.bomb;
}

/// Kesilen meyvenin iki yarisindan biri.
class FruitHalf {
  final FruitKind kind;
  final double radius;
  final double spin;
  final bool upper;
  Offset pos;
  Offset vel;
  double rot;
  double ageMs = 0;
  FruitHalf(this.kind, this.radius, this.pos, this.vel, this.rot, this.spin, this.upper);
}

/// Meyve suyu / patlama parcacigi.
class Particle {
  final double radius;
  final Color color;
  final double lifeMs;
  Offset pos;
  Offset vel;
  double ageMs = 0;
  Particle(this.pos, this.vel, this.radius, this.color, this.lifeMs);
}

class FruitSliceController extends ArenaGameController {
  final List<FlyingFruit> fruits = [];
  final List<FruitHalf> halves = [];
  final List<Particle> particles = [];

  /// Parmak izleri (kilic izi): parmak -> [(konum, zaman)].
  final Map<int, List<(Offset, double)>> trails = {};
  final Map<int, Offset> _last = {};
  final Map<int, int> _swipeCuts = {};

  double _nextWaveMs = 0;
  int sliced = 0;
  int missed = 0;
  int bestCombo = 0;
  bool bombHit = false;
  double boomMs = 0;
  Offset? boomAt;

  double get gravity => field.height * 1.5;

  @override
  void resetArena() {
    fruits.clear();
    halves.clear();
    particles.clear();
    trails.clear();
    _last.clear();
    _swipeCuts.clear();
    _nextWaveMs = 500;
    sliced = 0;
    missed = 0;
    bestCombo = 0;
    bombHit = false;
    boomMs = 0;
    boomAt = null;
  }

  @override
  void update(double dtMs) {
    final dt = dtMs / 1000;
    if (bombHit) {
      boomMs += dtMs;
      _updateBits(dt, dtMs);
      if (boomMs > 600) endRun();
      return;
    }

    if (playMs >= _nextWaveMs) _launchWave();

    final h = field.height;
    for (var i = fruits.length - 1; i >= 0; i--) {
      final f = fruits[i];
      f.vel = Offset(f.vel.dx, f.vel.dy + gravity * dt);
      f.pos += f.vel * dt;
      f.rot += f.spin * dt;
      if (f.vel.dy > 0 && f.pos.dy - f.radius > h) {
        fruits.removeAt(i);
        if (!f.isBomb) {
          missed += 1;
          breakStreak();
        }
      }
    }
    _updateBits(dt, dtMs);
    for (final list in trails.values) {
      list.removeWhere((e) => playMs - e.$2 > 140);
    }
  }

  void _updateBits(double dt, double dtMs) {
    for (final hf in halves) {
      hf.vel = Offset(hf.vel.dx, hf.vel.dy + gravity * dt);
      hf.pos += hf.vel * dt;
      hf.rot += hf.spin * dt;
      hf.ageMs += dtMs;
    }
    halves.removeWhere((x) => x.ageMs > 1000);
    for (final p in particles) {
      p.vel = Offset(p.vel.dx * 0.98, p.vel.dy + gravity * 0.5 * dt);
      p.pos += p.vel * dt;
      p.ageMs += dtMs;
    }
    particles.removeWhere((p) => p.ageMs > p.lifeMs);
  }

  void _launchWave() {
    final p = progress;
    // Dalga buyuklugu 1 -> 4'e cikar; bombalar meyvelerle ayni dalgada gelir.
    final n = 1 + rng.nextInt(1 + (3 * p).floor());
    for (var i = 0; i < n; i++) {
      _launch(_randomFruit());
    }
    if (playMs > 2000 && rng.nextDouble() < 0.18 + 0.22 * p) _launch(FruitKind.bomb);
    // Dalga araligi 1,0 sn -> 0,52 sn.
    _nextWaveMs = playMs + 1000 - 480 * p + rng.nextInt(150);
  }

  FruitKind _randomFruit() {
    final r = rng.nextDouble();
    if (r < 0.05) return FruitKind.star;
    if (r < 0.25) return FruitKind.kiwi;
    if (r < 0.45) return FruitKind.lemon;
    const common = [FruitKind.apple, FruitKind.orange, FruitKind.watermelon];
    return common[rng.nextInt(common.length)];
  }

  void _launch(FruitKind kind) {
    final w = field.width;
    final h = field.height;
    final base = w * 0.075;
    final radius = switch (kind) {
      FruitKind.watermelon => base * 1.3,
      FruitKind.kiwi => base * 0.72,
      FruitKind.star => base * 0.85,
      FruitKind.lemon => base * 0.8,
      _ => base,
    };
    final x = w * (0.12 + rng.nextDouble() * 0.76);
    final startY = h + radius;
    final apexY = h * (0.1 + rng.nextDouble() * 0.32);
    final vy = -sqrt(2 * gravity * (startY - apexY));
    final flight = 2 * (-vy) / gravity;
    final targetX = w * (0.2 + rng.nextDouble() * 0.6);
    final vx = (targetX - x) / flight * 1.2;
    fruits.add(FlyingFruit(
      kind,
      radius,
      Offset(x, startY),
      Offset(vx, vy),
      rng.nextDouble() * pi * 2,
      (rng.nextDouble() * 2 - 1) * 4,
    ));
  }

  // ------------------------------------------------------------------
  // Dokunus / kesme
  // ------------------------------------------------------------------

  bool get _canCut => phase == MiniPhase.play && !menuOpen && !bombHit;

  void down(int pointer, Offset pos) {
    if (!_canCut) return;
    _last[pointer] = pos;
    trails[pointer] = [(pos, playMs)];
    _swipeCuts[pointer] = 0;
  }

  void move(int pointer, Offset pos) {
    if (!_canCut) return;
    final prev = _last[pointer];
    if (prev == null) return;
    _last[pointer] = pos;
    trails[pointer]?.add((pos, playMs));
    if ((pos - prev).distance < 2) return;

    for (var i = fruits.length - 1; i >= 0; i--) {
      final f = fruits[i];
      if (_segDist(prev, pos, f.pos) > f.radius * 0.95) continue;
      fruits.removeAt(i);
      if (f.isBomb) {
        _explode(f);
        return;
      }
      _cut(f, pos - prev, pointer);
    }
  }

  void up(int pointer) {
    final n = _swipeCuts.remove(pointer) ?? 0;
    _last.remove(pointer);
    trails.remove(pointer);
    if (n > bestCombo) bestCombo = n;
    if (n >= 3 && _canCut) {
      final bonus = 40 * n;
      addPoints(bonus, label: 'Kombo x$n! +$bonus');
      safeNotify();
    }
  }

  double _segDist(Offset a, Offset b, Offset p) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0).toDouble();
    return (p - (a + ab * t)).distance;
  }

  void _cut(FlyingFruit f, Offset dir, int pointer) {
    sliced += 1;
    _swipeCuts[pointer] = (_swipeCuts[pointer] ?? 0) + 1;
    bumpStreak();

    var gained = switch (f.kind) {
      FruitKind.star => 150,
      FruitKind.kiwi => 80,
      FruitKind.lemon => 60,
      FruitKind.watermelon => 40,
      _ => 50,
    };
    String? label;
    if (streak >= 10 && streak % 10 == 0) {
      gained += 100;
      label = 'Seri x$streak! +$gained';
    }
    addPoints(gained, label: label);
    addFloat('+$gained', f.pos, f.kind == FruitKind.star ? const Color(0xFFFFE680) : Colors.white);

    final len = dir.distance;
    final d = len == 0 ? const Offset(1, 0) : dir / len;
    final perp = Offset(-d.dy, d.dx);
    final push = field.width * 0.35;
    final angle = atan2(d.dy, d.dx);
    halves.add(FruitHalf(f.kind, f.radius, f.pos, f.vel * 0.4 - perp * push, angle, -3, true));
    halves.add(FruitHalf(f.kind, f.radius, f.pos, f.vel * 0.4 + perp * push, angle, 3, false));

    final flesh = fruitFlesh(f.kind);
    for (var i = 0; i < 8; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = field.width * (0.2 + rng.nextDouble() * 0.5);
      particles.add(Particle(f.pos, Offset(cos(a) * sp, sin(a) * sp), f.radius * 0.14, flesh, 420));
    }
    AudioManager.instance.playCorrect();
    safeNotify();
  }

  void _explode(FlyingFruit b) {
    bombHit = true;
    boomAt = b.pos;
    breakStreak();
    for (var i = 0; i < 22; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = field.width * (0.4 + rng.nextDouble() * 0.9);
      final color = i.isEven ? const Color(0xFFFF8F00) : const Color(0xFF5E6178);
      particles.add(Particle(b.pos, Offset(cos(a) * sp, sin(a) * sp), b.radius * 0.2, color, 600));
    }
    AudioManager.instance.playWrong();
    showToast('BOMBA! Oyun bitti', good: false);
    safeNotify();
  }

  // ------------------------------------------------------------------
  // Sonuc
  // ------------------------------------------------------------------

  @override
  bool get passed => !bombHit && points >= _kFruitTarget;

  int get accuracy {
    final total = sliced + missed;
    return total == 0 ? 0 : (sliced / total * 100).round();
  }

  @override
  String get headlineLabel {
    if (passed) return 'Toplam puanın';
    if (bombHit) return 'Bombayı kestin!';
    return '$_kFruitTarget puana ulaşamadın';
  }

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('KESİLEN', '$sliced'),
        MiniStat('İSABET', '%$accuracy'),
        MiniStat('EN İYİ KOMBO', '$bestCombo'),
      ];

  @override
  String get verdict {
    if (bestCombo >= 5) return 'Tek hamlede $bestCombo meyve! Bıçak gibi keskinsin.';
    if (accuracy >= 90) return 'Neredeyse hiçbir meyve kaçmadı. Harika!';
    return 'Bombalardan kaçıp hedefi geçtin. Kombo yaparsan puan katlanır.';
  }
}

class FruitSliceScreen extends StatelessWidget {
  final GameController app;
  const FruitSliceScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<FruitSliceController>(
      app: app,
      mode: GameMode.fruitSlice,
      create: FruitSliceController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SÜRE', value: '${c.remainingSec} sn', highlight: c.remainingSec <= 5),
        HudPill(label: 'PUAN', value: '${c.points}/$_kFruitTarget', highlight: true),
      ],
      body: (c) => ArenaView(
        controller: c,
        painter: _FruitPainter(c),
        onDown: c.down,
        onMove: c.move,
        onUp: c.up,
      ),
    );
  }
}

class _FruitPainter extends CustomPainter {
  final FruitSliceController c;
  _FruitPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    // Ahsap kesme tahtasi
    paintPlayfield(canvas, size, const [Color(0xFFC49468), Color(0xFF8A5E3B)]);
    final plank = Paint()
      ..color = const Color(0xFF6E4A2E).withOpacity(0.35)
      ..strokeWidth = 2;
    for (var i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), plank);
    }

    final t = c.playMs / 1000;

    for (final h in c.halves) {
      canvas.save();
      canvas.translate(h.pos.dx, h.pos.dy);
      canvas.rotate(h.rot);
      final r = h.radius * 1.6;
      canvas.clipRect(h.upper ? Rect.fromLTRB(-r, -r, r, 0) : Rect.fromLTRB(-r, 0, r, r));
      paintFruit(canvas, h.kind, Offset.zero, h.radius, 0);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: h.radius * 1.9, height: h.radius * 0.5),
        Paint()..color = fruitFlesh(h.kind),
      );
      canvas.restore();
    }

    for (final f in c.fruits) {
      paintFruit(canvas, f.kind, f.pos, f.radius, f.rot, t: t);
    }

    for (final p in c.particles) {
      final k = 1 - (p.ageMs / p.lifeMs).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(p.pos, p.radius * (0.5 + 0.5 * k), Paint()..color = p.color.withOpacity(k));
    }

    // Kilic izi
    for (final list in c.trails.values) {
      if (list.length < 2) continue;
      for (var i = 1; i < list.length; i++) {
        final k = i / list.length;
        canvas.drawLine(
          list[i - 1].$1,
          list[i].$1,
          Paint()
            ..color = Colors.white.withOpacity(0.35 + 0.6 * k)
            ..strokeWidth = 2 + 9 * k
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Bomba patlamasi
    final at = c.boomAt;
    if (c.bombHit && at != null) {
      final k = (c.boomMs / 600).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        at,
        size.width * (0.1 + 0.9 * k),
        Paint()..color = const Color(0xFFFFB74D).withOpacity(0.55 * (1 - k)),
      );
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withOpacity(0.5 * (1 - k)));
    }

    paintFloats(canvas, c.floats);
  }

  @override
  bool shouldRepaint(covariant _FruitPainter old) => old.c != c;
}
