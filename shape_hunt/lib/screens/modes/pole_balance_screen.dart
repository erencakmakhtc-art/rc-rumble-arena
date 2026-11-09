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

/// Cubuk bu aciyi (radyan, ~57°) gecerse devrilir.
const double _kPoleFailRad = 1.0;

/// Parmak kaldirildiktan sonra geri koymak icin taninan sure (ms).
const double _kPoleLiftGraceMs = 200;

/// Bu acinin altinda cubuk "dik" sayilir ve ekstra puan verir (radyan).
const double _kPoleSteadyRad = 0.1;

class PoleBalanceController extends ArenaGameController {
  double theta = 0;
  double omega = 0;
  double cartX = -1;
  double _cartV = 0;
  double _acc = 0;
  double _targetX = 0;

  int? _pointer;
  bool needFinger = true;
  bool started = false;
  double? _liftedAt;
  bool fell = false;
  bool lifted = false;
  double endFx = 0;

  double wind = 0;
  double windUntil = -1;
  double _nextGust = 6000;
  int gusts = 0;

  double _pointAcc = 0;
  double steadyMs = 0;

  @override
  bool get waiting => needFinger;

  /// Cubuk boyu zamanla kisalir: kisa cubuk daha hizli devrilir.
  double get poleLen => field.height * (0.42 - 0.14 * progress);
  double get gravity => field.height * 1.8;
  double get railY => field.height * 0.8;
  bool get windActive => playMs < windUntil;

  @override
  void resetArena() {
    theta = (rng.nextBool() ? 1 : -1) * 0.05;
    omega = 0;
    cartX = -1;
    _cartV = 0;
    _acc = 0;
    _pointer = null;
    needFinger = true;
    started = false;
    _liftedAt = null;
    fell = false;
    lifted = false;
    endFx = 0;
    wind = 0;
    windUntil = -1;
    _nextGust = 6000;
    gusts = 0;
    _pointAcc = 0;
    steadyMs = 0;
  }

  @override
  void onResume(int pausedMs) {
    super.onResume(pausedMs);
    if (_pointer == null && started && !fell && !lifted) {
      needFinger = true;
      _liftedAt = null;
    }
  }

  double _clampX(double x) => x.clamp(field.width * 0.08, field.width * 0.92).toDouble();

  @override
  void update(double dtMs) {
    final dt = dtMs / 1000;
    if (fell || lifted) {
      endFx += dtMs;
      if (fell) {
        omega += gravity / poleLen * sin(theta) * dt;
        theta = (theta + omega * dt).clamp(-pi / 2, pi / 2).toDouble();
      }
      if (endFx > 550) endRun();
      return;
    }

    final la = _liftedAt;
    if (la != null && playMs - la > _kPoleLiftGraceMs) {
      lifted = true;
      AudioManager.instance.playWrong();
      showToast('Parmağını kaldırdın!', good: false);
      safeNotify();
      return;
    }

    // Puan: her 100 ms'de 10, cubuk dikse +5.
    final steady = theta.abs() < _kPoleSteadyRad;
    if (steady) steadyMs += dtMs;
    _pointAcc += dtMs;
    while (_pointAcc >= 100) {
      _pointAcc -= 100;
      addPoints(steady ? 15 : 10);
    }

    // Araba parmagi yumusakca takip eder; ivmesi cubugu etkiler.
    if (cartX < 0) cartX = _targetX;
    final prevX = cartX;
    final prevV = _cartV;
    cartX += (_targetX - cartX) * min(1.0, dt * 22);
    _cartV = (cartX - prevX) / dt;
    final rawA = ((_cartV - prevV) / dt).clamp(-field.width * 60, field.width * 60).toDouble();
    _acc += (rawA - _acc) * min(1.0, dt * 30);

    // Ruzgar: 6. saniyeden sonra rastgele aralikla kisa ruzgarlar.
    if (playMs >= _nextGust) {
      wind = (rng.nextBool() ? 1 : -1) * gravity * (0.25 + 0.3 * progress);
      windUntil = playMs + 700;
      _nextGust = playMs + 2400 + rng.nextDouble() * 1400;
      gusts += 1;
      addFloat(wind > 0 ? 'Rüzgâr →' : '← Rüzgâr', Offset(field.width / 2, field.height * 0.12),
          const Color(0xFFFFE08A), size: 18);
    }
    final windAcc = windActive ? wind : 0.0;

    // Ters sarkac: theta'' = (g sin(theta) - a cos(theta) + ruzgar cos(theta)) / L
    final l = poleLen;
    final alpha = (gravity * sin(theta) - _acc * cos(theta) + windAcc * cos(theta)) / l;
    omega += alpha * dt;
    omega *= (1 - 0.25 * dt);
    theta += omega * dt;

    if (theta.abs() > _kPoleFailRad) {
      fell = true;
      breakStreak();
      AudioManager.instance.playWrong();
      showToast('Çubuk devrildi!', good: false);
      safeNotify();
    }
  }

  void down(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen || fell || lifted || _pointer != null) return;
    _pointer = pointer;
    _targetX = _clampX(pos.dx);
    _liftedAt = null;
    if (needFinger) {
      if (!started) {
        cartX = _targetX;
        _cartV = 0;
        _acc = 0;
      }
      needFinger = false;
      started = true;
      safeNotify();
    }
  }

  void move(int pointer, Offset pos) {
    if (pointer != _pointer) return;
    _targetX = _clampX(pos.dx);
  }

  void up(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    if (started && !needFinger && !fell && !lifted && phase == MiniPhase.play) _liftedAt = playMs;
  }

  @override
  bool get passed => started && !fell && !lifted && playMs >= durationMs;

  int get steadyPct => playMs <= 0 ? 0 : (steadyMs / playMs * 100).round();

  @override
  String get headlineLabel {
    if (passed) return 'Toplam puanın';
    if (lifted) return 'Parmağını kaldırdın';
    return 'Çubuk devrildi';
  }

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('SÜRE', '${(playMs / 1000).toStringAsFixed(1)} sn'),
        MiniStat('DİK', '%$steadyPct'),
        MiniStat('RÜZGÂR', '$gusts'),
      ];

  @override
  String get verdict {
    if (steadyPct >= 60) return 'Çubuk neredeyse hiç sallanmadı. Cambaz gibisin!';
    return '20 saniye boyunca dengede tuttun. Dik tuttukça daha çok puan!';
  }
}

class PoleBalanceScreen extends StatelessWidget {
  final GameController app;
  const PoleBalanceScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<PoleBalanceController>(
      app: app,
      mode: GameMode.poleBalance,
      create: PoleBalanceController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SÜRE', value: '${c.remainingSec} sn', highlight: c.remainingSec <= 5),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(
        controller: c,
        painter: _PolePainter(c),
        onDown: c.down,
        onMove: c.move,
        onUp: c.up,
      ),
    );
  }
}

class _PolePainter extends CustomPainter {
  final PoleBalanceController c;
  _PolePainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Sirk sahnesi: koyu perde + spot isigi
    paintPlayfield(canvas, size, const [Color(0xFF3B1E5E), Color(0xFF1E0F33)]);
    final curtain = Paint()..color = const Color(0xFF5E1F3F).withOpacity(0.55);
    for (var i = 0; i < 7; i++) {
      final x = w * i / 6;
      canvas.drawPath(
        Path()
          ..moveTo(x - 18, 0)
          ..quadraticBezierTo(x, h * 0.08, x + 18, 0)
          ..close(),
        curtain,
      );
    }
    final cx = c.cartX < 0 ? w / 2 : c.cartX;
    final spot = Path()
      ..moveTo(cx - w * 0.06, 0)
      ..lineTo(cx + w * 0.06, 0)
      ..lineTo(cx + w * 0.34, c.railY)
      ..lineTo(cx - w * 0.34, c.railY)
      ..close();
    canvas.drawPath(
      spot,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFFFF4C2).withOpacity(0.28), const Color(0xFFFFF4C2).withOpacity(0.05)],
        ).createShader(Rect.fromLTWH(0, 0, w, c.railY)),
    );

    // Zemin + ray
    final floor = Rect.fromLTWH(0, c.railY + 14, w, h - c.railY - 14);
    canvas.drawRect(floor, Paint()..color = const Color(0xFF2A1640));
    canvas.drawLine(
      Offset(w * 0.05, c.railY + 14),
      Offset(w * 0.95, c.railY + 14),
      Paint()
        ..color = const Color(0xFFB39AF2)
        ..strokeWidth = 3,
    );

    // Egim gostergesi (ust yarim daire)
    final gC = Offset(w / 2, h * 0.2);
    final gR = w * 0.16;
    canvas.drawArc(
      Rect.fromCircle(center: gC, radius: gR),
      pi,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white.withOpacity(0.18),
    );
    final safe = _kPoleSteadyRad / (pi / 2) * (pi / 2);
    canvas.drawArc(
      Rect.fromCircle(center: gC, radius: gR),
      -pi / 2 - safe,
      safe * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xFF7CFFB0).withOpacity(0.7),
    );
    final needleA = -pi / 2 + c.theta.clamp(-pi / 2, pi / 2).toDouble();
    canvas.drawLine(
      gC,
      gC + Offset(cos(needleA), sin(needleA)) * (gR - 4),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Ruzgar cizgileri
    if (c.windActive) {
      final dir = c.wind > 0 ? 1.0 : -1.0;
      final streak = Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final t = c.playMs / 1000;
      for (var i = 0; i < 8; i++) {
        final y = h * (0.28 + i * 0.06);
        final x = ((t * 900 * dir + i * 97) % (w + 80) + (w + 80)) % (w + 80) - 40;
        canvas.drawLine(Offset(x, y), Offset(x - dir * 36, y), streak);
      }
    }

    // Araba
    final cartY = c.railY;
    final cartRect = Rect.fromCenter(center: Offset(cx, cartY), width: w * 0.2, height: 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cartRect, const Radius.circular(8)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6B6B), Color(0xFFB71C1C)],
        ).createShader(cartRect),
    );
    final wheel = Paint()..color = const Color(0xFFFFD24D);
    canvas.drawCircle(Offset(cartRect.left + 12, cartY + 11), 6, wheel);
    canvas.drawCircle(Offset(cartRect.right - 12, cartY + 11), 6, wheel);

    // Cubuk (seker cubugu seritli) + tepede agirlik topu
    final l = c.poleLen;
    final pivot = Offset(cx, cartY - 8);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(c.theta);
    final pole = Rect.fromLTWH(-5, -l, 10, l);
    final danger = c.theta.abs() > 0.6;
    canvas.drawRRect(RRect.fromRectAndRadius(pole, const Radius.circular(5)), Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(pole, const Radius.circular(5)));
    final stripe = Paint()..color = danger ? AppColors.red : const Color(0xFFE8559C);
    for (var y = -l; y < 0; y += 18) {
      canvas.drawPath(
        Path()
          ..moveTo(-6, y)
          ..lineTo(6, y - 8)
          ..lineTo(6, y - 1)
          ..lineTo(-6, y + 7)
          ..close(),
        stripe,
      );
    }
    canvas.restore();
    paintGlossBall(canvas, Offset(0, -l), 14, const Color(0xFFFFF1A8), const Color(0xFFE0A800));
    canvas.restore();

    if (c.needFinger && c.phase == MiniPhase.play) {
      paintPrompt(canvas, size, c.started ? 'Parmağını geri koy' : 'Parmağını koy, çubuğu dik tut!');
    }
    if (c.fell || c.lifted) {
      final k = (c.endFx / 550).clamp(0.0, 1.0).toDouble();
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF5A5A).withOpacity(0.35 * (1 - k)));
    }
    paintFloats(canvas, c.floats);
  }

  @override
  bool shouldRepaint(covariant _PolePainter old) => old.c != c;
}
