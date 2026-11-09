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

/// Gecilmesi gereken kopru sayisi.
const int _kBridgeGoal = 15;

/// Bu kadar dususte oyun biter (yani 1 dusus hakki var).
const int _kBridgeMaxFalls = 2;

/// Cubuk ucu platform merkezine bu kadar yakinsa "mukemmel" (px).
const double _kBridgePerfectPx = 5;

enum BridgeStage { idle, growing, falling, walking, shifting, dropping }

class BridgeBuilderController extends ArenaGameController {
  @override
  bool get timed => false;

  @override
  int get durationMs => 600000;

  // Dunya koordinatlari (px); ekrana cizerken camX cikarilir.
  double curX = 0;
  double curW = 0;
  double nextX = 0;
  double nextW = 0;
  double stick = 0;
  double stickAngle = 0;
  double heroX = 0;
  double heroDrop = 0;
  double camX = 0;
  double _camFrom = 0;
  double _camTo = 0;

  BridgeStage stage = BridgeStage.idle;
  double stageMs = 0;
  double _holdStart = 0;
  int? _holdPointer;
  bool _success = false;
  bool _needLayout = true;

  int crossed = 0;
  int falls = 0;
  int perfects = 0;
  bool completed = false;

  double get pillarTop => field.height * 0.68;
  double get heroR => field.width * 0.035;
  double get edge => curX + curW;

  /// Cubugun uzama hizi (px/sn): her koprude artar.
  double get growSpeed => field.width * (0.9 + 0.03 * crossed);

  @override
  void resetArena() {
    crossed = 0;
    falls = 0;
    perfects = 0;
    completed = false;
    stage = BridgeStage.idle;
    stageMs = 0;
    stick = 0;
    stickAngle = 0;
    heroDrop = 0;
    camX = 0;
    _holdPointer = null;
    _needLayout = true;
  }

  void _layout() {
    final w = field.width;
    curW = w * 0.2;
    curX = w * 0.05;
    camX = 0;
    heroX = edge - heroR - 2;
    _makeNext();
  }

  void _makeNext() {
    final w = field.width;
    final gap = w * (0.15 + rng.nextDouble() * 0.4);
    final pw = max(0.06, 0.2 - 0.006 * crossed) * w * (0.8 + rng.nextDouble() * 0.4);
    nextX = edge + gap;
    nextW = pw;
  }

  void _go(BridgeStage s) {
    stage = s;
    stageMs = 0;
    safeNotify();
  }

  @override
  void update(double dtMs) {
    if (_needLayout) {
      _layout();
      _needLayout = false;
    }
    final dt = dtMs / 1000;
    stageMs += dtMs;

    switch (stage) {
      case BridgeStage.idle:
        break;
      case BridgeStage.growing:
        stick = max(0.0, growSpeed * (playMs - _holdStart) / 1000);
        stick = min(stick, field.width * 1.2);
      case BridgeStage.falling:
        stickAngle = min(pi / 2, pi / 2 * stageMs / 260);
        if (stageMs >= 260) _evaluate();
      case BridgeStage.walking:
        final target = _success ? nextX + nextW - heroR - 2 : edge + stick;
        heroX = min(target, heroX + field.width * 1.3 * dt);
        if (heroX >= target) {
          if (_success) {
            _camFrom = camX;
            _camTo = nextX - field.width * 0.05;
            _go(BridgeStage.shifting);
          } else {
            AudioManager.instance.playWrong();
            _go(BridgeStage.dropping);
          }
        }
      case BridgeStage.shifting:
        final k = (stageMs / 350).clamp(0.0, 1.0).toDouble();
        final q = -2 * k + 2;
        final e = k < 0.5 ? 2 * k * k : 1 - q * q / 2;
        camX = _camFrom + (_camTo - _camFrom) * e;
        if (k >= 1) {
          curX = nextX;
          curW = nextW;
          crossed += 1;
          stick = 0;
          stickAngle = 0;
          if (crossed >= _kBridgeGoal) {
            completed = true;
            endRun();
            return;
          }
          _makeNext();
          _go(BridgeStage.idle);
        }
      case BridgeStage.dropping:
        heroDrop += field.height * 2.2 * dt * (stageMs / 300 + 0.5);
        stickAngle = min(pi, pi / 2 + pi / 2 * stageMs / 400);
        if (stageMs >= 650) {
          falls += 1;
          if (falls >= _kBridgeMaxFalls) {
            endRun();
            return;
          }
          stick = 0;
          stickAngle = 0;
          heroDrop = 0;
          heroX = edge - heroR - 2;
          showToast('Bir hakkın kaldı!', good: false);
          _go(BridgeStage.idle);
        }
    }
  }

  void _evaluate() {
    final end = edge + stick;
    _success = end >= nextX && end <= nextX + nextW;
    if (_success) {
      final perfect = (end - (nextX + nextW / 2)).abs() <= _kBridgePerfectPx;
      bumpStreak();
      var gained = 100;
      if (perfect) {
        perfects += 1;
        gained += 100;
        addFloat('Mükemmel! +$gained', Offset(nextX + nextW / 2 - camX, pillarTop - 40), const Color(0xFFB3261E), size: 17);
      } else {
        addFloat('+$gained', Offset(nextX + nextW / 2 - camX, pillarTop - 40), const Color(0xFF3F4478));
      }
      addPoints(gained);
      AudioManager.instance.playCorrect();
    } else {
      breakStreak();
      addFloat(end < nextX ? 'Kısa kaldı!' : 'Çok uzun!', Offset(edge + stick - camX, pillarTop - 40), const Color(0xFFB3261E));
    }
    _go(BridgeStage.walking);
  }

  void down(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen || stage != BridgeStage.idle || _holdPointer != null) return;
    _holdPointer = pointer;
    _holdStart = nowMs;
    stick = 0;
    _go(BridgeStage.growing);
  }

  void up(int pointer) {
    if (pointer != _holdPointer) return;
    _holdPointer = null;
    if (stage != BridgeStage.growing) return;
    stick = min(field.width * 1.2, max(0.0, growSpeed * (nowMs - _holdStart) / 1000));
    AudioManager.instance.playClick();
    _go(BridgeStage.falling);
  }

  /// Menuye basmak icin parmak kalktiysa buyume yarim kalmasin.
  @override
  void onPause() {
    super.onPause();
    if (stage == BridgeStage.growing) {
      _holdPointer = null;
      stick = 0;
      stage = BridgeStage.idle;
    }
  }

  @override
  bool get passed => completed;

  @override
  String get headlineLabel => passed ? 'Toplam puanın' : '$_kBridgeMaxFalls kez düştün';

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('KÖPRÜ', '$crossed/$_kBridgeGoal'),
        MiniStat('MÜKEMMEL', '$perfects'),
        MiniStat('DÜŞÜŞ', '$falls'),
      ];

  @override
  String get verdict {
    if (falls == 0 && perfects >= 5) return 'Hiç düşmeden ve $perfects kez tam ortadan! Köprü ustası.';
    if (falls == 0) return 'Hiç düşmeden 15 köprü! Zamanlama hissin mükemmel.';
    return 'Karşıya geçtin! Kırmızı işaret tam ortayı gösterir.';
  }
}

class BridgeBuilderScreen extends StatelessWidget {
  final GameController app;
  const BridgeBuilderScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<BridgeBuilderController>(
      app: app,
      mode: GameMode.bridgeBuilder,
      create: BridgeBuilderController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'KÖPRÜ', value: '${c.crossed}/$_kBridgeGoal', highlight: true),
        HudPill(label: 'DÜŞÜŞ', value: '${c.falls}/1', highlight: c.falls >= 1),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(
        controller: c,
        painter: _BridgePainter(c),
        onDown: c.down,
        onUp: c.up,
      ),
    );
  }
}

class _BridgePainter extends CustomPainter {
  final BridgeBuilderController c;
  _BridgePainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    paintPlayfield(canvas, size, const [Color(0xFFFFD9B8), Color(0xFFFF9EAA)]);
    canvas.drawCircle(Offset(w * 0.78, h * 0.18), w * 0.1, Paint()..color = const Color(0xFFFFF4D6).withOpacity(0.9));

    // Paralaks tepeler
    _hills(canvas, size, h * 0.62, h * 0.08, const Color(0xFFE88A9A), c.camX * 0.2, 0.012);
    _hills(canvas, size, h * 0.72, h * 0.07, const Color(0xFFC8708E), c.camX * 0.4, 0.018);

    if (c.curW == 0) return;
    final top = c.pillarTop;

    // Sutunlar
    _pillar(canvas, Rect.fromLTRB(c.curX - c.camX, top, c.curX + c.curW - c.camX, h));
    _pillar(canvas, Rect.fromLTRB(c.nextX - c.camX, top, c.nextX + c.nextW - c.camX, h));
    // Mukemmel isareti
    final mid = c.nextX + c.nextW / 2 - c.camX;
    canvas.drawRect(Rect.fromCenter(center: Offset(mid, top + 2.5), width: 9, height: 5), Paint()..color = const Color(0xFFE53935));

    // Cubuk
    if (c.stick > 0) {
      final base = Offset(c.edge - c.camX, top);
      final end = base + Offset(sin(c.stickAngle) * c.stick, -cos(c.stickAngle) * c.stick);
      canvas.drawLine(
        base,
        end,
        Paint()
          ..color = const Color(0xFF5A3A22)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    _hero(canvas, Offset(c.heroX - c.camX, top - c.heroR + c.heroDrop), c.heroR, c.playMs / 1000);

    if (c.crossed == 0 && c.stage == BridgeStage.idle && c.phase == MiniPhase.play) {
      paintLabel(canvas, 'Basılı tut → çubuk uzar, bırak → düşer', Offset(w / 2, h * 0.36), 15, const Color(0xFF6B2A3A));
    }
    paintFloats(canvas, c.floats);
  }

  void _hills(Canvas canvas, Size size, double baseY, double amp, Color color, double shift, double freq) {
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + 8; x += 8) {
      path.lineTo(x, baseY - amp * (0.5 + 0.5 * sin((x + shift) * freq)));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _pillar(Canvas canvas, Rect r) {
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4D5288), Color(0xFF23264F)],
        ).createShader(r),
    );
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 3), Paint()..color = Colors.white.withOpacity(0.35));
  }

  void _hero(Canvas canvas, Offset c0, double r, double t) {
    paintGlossBall(canvas, c0, r, const Color(0xFFFFE082), const Color(0xFFFFA000));
    // Kirmizi alin bandi ve ucusan uclari
    final band = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c0 + Offset(-r * 0.9, -r * 0.35), c0 + Offset(r * 0.9, -r * 0.35), band);
    final wave = sin(t * 12) * r * 0.2;
    canvas.drawLine(c0 + Offset(-r * 0.9, -r * 0.35), c0 + Offset(-r * 1.6, -r * 0.2 + wave), band..strokeWidth = r * 0.18);
    final eye = Paint()..color = const Color(0xFF3F2A00);
    canvas.drawCircle(c0 + Offset(r * 0.15, r * 0.05), r * 0.13, eye);
    canvas.drawCircle(c0 + Offset(r * 0.55, r * 0.05), r * 0.13, eye);
  }

  @override
  bool shouldRepaint(covariant _BridgePainter old) => old.c != c;
}
