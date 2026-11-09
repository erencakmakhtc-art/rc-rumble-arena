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

/// Gecme sarti: 20 saniye carpmadan hayatta kalip bu kadar puan toplamak.
const int _kRunTarget = 1300;

/// Yildiz basina puan.
const int _kStarPoints = 100;

class LaneObj {
  final int lane;
  final bool star;
  double y;
  LaneObj(this.lane, this.star, this.y);
}

class LaneRunnerController extends ArenaGameController {
  final List<LaneObj> objs = [];

  /// Hedef serit (0..2) ve gorsel (kayan) serit konumu.
  int lane = 1;
  double laneX = 1;

  double _nextRowMs = 0;
  bool crashed = false;
  double crashMs = 0;
  int stars = 0;
  int starsSeen = 0;
  double roadOffset = 0;

  double get unit => field.width / 3;
  double get playerY => field.height * 0.84;
  double get obstacleH => unit * 0.5;

  /// Kayma hizi alan yuksekligine oranli: saniyede 0,55H -> 1,3H.
  double get speed => field.height * (0.55 + 0.75 * progress);

  double laneCenter(double l) => unit * (l + 0.5);

  @override
  void resetArena() {
    objs.clear();
    lane = 1;
    laneX = 1;
    _nextRowMs = 700;
    crashed = false;
    crashMs = 0;
    stars = 0;
    starsSeen = 0;
    roadOffset = 0;
  }

  @override
  void update(double dtMs) {
    final dt = dtMs / 1000;
    if (crashed) {
      crashMs += dtMs;
      if (crashMs > 550) endRun();
      return;
    }

    laneX += (lane - laneX) * min(1.0, dt * 18);
    roadOffset = (roadOffset + speed * dt) % 60;

    if (playMs >= _nextRowMs) {
      _spawnRow();
      final p = progress;
      _nextRowMs = playMs + 900 - 500 * p + rng.nextInt(120);
    }

    final px = laneCenter(laneX);
    final py = playerY;
    for (var i = objs.length - 1; i >= 0; i--) {
      final o = objs[i];
      o.y += speed * dt;
      if (o.y > field.height + obstacleH) {
        objs.removeAt(i);
        continue;
      }
      final ox = laneCenter(o.lane.toDouble());
      if ((ox - px).abs() > unit * 0.42) continue;
      final reach = o.star ? unit * 0.32 : obstacleH / 2 + unit * 0.18;
      if ((o.y - py).abs() > reach) continue;

      if (o.star) {
        objs.removeAt(i);
        stars += 1;
        bumpStreak();
        addPoints(_kStarPoints);
        addFloat('+$_kStarPoints', Offset(ox, o.y), const Color(0xFF8A5A00));
        AudioManager.instance.playCorrect();
        safeNotify();
      } else {
        crashed = true;
        breakStreak();
        AudioManager.instance.playWrong();
        showToast('ÇARPTIN!', good: false);
        safeNotify();
        return;
      }
    }
  }

  void _spawnRow() {
    final p = progress;
    final y = -obstacleH;
    final lanes = [0, 1, 2]..shuffle(rng);

    if (rng.nextDouble() < 0.25 + 0.35 * p) {
      // Iki engel, tek bosluk. Yildiz cogu zaman boslukta: oraya gecmek zorunlu.
      objs.add(LaneObj(lanes[0], false, y));
      objs.add(LaneObj(lanes[1], false, y));
      if (rng.nextDouble() < 0.6) _addStar(lanes[2], y);
    } else {
      objs.add(LaneObj(lanes[0], false, y));
      if (rng.nextDouble() < 0.75) {
        // Yildiz bazen engelin hemen arkasinda (riskli gecis).
        final behind = p > 0.35 && rng.nextDouble() < 0.3;
        _addStar(behind ? lanes[0] : lanes[1], behind ? y - unit * 1.1 : y);
      }
    }
  }

  void _addStar(int l, double y) {
    objs.add(LaneObj(l, true, y));
    starsSeen += 1;
  }

  void tap(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen || crashed) return;
    if (pos.dx < field.width / 2) {
      lane = max(0, lane - 1);
    } else {
      lane = min(2, lane + 1);
    }
  }

  @override
  bool get passed => !crashed && points >= _kRunTarget;

  @override
  String get headlineLabel {
    if (passed) return 'Toplam puanın';
    if (crashed) return 'Engele çarptın';
    return '$_kRunTarget puana ulaşamadın';
  }

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('YILDIZ', '$stars'),
        MiniStat('TOPLAMA', starsSeen == 0 ? '—' : '%${(stars / starsSeen * 100).round()}'),
        MiniStat('SÜRE', '${(playMs / 1000).toStringAsFixed(1)} sn'),
      ];

  @override
  String get verdict {
    if (starsSeen > 0 && stars == starsSeen) return 'Tek bir yıldız bile kaçmadı. Kusursuz koşu!';
    if (stars / max(1, starsSeen) > 0.85) return 'Hem kaçtın hem topladın. Çok iyi!';
    return 'Hayatta kaldın ve hedefi geçtin. Riskli yıldızlar puanı katlar.';
  }
}

class LaneRunnerScreen extends StatelessWidget {
  final GameController app;
  const LaneRunnerScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<LaneRunnerController>(
      app: app,
      mode: GameMode.laneRunner,
      create: LaneRunnerController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SÜRE', value: '${c.remainingSec} sn', highlight: c.remainingSec <= 5),
        HudPill(label: 'PUAN', value: '${c.points}/$_kRunTarget', highlight: true),
      ],
      body: (c) => ArenaView(controller: c, painter: _RunPainter(c), onDown: c.tap),
    );
  }
}

class _RunPainter extends CustomPainter {
  final LaneRunnerController c;
  _RunPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    paintPlayfield(canvas, size, const [Color(0xFF7A80B8), Color(0xFF4D5288)]);
    final unit = size.width / 3;

    // Yol kenarlari: koyu banket + beyaz kenar cizgisi + kayan reflektorler
    final shoulder = Paint()..color = const Color(0xFF3E4276);
    canvas.drawRect(Rect.fromLTWH(0, 0, 7, size.height), shoulder);
    canvas.drawRect(Rect.fromLTWH(size.width - 7, 0, 7, size.height), shoulder);
    final edge = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(9, 0), Offset(9, size.height), edge);
    canvas.drawLine(Offset(size.width - 9, 0), Offset(size.width - 9, size.height), edge);
    final reflector = Paint()..color = const Color(0xFFFFC857);
    for (var y = -60.0 + c.roadOffset; y < size.height; y += 60) {
      canvas.drawCircle(Offset(3.5, y + 30), 2.2, reflector);
      canvas.drawCircle(Offset(size.width - 3.5, y + 30), 2.2, reflector);
    }

    // Serit cizgileri (kayar)
    final dash = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var l = 1; l < 3; l++) {
      final x = unit * l;
      for (var y = -60.0 + c.roadOffset; y < size.height; y += 60) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 28), dash);
      }
    }

    // Dokunma ipucu (sol/sag yarim)
    if (c.playMs < 2500) {
      paintLabel(canvas, '◀ sol', Offset(size.width * 0.25, size.height * 0.95), 14, Colors.white.withOpacity(0.7));
      paintLabel(canvas, 'sağ ▶', Offset(size.width * 0.75, size.height * 0.95), 14, Colors.white.withOpacity(0.7));
    }

    final t = c.playMs / 1000;
    for (final o in c.objs) {
      final cx = c.laneCenter(o.lane.toDouble());
      if (o.star) {
        paintFruit(canvas, FruitKind.star, Offset(cx, o.y), unit * 0.2, sin(t * 3) * 0.3);
      } else {
        _barrier(canvas, Offset(cx, o.y), unit * 0.8, c.obstacleH);
      }
    }

    _runner(canvas, Offset(c.laneCenter(c.laneX), c.playerY), unit * 0.24, t);

    if (c.crashed) {
      final k = (c.crashMs / 550).clamp(0.0, 1.0).toDouble();
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF5A5A).withOpacity(0.45 * (1 - k)));
    }
    paintFloats(canvas, c.floats);
  }

  void _barrier(Canvas canvas, Offset c0, double w, double h) {
    final rect = Rect.fromCenter(center: c0, width: w, height: h);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(h * 0.25));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFF8A1F));
    canvas.save();
    canvas.clipRRect(rr);
    final stripe = Paint()..color = Colors.white.withOpacity(0.9);
    for (var x = rect.left - h; x < rect.right + h; x += h * 0.9) {
      canvas.drawPath(
        Path()
          ..moveTo(x, rect.bottom)
          ..lineTo(x + h * 0.45, rect.bottom)
          ..lineTo(x + h * 0.9, rect.top)
          ..lineTo(x + h * 0.45, rect.top)
          ..close(),
        stripe,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFB85300),
    );
  }

  void _runner(Canvas canvas, Offset c0, double r, double t) {
    final bob = sin(t * 14) * r * 0.08;
    final body = c0 + Offset(0, bob);
    // Golge
    canvas.drawOval(
      Rect.fromCenter(center: c0 + Offset(0, r * 1.05), width: r * 1.6, height: r * 0.4),
      Paint()..color = Colors.black.withOpacity(0.2),
    );
    paintGlossBall(canvas, body, r, const Color(0xFFFFE082), const Color(0xFFFFA000));
    final eye = Paint()..color = const Color(0xFF3F2A00);
    if (c.crashed) {
      final x = Paint()
        ..color = const Color(0xFF3F2A00)
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round;
      for (final ex in [-0.32, 0.32]) {
        final e = body + Offset(r * ex, -r * 0.1);
        canvas.drawLine(e + Offset(-r * 0.1, -r * 0.1), e + Offset(r * 0.1, r * 0.1), x);
        canvas.drawLine(e + Offset(-r * 0.1, r * 0.1), e + Offset(r * 0.1, -r * 0.1), x);
      }
    } else {
      canvas.drawCircle(body + Offset(-r * 0.32, -r * 0.1), r * 0.12, eye);
      canvas.drawCircle(body + Offset(r * 0.32, -r * 0.1), r * 0.12, eye);
    }
    canvas.drawOval(
      Rect.fromCenter(center: body + Offset(-r * 0.5, r * 0.25), width: r * 0.3, height: r * 0.16),
      Paint()..color = const Color(0xFFFF8A80).withOpacity(0.7),
    );
    canvas.drawOval(
      Rect.fromCenter(center: body + Offset(r * 0.5, r * 0.25), width: r * 0.3, height: r * 0.16),
      Paint()..color = const Color(0xFFFF8A80).withOpacity(0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _RunPainter old) => old.c != c;
}
