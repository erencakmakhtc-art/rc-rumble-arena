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

/// Toplarin oyuna girdigi anlar (ms): 1 top ile baslar, 4 topa cikar.
const List<double> _kKeepSpawns = [0, 4000, 9000, 14000];

/// Yeni top gelmeden once ustte uyari gosterilir (ms).
const double _kKeepWarnMs = 700;

const List<(Color, Color)> _kKeepColors = [
  (Color(0xFFFF9A9A), Color(0xFFD9303A)),
  (Color(0xFF9AD0FF), Color(0xFF2E78D0)),
  (Color(0xFFB8F08A), Color(0xFF4E9A1C)),
  (Color(0xFFD6B8FF), Color(0xFF7446C8)),
];

class KeepBall {
  final int colorIdx;
  Offset pos;
  Offset vel;
  double lastTapMs = -9999;
  KeepBall(this.pos, this.vel, this.colorIdx);
}

class KeepUpController extends ArenaGameController {
  final List<KeepBall> balls = [];
  int _spawned = 0;
  double? warnX;
  bool dropped = false;
  double endFx = 0;
  Offset? dropAt;
  int bounces = 0;
  int saves = 0;

  /// Yercekimi zamanla artar, toplar kuculur.
  double get gravity => field.height * (1.15 + 0.55 * progress);
  double get ballR => field.width * (0.085 - 0.02 * progress);

  @override
  void resetArena() {
    balls.clear();
    _spawned = 0;
    warnX = null;
    dropped = false;
    endFx = 0;
    dropAt = null;
    bounces = 0;
    saves = 0;
  }

  @override
  void update(double dtMs) {
    final dt = dtMs / 1000;
    if (dropped) {
      endFx += dtMs;
      if (endFx > 500) endRun();
      return;
    }

    final w = field.width;
    final h = field.height;
    final r = ballR;

    if (_spawned < _kKeepSpawns.length) {
      final at = _kKeepSpawns[_spawned];
      if (warnX == null && playMs >= at - _kKeepWarnMs) {
        warnX = w * (0.2 + rng.nextDouble() * 0.6);
      }
      if (playMs >= at) {
        balls.add(KeepBall(Offset(warnX ?? w / 2, -r), Offset(0, h * 0.1), _spawned % _kKeepColors.length));
        _spawned += 1;
        warnX = null;
        safeNotify();
      }
    }

    final g = gravity;
    for (final b in balls) {
      var vx = b.vel.dx;
      var vy = b.vel.dy + g * dt;
      var x = b.pos.dx + vx * dt;
      var y = b.pos.dy + vy * dt;
      if (x < r && vx < 0) {
        x = r;
        vx = -vx * 0.85;
      } else if (x > w - r && vx > 0) {
        x = w - r;
        vx = -vx * 0.85;
      }
      // Tavandan yumusak sekme (yukaridan giren toplar etkilenmez).
      if (y < r && vy < 0) vy = -vy * 0.4;
      b.pos = Offset(x, y);
      b.vel = Offset(vx, vy);

      if (y + r >= h) {
        dropped = true;
        dropAt = Offset(x, h - r);
        breakStreak();
        AudioManager.instance.playWrong();
        showToast('Top düştü!', good: false);
        safeNotify();
        return;
      }
    }
  }

  void tap(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen || dropped) return;
    final r = ballR;
    KeepBall? best;
    var bestD = double.infinity;
    for (final b in balls) {
      if (playMs - b.lastTapMs < 120) continue;
      final d = (b.pos - pos).distance;
      if (d <= r * 1.35 + 8 && d < bestD) {
        best = b;
        bestD = d;
      }
    }
    if (best == null) return;

    final b = best;
    b.lastTapMs = playMs;
    // Topun kenarina dokunmak onu ters yone iter.
    final off = ((b.pos.dx - pos.dx) / r).clamp(-1.0, 1.0).toDouble();
    b.vel = Offset(off * field.width * 0.55 + b.vel.dx * 0.3, -field.height * 1.05);
    bounces += 1;
    bumpStreak();

    var gained = 20;
    var text = '+20';
    if (b.pos.dy > field.height * 0.82) {
      saves += 1;
      gained += 60;
      text = 'Kurtarış! +80';
    }
    String? label;
    if (streak % 10 == 0) {
      gained += 100;
      label = 'Seri x$streak! +$gained';
    }
    addPoints(gained, label: label);
    addFloat(text, b.pos + Offset(0, -r * 1.4), AppColors.ink, size: 15);
    AudioManager.instance.playClick();
    safeNotify();
  }

  @override
  bool get passed => !dropped && playMs >= durationMs;

  @override
  String get headlineLabel => passed ? 'Toplam puanın' : 'Top yere düştü';

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('SEKTİRME', '$bounces'),
        MiniStat('KURTARIŞ', '$saves'),
        MiniStat('SÜRE', '${(playMs / 1000).toStringAsFixed(1)} sn'),
      ];

  @override
  String get verdict {
    if (saves >= 8) return '$saves son saniye kurtarışı! Kaleci refleksi.';
    return 'Dört topu da havada tuttun. Tam bir hokkabaz!';
  }
}

class KeepUpScreen extends StatelessWidget {
  final GameController app;
  const KeepUpScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<KeepUpController>(
      app: app,
      mode: GameMode.keepUp,
      create: KeepUpController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SÜRE', value: '${c.remainingSec} sn', highlight: c.remainingSec <= 5),
        HudPill(label: 'TOP', value: '${c.balls.length}/${_kKeepSpawns.length}'),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(controller: c, painter: _KeepPainter(c), onDown: c.tap),
    );
  }
}

class _KeepPainter extends CustomPainter {
  final KeepUpController c;
  _KeepPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    paintPlayfield(canvas, size, const [Color(0xFFFFF6E6), Color(0xFFFFD9AE)]);

    // Tehlike bolgesi (zemin)
    final zone = Rect.fromLTWH(0, size.height - 14, size.width, 14);
    canvas.drawRect(zone, Paint()..color = const Color(0xFFFF6B5A).withOpacity(0.55));
    final stripe = Paint()..color = Colors.white.withOpacity(0.6);
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawPath(
        Path()
          ..moveTo(x, size.height)
          ..lineTo(x + 10, size.height)
          ..lineTo(x + 20, size.height - 14)
          ..lineTo(x + 10, size.height - 14)
          ..close(),
        stripe,
      );
    }

    final t = c.playMs / 1000;
    final wx = c.warnX;
    if (wx != null) {
      final k = 0.5 + 0.5 * sin(t * 18);
      final p = Paint()..color = AppColors.red.withOpacity(0.5 + 0.4 * k);
      canvas.drawPath(
        Path()
          ..moveTo(wx - 14, 8)
          ..lineTo(wx + 14, 8)
          ..lineTo(wx, 26)
          ..close(),
        p,
      );
    }

    final r = c.ballR;
    for (final b in c.balls) {
      // Golge (yere yaklastikca koyulasir)
      final near = (b.pos.dy / size.height).clamp(0.0, 1.0).toDouble();
      canvas.drawOval(
        Rect.fromCenter(center: Offset(b.pos.dx, size.height - 16), width: r * 1.6 * near, height: r * 0.35 * near),
        Paint()..color = Colors.black.withOpacity(0.18 * near),
      );
      final (light, dark) = _kKeepColors[b.colorIdx];
      paintGlossBall(canvas, b.pos, r, light, dark);
      // Plaj topu seridi
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: b.pos, radius: r)));
      canvas.drawRect(
        Rect.fromCenter(center: b.pos, width: r * 2, height: r * 0.34),
        Paint()..color = Colors.white.withOpacity(0.7),
      );
      canvas.restore();
    }

    final at = c.dropAt;
    if (c.dropped && at != null) {
      final k = (c.endFx / 500).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        at,
        r * (1 + 2 * k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * (1 - k)
          ..color = AppColors.red.withOpacity(1 - k),
      );
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF5A5A).withOpacity(0.35 * (1 - k)));
    }
    paintFloats(canvas, c.floats);
  }

  @override
  bool shouldRepaint(covariant _KeepPainter old) => old.c != c;
}
