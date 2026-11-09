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

/// Parmagin carpisma yaricapi (px).
const double _kFingerR = 14;

/// Parmak kaldirildiktan sonra geri koymak icin taninan sure (ms).
const double _kLiftGraceMs = 150;

/// En fazla top sayisi.
const int _kMaxBalls = 9;

/// Yeni top ekleme araligi (ms) ve belirmeden once uyari suresi.
const double _kBallEveryMs = 2500;
const double _kWarnMs = 600;

class DodgeBall {
  final double radius;
  final bool homing;
  final double activeAt;
  Offset pos;
  Offset vel;
  double nearCooldown = 0;
  DodgeBall(this.pos, this.vel, this.radius, this.homing, this.activeAt);
}

class FingerDodgeController extends ArenaGameController {
  final List<DodgeBall> balls = [];
  Offset? finger;
  int? _pointer;
  bool needFinger = true;
  bool started = false;
  double? _liftedAt;
  bool hit = false;
  bool lifted = false;
  double endFx = 0;
  int nearMisses = 0;
  double _nextBallMs = 0;
  double _survivalAcc = 0;

  @override
  bool get waiting => needFinger;

  double get _speed => field.width * (0.45 + 0.40 * progress);

  @override
  void resetArena() {
    balls.clear();
    finger = null;
    _pointer = null;
    needFinger = true;
    started = false;
    _liftedAt = null;
    hit = false;
    lifted = false;
    endFx = 0;
    nearMisses = 0;
    _nextBallMs = _kBallEveryMs;
    _survivalAcc = 0;
  }

  /// Menuden donuste parmak ekranda degilse yeniden "parmagini koy" beklenir
  /// (menuye basmak icin parmak kaldirilmis olabilir; bu ceza sayilmaz).
  @override
  void onResume(int pausedMs) {
    super.onResume(pausedMs);
    if (_pointer == null && started && !hit && !lifted) {
      needFinger = true;
      _liftedAt = null;
    }
  }

  @override
  void update(double dtMs) {
    final dt = dtMs / 1000;
    if (hit || lifted) {
      endFx += dtMs;
      if (endFx > 450) endRun();
      return;
    }

    final la = _liftedAt;
    if (la != null && playMs - la > _kLiftGraceMs) {
      lifted = true;
      AudioManager.instance.playWrong();
      showToast('Parmağını kaldırdın!', good: false);
      safeNotify();
      return;
    }

    // Hayatta kalma puani: her 100 ms'de 10 puan.
    _survivalAcc += dtMs;
    while (_survivalAcc >= 100) {
      _survivalAcc -= 100;
      addPoints(10);
    }

    if (playMs >= _nextBallMs && balls.length < _kMaxBalls) {
      _spawnBall(playMs + _kWarnMs);
      _nextBallMs += _kBallEveryMs;
    }

    final f = finger;
    final w = field.width;
    final h = field.height;
    final sp = _speed;
    for (final b in balls) {
      if (playMs < b.activeAt) continue;
      b.nearCooldown = max(0.0, b.nearCooldown - dtMs);

      var v = b.vel;
      if (b.homing && f != null) {
        // Takipci top: yonunu yavasca parmaga cevirir.
        final to = f - b.pos;
        final d = to.distance;
        if (d > 1) {
          final desired = to / d * v.distance;
          final k = min(1.0, dt * 0.9);
          v = v + (desired - v) * k;
        }
      }
      // Hiz, oyun ilerledikce artan hedef hiza oturur.
      final len = v.distance;
      if (len > 0) v = v / len * sp * (b.homing ? 0.8 : 1.0);
      b.vel = v;
      b.pos += v * dt;

      var dx = b.vel.dx;
      var dy = b.vel.dy;
      if (b.pos.dx < b.radius && dx < 0) dx = -dx;
      if (b.pos.dx > w - b.radius && dx > 0) dx = -dx;
      if (b.pos.dy < b.radius && dy < 0) dy = -dy;
      if (b.pos.dy > h - b.radius && dy > 0) dy = -dy;
      b.vel = Offset(dx, dy);

      if (f == null) continue;
      final dist = (b.pos - f).distance;
      if (dist < b.radius + _kFingerR) {
        hit = true;
        breakStreak();
        AudioManager.instance.playWrong();
        showToast('Yakalandın!', good: false);
        safeNotify();
        return;
      }
      if (dist < b.radius + _kFingerR + 30 && b.nearCooldown <= 0) {
        b.nearCooldown = 900;
        nearMisses += 1;
        addPoints(50);
        addFloat('Kıl payı! +50', f + const Offset(0, -34), const Color(0xFF7A4AD0), size: 15);
      }
    }
  }

  void _spawnBall(double activeAt) {
    final w = field.width;
    final h = field.height;
    final f = finger ?? Offset(w / 2, h / 2);
    final r = w * 0.055;
    // Parmaktan uzak bir kenar noktasi sec (adil baslangic).
    Offset pos = Offset(r, r);
    for (var i = 0; i < 16; i++) {
      pos = Offset(r + rng.nextDouble() * (w - 2 * r), r + rng.nextDouble() * (h - 2 * r));
      if ((pos - f).distance > min(w, h) * 0.45) break;
    }
    final a = rng.nextDouble() * pi * 2;
    final homing = playMs > 6000 && rng.nextDouble() < 0.3;
    balls.add(DodgeBall(pos, Offset(cos(a), sin(a)) * _speed, r, homing, activeAt));
  }

  void down(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen || hit || lifted) return;
    if (_pointer != null) return;
    _pointer = pointer;
    finger = pos;
    _liftedAt = null;
    if (needFinger) {
      needFinger = false;
      if (!started) {
        started = true;
        for (var i = 0; i < 3; i++) {
          _spawnBall(0);
        }
      }
      safeNotify();
    }
  }

  void move(int pointer, Offset pos) {
    if (pointer != _pointer) return;
    finger = Offset(
      pos.dx.clamp(0.0, field.width).toDouble(),
      pos.dy.clamp(0.0, field.height).toDouble(),
    );
  }

  void up(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    if (started && !hit && !lifted && !needFinger && phase == MiniPhase.play) {
      _liftedAt = playMs;
    }
  }

  @override
  bool get passed => started && !hit && !lifted && playMs >= durationMs;

  @override
  String get headlineLabel {
    if (passed) return 'Toplam puanın';
    if (hit) return 'Bir top parmağına değdi';
    if (lifted) return 'Parmağını kaldırdın';
    return 'Tamamlanmadı';
  }

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('SÜRE', '${(playMs / 1000).toStringAsFixed(1)} sn'),
        MiniStat('KIL PAYI', '$nearMisses'),
        MiniStat('TOP', '${balls.length}'),
      ];

  @override
  String get verdict {
    if (nearMisses >= 10) return '$nearMisses kez kıl payı! Tehlikeyle dans ediyorsun.';
    return '20 saniye boyunca dokunulmaz oldun. Kıl payı geçişler ekstra puan getirir.';
  }
}

class FingerDodgeScreen extends StatelessWidget {
  final GameController app;
  const FingerDodgeScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<FingerDodgeController>(
      app: app,
      mode: GameMode.fingerDodge,
      create: FingerDodgeController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SÜRE', value: '${c.remainingSec} sn', highlight: c.remainingSec <= 5),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(
        controller: c,
        painter: _DodgePainter(c),
        onDown: c.down,
        onMove: c.move,
        onUp: c.up,
      ),
    );
  }
}

class _DodgePainter extends CustomPainter {
  final FingerDodgeController c;
  _DodgePainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    paintPlayfield(canvas, size, const [Color(0xFFF3EEFF), Color(0xFFDCD2FA)]);
    final now = c.playMs;
    final pulse = 0.5 + 0.5 * sin(now / 1000 * 12);

    for (final b in c.balls) {
      if (now < b.activeAt) {
        // Belirme uyarisi
        canvas.drawCircle(
          b.pos,
          b.radius * (1.2 + 0.3 * pulse),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = AppColors.red.withOpacity(0.4 + 0.4 * pulse),
        );
        continue;
      }
      if (b.homing) {
        paintGlossBall(canvas, b.pos, b.radius, const Color(0xFFC9A7FF), const Color(0xFF6A3FD0));
        final eye = Paint()..color = Colors.white;
        final dir = b.vel.distance > 0 ? b.vel / b.vel.distance : const Offset(1, 0);
        canvas.drawCircle(b.pos + dir * b.radius * 0.35, b.radius * 0.28, eye);
        canvas.drawCircle(b.pos + dir * b.radius * 0.45, b.radius * 0.13, Paint()..color = const Color(0xFF1A1240));
      } else {
        paintGlossBall(canvas, b.pos, b.radius, const Color(0xFFFF9A9A), const Color(0xFFD9303A));
      }
    }

    final f = c.finger;
    if (f != null && !c.needFinger) {
      canvas.drawCircle(f, _kFingerR + 10, Paint()..color = AppColors.ink.withOpacity(0.12));
      canvas.drawCircle(
        f,
        _kFingerR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = c.hit ? AppColors.red : AppColors.ink,
      );
    }

    if (c.needFinger && c.phase == MiniPhase.play) {
      paintPrompt(canvas, size, c.started ? 'Parmağını geri koy' : 'Parmağını ekrana koy ve kaldırma!');
    }
    if (c.hit || c.lifted) {
      final k = (c.endFx / 450).clamp(0.0, 1.0).toDouble();
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF5A5A).withOpacity(0.4 * (1 - k)));
    }
    paintFloats(canvas, c.floats);
  }

  @override
  bool shouldRepaint(covariant _DodgePainter old) => old.c != c;
}
