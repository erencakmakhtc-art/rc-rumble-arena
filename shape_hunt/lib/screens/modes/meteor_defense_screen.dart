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

/// Gezegen kalkani (0'a inerse oyun biter).
const int _kMeteorShields = 3;

class Meteor {
  final bool big;
  final double radius;
  final double spin;
  Offset pos;
  Offset vel;
  double rot = 0;
  Meteor(this.pos, this.vel, this.radius, this.big, this.spin);
}

class Satellite {
  final double vx;
  Offset pos;
  Satellite(this.pos, this.vx);
}

class SpaceBurst {
  final Offset pos;
  final Color color;
  final double size;
  final double bornMs;
  SpaceBurst(this.pos, this.color, this.size, this.bornMs);
}

class MeteorDefenseController extends ArenaGameController {
  final List<Meteor> meteors = [];
  final List<Satellite> sats = [];
  final List<SpaceBurst> bursts = [];
  int shields = _kMeteorShields;
  bool destroyed = false;
  double endFx = 0;
  int kills = 0;
  int satHits = 0;
  double _nextSpawn = 500;
  double _nextSat = 4000;
  double shieldFlashMs = -9999;

  Offset get planetC => Offset(field.width / 2, field.height + field.width * 0.28);
  double get planetR => field.width * 0.62;
  double get shieldR => planetR + field.height * 0.035;

  @override
  void resetArena() {
    meteors.clear();
    sats.clear();
    bursts.clear();
    shields = _kMeteorShields;
    destroyed = false;
    endFx = 0;
    kills = 0;
    satHits = 0;
    _nextSpawn = 500;
    _nextSat = 4000;
    shieldFlashMs = -9999;
  }

  @override
  void update(double dtMs) {
    final dt = dtMs / 1000;
    bursts.removeWhere((b) => playMs - b.bornMs > 450);
    if (destroyed) {
      endFx += dtMs;
      if (endFx > 650) endRun();
      return;
    }

    final p = progress;
    final w = field.width;
    final h = field.height;

    if (playMs >= _nextSpawn) {
      _spawnMeteor(p);
      // Meteor araligi 0,9 sn -> 0,38 sn.
      _nextSpawn = playMs + 900 - 520 * p + rng.nextInt(120);
    }
    if (playMs >= _nextSat) {
      final fromLeft = rng.nextBool();
      sats.add(Satellite(
        Offset(fromLeft ? -30 : w + 30, h * (0.22 + rng.nextDouble() * 0.33)),
        (fromLeft ? 1 : -1) * w * 0.28,
      ));
      _nextSat = playMs + 3500 + rng.nextDouble() * 1500;
    }

    for (final s in sats) {
      s.pos = s.pos + Offset(s.vx * dt, 0);
    }
    sats.removeWhere((s) => s.pos.dx < -60 || s.pos.dx > w + 60);

    final pc = planetC;
    for (var i = meteors.length - 1; i >= 0; i--) {
      final m = meteors[i];
      m.pos += m.vel * dt;
      m.rot += m.spin * dt;
      if ((m.pos - pc).distance <= shieldR + m.radius * 0.3) {
        meteors.removeAt(i);
        _damage(m.pos, 'Kalkan −1');
        if (destroyed) return;
      } else if (m.pos.dy > h + 60 || m.pos.dx < -80 || m.pos.dx > w + 80) {
        meteors.removeAt(i);
      }
    }
  }

  void _spawnMeteor(double p) {
    final w = field.width;
    final big = rng.nextDouble() < 0.35 + 0.25 * p;
    final r = w * (big ? 0.06 : 0.035);
    final start = Offset(w * (0.1 + rng.nextDouble() * 0.8), -r);
    final pc = planetC;
    // Kalkanin gorunen kismindaki rastgele bir noktaya nisan al.
    final a = -pi / 2 + (rng.nextDouble() * 2 - 1) * 0.55;
    final target = pc + Offset(cos(a), sin(a)) * shieldR;
    final dir = target - start;
    final speed = field.height * (0.22 + 0.28 * p) * (0.85 + rng.nextDouble() * 0.3);
    meteors.add(Meteor(start, dir / dir.distance * speed, r, big, (rng.nextDouble() * 2 - 1) * 3));
  }

  void _damage(Offset at, String text) {
    shields -= 1;
    shieldFlashMs = playMs;
    breakStreak();
    bursts.add(SpaceBurst(at, const Color(0xFF3DF2FF), 40, playMs));
    addFloat(text, at + const Offset(0, -20), const Color(0xFFFF8A8A), size: 16);
    AudioManager.instance.playWrong();
    if (shields <= 0) {
      destroyed = true;
      showToast('Gezegen düştü!', good: false);
    }
    safeNotify();
  }

  void tap(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen || destroyed) return;

    Meteor? best;
    var bestD = double.infinity;
    for (final m in meteors) {
      final d = (m.pos - pos).distance;
      if (d <= m.radius * 1.4 + 10 && d < bestD) {
        best = m;
        bestD = d;
      }
    }
    if (best != null) {
      final m = best;
      meteors.remove(m);
      bumpStreak();
      var gained = m.big ? 40 : 60;
      if (m.big) {
        // Buyuk meteor ikiye bolunur: daha kucuk ve daha hizli parcalar.
        final speed = m.vel.distance * 1.35;
        final base = atan2(m.vel.dy, m.vel.dx);
        for (final da in const [-0.6, 0.6]) {
          final v = Offset(cos(base + da), sin(base + da)) * speed;
          meteors.add(Meteor(m.pos, v, field.width * 0.035, false, (rng.nextDouble() * 2 - 1) * 4));
        }
      } else {
        kills += 1;
      }
      String? label;
      if (streak % 10 == 0) {
        gained += 100;
        label = 'Seri x$streak! +$gained';
      }
      addPoints(gained, label: label);
      bursts.add(SpaceBurst(m.pos, const Color(0xFFFFB74D), m.radius * 2.2, playMs));
      addFloat('+$gained', m.pos, const Color(0xFFFFE08A), size: 15);
      AudioManager.instance.playCorrect();
      safeNotify();
      return;
    }

    for (final s in sats) {
      if ((s.pos - pos).distance < 30) {
        sats.remove(s);
        satHits += 1;
        _damage(s.pos, 'Uyduyu vurdun!');
        return;
      }
    }
  }

  @override
  bool get passed => !destroyed && playMs >= durationMs;

  @override
  String get headlineLabel => passed ? 'Toplam puanın' : 'Gezegen düştü';

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('YOK EDİLEN', '$kills'),
        MiniStat('KALKAN', '$shields/$_kMeteorShields'),
        MiniStat('UYDU HATASI', '$satHits'),
      ];

  @override
  String get verdict {
    if (shields == _kMeteorShields) return 'Kalkana tek çizik bile yok. Galaksinin koruyucusu!';
    return 'Gezegeni kurtardın! Uydulara dokunmamaya dikkat.';
  }
}

class MeteorDefenseScreen extends StatelessWidget {
  final GameController app;
  const MeteorDefenseScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<MeteorDefenseController>(
      app: app,
      mode: GameMode.meteorDefense,
      create: MeteorDefenseController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SÜRE', value: '${c.remainingSec} sn', highlight: c.remainingSec <= 5),
        HudPill(label: 'KALKAN', value: '${c.shields}/$_kMeteorShields', highlight: c.shields <= 1),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(controller: c, painter: _SpacePainter(c), onDown: c.tap),
    );
  }
}

final List<(double, double, double)> _kSpaceStars = () {
  final r = Random(23);
  return [for (var i = 0; i < 60; i++) (r.nextDouble(), r.nextDouble(), 0.5 + r.nextDouble() * 1.3)];
}();

class _SpacePainter extends CustomPainter {
  final MeteorDefenseController c;
  _SpacePainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = c.playMs / 1000;
    paintPlayfield(canvas, size, const [Color(0xFF0B1030), Color(0xFF1B1446)]);

    // Bulutsu + yildizlar
    final neb = Offset(w * 0.25, h * 0.3);
    canvas.drawCircle(
      neb,
      w * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFB04DFF).withOpacity(0.18), Colors.transparent],
        ).createShader(Rect.fromCircle(center: neb, radius: w * 0.5)),
    );
    for (var i = 0; i < _kSpaceStars.length; i++) {
      final (sx, sy, sr) = _kSpaceStars[i];
      final a = 0.4 + 0.35 * sin(t * 1.7 + i * 1.3);
      canvas.drawCircle(Offset(sx * w, sy * h), sr, Paint()..color = Colors.white.withOpacity(a));
    }

    if (size.isEmpty) return;
    final pc = c.planetC;
    final pr = c.planetR;

    // Atmosfer isimasi + gezegen
    canvas.drawCircle(
      pc,
      pr + 18,
      Paint()
        ..color = const Color(0xFF4FC3F7).withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    final planetRect = Rect.fromCircle(center: pc, radius: pr);
    canvas.drawCircle(
      pc,
      pr,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.7),
          colors: [Color(0xFF6FD3FF), Color(0xFF1565C0)],
        ).createShader(planetRect),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(planetRect));
    final land = Paint()..color = const Color(0xFF66BB6A).withOpacity(0.85);
    canvas.drawOval(Rect.fromCenter(center: pc + Offset(-pr * 0.35, -pr * 0.82), width: pr * 0.5, height: pr * 0.18), land);
    canvas.drawOval(Rect.fromCenter(center: pc + Offset(pr * 0.3, -pr * 0.9), width: pr * 0.36, height: pr * 0.12), land);
    canvas.drawOval(Rect.fromCenter(center: pc + Offset(pr * 0.05, -pr * 0.72), width: pr * 0.28, height: pr * 0.1), land);
    canvas.restore();

    // Kalkan parcalari (kalanlar)
    final flash = (c.playMs - c.shieldFlashMs) < 300;
    final segs = [-pi / 2 - 0.62, -pi / 2 - 0.2, -pi / 2 + 0.22];
    final keep = c.shields.clamp(0, 3);
    for (var i = 0; i < 3; i++) {
      final alive = (i == 1 && keep >= 1) || (i == 0 && keep >= 2) || (i == 2 && keep >= 3);
      if (!alive) continue;
      final rect = Rect.fromCircle(center: pc, radius: c.shieldR);
      canvas.drawArc(
        rect,
        segs[i],
        0.38,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = const Color(0xFF3DF2FF).withOpacity(flash ? 0.7 : 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawArc(
        rect,
        segs[i],
        0.38,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF3DF2FF),
      );
    }

    for (final s in c.sats) {
      _satellite(canvas, s.pos, t);
    }
    for (final m in c.meteors) {
      _meteor(canvas, m);
    }
    for (final b in c.bursts) {
      final k = ((c.playMs - b.bornMs) / 450).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(b.pos, b.size * (0.4 + 0.8 * k), Paint()..color = b.color.withOpacity(0.45 * (1 - k)));
      canvas.drawCircle(
        b.pos,
        b.size * (0.6 + 1.0 * k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - k)
          ..color = Colors.white.withOpacity(1 - k),
      );
    }
    if (c.destroyed) {
      final k = (c.endFx / 650).clamp(0.0, 1.0).toDouble();
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF5A5A).withOpacity(0.35 * (1 - k)));
    }
    paintFloats(canvas, c.floats);
  }

  void _meteor(Canvas canvas, Meteor m) {
    final len = m.vel.distance;
    if (len > 0) {
      final back = -m.vel / len;
      final perp = Offset(-back.dy, back.dx);
      final tail = m.pos + back * m.radius * 4;
      final path = Path()
        ..moveTo(m.pos.dx + perp.dx * m.radius * 0.8, m.pos.dy + perp.dy * m.radius * 0.8)
        ..lineTo(tail.dx, tail.dy)
        ..lineTo(m.pos.dx - perp.dx * m.radius * 0.8, m.pos.dy - perp.dy * m.radius * 0.8)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [const Color(0xFFFFB74D).withOpacity(0.85), const Color(0xFFFF5722).withOpacity(0.0)],
          ).createShader(Rect.fromPoints(m.pos, tail)),
      );
    }
    canvas.save();
    canvas.translate(m.pos.dx, m.pos.dy);
    canvas.rotate(m.rot);
    final r = m.radius;
    paintGlossBall(canvas, Offset.zero, r, m.big ? const Color(0xFFC9A28A) : const Color(0xFFB8AFA6),
        m.big ? const Color(0xFF6B3F2A) : const Color(0xFF5D554E));
    final crater = Paint()..color = Colors.black.withOpacity(0.22);
    canvas.drawCircle(Offset(r * 0.3, r * 0.2), r * 0.22, crater);
    canvas.drawCircle(Offset(-r * 0.35, r * 0.35), r * 0.14, crater);
    canvas.restore();
  }

  void _satellite(Canvas canvas, Offset c0, double t) {
    final panel = Paint()..color = const Color(0xFF3F7BE6);
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1;
    for (final dx in const [-26.0, 14.0]) {
      final r = Rect.fromLTWH(c0.dx + dx, c0.dy - 6, 12, 12);
      canvas.drawRect(r, panel);
      canvas.drawLine(Offset(r.center.dx, r.top), Offset(r.center.dx, r.bottom), grid);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: c0, width: 16, height: 14), const Radius.circular(3)),
      Paint()..color = const Color(0xFFFFC857),
    );
    canvas.drawLine(c0 + const Offset(0, -7), c0 + const Offset(4, -15), Paint()
      ..color = const Color(0xFFE8ECF7)
      ..strokeWidth = 1.5);
    if (sin(t * 10) > 0) canvas.drawCircle(c0 + const Offset(4, -16), 2.2, Paint()..color = const Color(0xFFFF5A5A));
  }

  @override
  bool shouldRepaint(covariant _SpacePainter old) => old.c != c;
}
