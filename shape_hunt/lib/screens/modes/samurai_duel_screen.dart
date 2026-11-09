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

/// Rakibin her duellodaki tepki suresi (ms). Onu gecmek icin daha hizli olmalisin.
const List<double> _kOpponentMs = [350, 325, 305, 290, 275, 262, 252];

/// Bu kadar duello kaybedilince oyun biter (yani 1 kayip hakki var).
const int _kDuelMaxLosses = 2;

/// Sahte isaretin ekranda kalma suresi (ms).
const double _kFakeMs = 450;

/// Sonuc sahnesinin suresi (ms).
const double _kResultMs = 1300;

enum DuelStage { ready, fake, cue, result }

class SamuraiDuelController extends ArenaGameController {
  @override
  bool get timed => false;

  @override
  int get durationMs => 600000;

  @override
  bool get higherIsBetter => false;

  int duel = 0;
  int wins = 0;
  int losses = 0;
  DuelStage stage = DuelStage.ready;

  /// Duello basindan (ready/fake) ya da sonuc basindan (result) beri gecen sure.
  double stageMs = 0;
  double _cueAt = 0;
  double _fakeAt = -1;
  double cueStartMs = 0;

  /// 1: gri "!" (yem), 2: "?" isareti, 3: gokte uçan kus.
  int fakeKind = 0;

  bool? lastWon;
  String lastNote = '';
  int? lastRt;
  final List<int> reactions = [];
  bool completed = false;

  double get opponentMs => _kOpponentMs[(duel - 1).clamp(0, _kOpponentMs.length - 1)];

  int get avgRt => reactions.isEmpty ? 0 : (reactions.reduce((a, b) => a + b) / reactions.length).round();
  int get bestRt => reactions.isEmpty ? 0 : reactions.reduce(min);

  @override
  int get recordValue => passed ? avgRt : 99999;

  @override
  void resetArena() {
    duel = 0;
    wins = 0;
    losses = 0;
    reactions.clear();
    completed = false;
    _startDuel();
  }

  void _startDuel() {
    duel += 1;
    stage = DuelStage.ready;
    stageMs = 0;
    lastWon = null;
    lastRt = null;
    // Isaret 1,4 - 3,6 sn arasinda rastgele bir anda gelir.
    _cueAt = 1400 + rng.nextDouble() * 2200;
    // 3. duellodan itibaren %45 ihtimalle once sahte bir isaret.
    if (duel >= 3 && rng.nextDouble() < 0.45) {
      fakeKind = 1 + rng.nextInt(3);
      _fakeAt = 400 + rng.nextDouble() * max(0.0, _cueAt - 1450);
    } else {
      fakeKind = 0;
      _fakeAt = -1;
    }
    safeNotify();
  }

  @override
  void update(double dtMs) {
    stageMs += dtMs;
    switch (stage) {
      case DuelStage.ready:
      case DuelStage.fake:
        if (_fakeAt >= 0) {
          final inFake = stageMs >= _fakeAt && stageMs < _fakeAt + _kFakeMs;
          stage = inFake ? DuelStage.fake : DuelStage.ready;
        }
        if (stageMs >= _cueAt) {
          stage = DuelStage.cue;
          cueStartMs = playMs;
          AudioManager.instance.playGo();
          safeNotify();
        }
      case DuelStage.cue:
        if (playMs - cueStartMs >= opponentMs) _lose('Rakip daha hızlıydı!');
      case DuelStage.result:
        if (stageMs >= _kResultMs) {
          if (losses >= _kDuelMaxLosses) {
            endRun();
          } else if (duel >= _kOpponentMs.length) {
            completed = true;
            endRun();
          } else {
            _startDuel();
          }
        }
    }
  }

  void tap(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen) return;
    switch (stage) {
      case DuelStage.ready:
        _lose('Erken davrandın!');
      case DuelStage.fake:
        _lose('Tuzağa düştün!');
      case DuelStage.cue:
        final rt = (nowMs - cueStartMs).round();
        if (rt < opponentMs) {
          _win(rt);
        } else {
          _lose('Rakip daha hızlıydı!');
        }
      case DuelStage.result:
        break;
    }
  }

  void _win(int rt) {
    wins += 1;
    reactions.add(rt);
    bumpStreak();
    addPoints(100 + (opponentMs - rt).round());
    lastWon = true;
    lastRt = rt;
    lastNote = '$rt ms';
    stage = DuelStage.result;
    stageMs = 0;
    AudioManager.instance.playCorrect();
    safeNotify();
  }

  void _lose(String note) {
    losses += 1;
    breakStreak();
    lastWon = false;
    lastNote = note;
    stage = DuelStage.result;
    stageMs = 0;
    AudioManager.instance.playWrong();
    safeNotify();
  }

  @override
  bool get passed => completed && losses < _kDuelMaxLosses;

  @override
  String get headlineLabel => passed ? 'Ortalama tepki süren' : '$_kDuelMaxLosses düello kaybettin';

  @override
  String get headlineValue => passed ? '${(avgRt / 1000).toStringAsFixed(3)} sn' : '$wins/${_kOpponentMs.length}';

  @override
  List<MiniStat> get stats => [
        MiniStat('KAZANILAN', '$wins/${_kOpponentMs.length}'),
        MiniStat('EN HIZLI', reactions.isEmpty ? '—' : '$bestRt ms'),
        MiniStat('ORTALAMA', reactions.isEmpty ? '—' : '$avgRt ms'),
      ];

  @override
  String get verdict {
    if (losses == 0 && avgRt < 230) return 'Kılıç daha kınından çıkmadan kazandın. Efsane!';
    if (losses == 0) return 'Yedi düellonun yedisini de aldın. Usta samuray!';
    return 'Son rakibi de devirdin. Sahte işaretlere dikkat!';
  }
}

class SamuraiDuelScreen extends StatelessWidget {
  final GameController app;
  const SamuraiDuelScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<SamuraiDuelController>(
      app: app,
      mode: GameMode.samuraiDuel,
      create: SamuraiDuelController.new,
      score: (c) => c.recordValue,
      hud: (c) => [
        HudPill(label: 'DÜELLO', value: '${max(1, c.duel)}/${_kOpponentMs.length}', highlight: true),
        HudPill(label: 'RAKİP', value: '${c.opponentMs.round()} ms'),
        HudPill(label: 'KAYIP', value: '${c.losses}/1', highlight: c.losses >= 1),
      ],
      body: (c) => ArenaView(controller: c, painter: _DuelPainter(c), onDown: c.tap),
    );
  }
}

/// Suzulen kiraz yapraklari icin sabit tohumlar.
final List<(double, double, double)> _kPetals = () {
  final r = Random(11);
  return [for (var i = 0; i < 16; i++) (r.nextDouble(), r.nextDouble(), 0.6 + r.nextDouble() * 0.8)];
}();

class _DuelPainter extends CustomPainter {
  final SamuraiDuelController c;
  _DuelPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = c.playMs / 1000;
    final groundY = h * 0.78;

    // Gun batimi gokyuzu
    paintPlayfield(canvas, size, const [Color(0xFF5B3F8F), Color(0xFFE0668A), Color(0xFFFFB36B)]);
    final sunC = Offset(w / 2, groundY - h * 0.02);
    final sunR = w * 0.26;
    canvas.drawCircle(
      sunC,
      sunR,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFFFFF1C2), Color(0xFFFFB86B)])
            .createShader(Rect.fromCircle(center: sunC, radius: sunR)),
    );

    // Daglar (iki katman)
    _mountains(canvas, size, groundY, h * 0.22, const Color(0xFF7A4F8F), 0.0);
    _mountains(canvas, size, groundY, h * 0.13, const Color(0xFF4E3470), 1.7);

    // Zemin
    final ground = Rect.fromLTWH(0, groundY, w, h - groundY);
    canvas.drawRect(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A2556), Color(0xFF1F1433)],
        ).createShader(ground),
    );

    // Kiraz yapraklari
    final petal = Paint()..color = const Color(0xFFFFC4DA).withOpacity(0.85);
    for (final (px, py, k) in _kPetals) {
      final x = (px * w + t * 24 * k) % (w + 20) - 10;
      final y = (py * h + t * 38 * k) % (h + 20) - 10;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 2 * k + px * 6);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 7 * k + 3, height: 4 * k + 2), petal);
      canvas.restore();
    }

    // Samuraylar
    final won = c.stage == DuelStage.result ? c.lastWon : null;
    final scale = h * 0.2;
    _samurai(canvas, Offset(w * 0.24, groundY), scale, true, const Color(0xFF1B1530),
        won == true ? _Pose.slash : (won == false ? _Pose.fallen : _Pose.ready));
    _samurai(canvas, Offset(w * 0.76, groundY), scale, false, const Color(0xFF3A0F1E),
        won == false ? _Pose.slash : (won == true ? _Pose.fallen : _Pose.ready));

    // Kesik izi
    if (won != null) {
      final k = (c.stageMs / 420).clamp(0.0, 1.0).toDouble();
      final fade = 1 - (c.stageMs / _kResultMs).clamp(0.0, 1.0).toDouble();
      final a = Offset(w * 0.08, h * 0.3);
      final b = Offset(w * 0.92, h * 0.62);
      canvas.drawLine(
        a,
        Offset.lerp(a, b, k)!,
        Paint()
          ..color = Colors.white.withOpacity(0.9 * fade)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Isaretler
    final center = Offset(w / 2, h * 0.3);
    if (c.stage == DuelStage.cue) {
      _burst(canvas, center, w * 0.16, Colors.white, '!', const Color(0xFFE02F2F));
    } else if (c.stage == DuelStage.fake) {
      switch (c.fakeKind) {
        case 1:
          _burst(canvas, center, w * 0.16, const Color(0xFFBFC3D6), '!', const Color(0xFF6E739E));
        case 2:
          _burst(canvas, center, w * 0.16, Colors.white, '?', const Color(0xFF3F4478));
        default:
          final k = ((c.stageMs % 450) / 450);
          _bird(canvas, Offset(w * (0.1 + 0.8 * k), h * 0.2), w * 0.06, t);
      }
    }

    // Metinler
    if (c.stage == DuelStage.ready && c.duel == 1 && c.stageMs < 2600) {
      paintLabel(canvas, 'Sadece KIRMIZI ! görünce dokun', Offset(w / 2, h * 0.12), 16, Colors.white);
    }
    if (c.stage == DuelStage.result) {
      final txt = c.lastWon == true ? 'Kazandın!' : 'Kaybettin';
      paintLabel(canvas, txt, Offset(w / 2, h * 0.13), 26, Colors.white);
      paintLabel(canvas, c.lastNote, Offset(w / 2, h * 0.2), 17,
          c.lastWon == true ? const Color(0xFFFFF1C2) : const Color(0xFFFFC2C2));
    }
    paintFloats(canvas, c.floats);
  }

  void _mountains(Canvas canvas, Size size, double baseY, double height, Color color, double phase) {
    final path = Path()..moveTo(0, baseY);
    const peaks = 5;
    for (var i = 0; i <= peaks * 2; i++) {
      final x = size.width * i / (peaks * 2);
      final up = i.isOdd ? (0.55 + 0.45 * (0.5 + 0.5 * sin(i * 1.9 + phase))) : 0.15;
      path.lineTo(x, baseY - height * up);
    }
    path
      ..lineTo(size.width, baseY)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _burst(Canvas canvas, Offset c0, double r, Color fill, String mark, Color ink) {
    final path = Path();
    const spikes = 12;
    for (var i = 0; i < spikes * 2; i++) {
      final a = -pi / 2 + i * pi / spikes;
      final rr = i.isEven ? r : r * 0.72;
      final p = c0 + Offset(cos(a) * rr, sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = ink.withOpacity(0.35),
    );
    paintLabel(canvas, mark, c0 + Offset(0, r * 0.05), r * 1.1, ink);
  }

  void _bird(Canvas canvas, Offset c0, double s, double t) {
    final flap = sin(t * 18) * s * 0.35;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1B1530);
    canvas.drawPath(
      Path()
        ..moveTo(c0.dx - s, c0.dy - flap)
        ..quadraticBezierTo(c0.dx - s * 0.4, c0.dy - s * 0.3, c0.dx, c0.dy)
        ..quadraticBezierTo(c0.dx + s * 0.4, c0.dy - s * 0.3, c0.dx + s, c0.dy - flap),
      p,
    );
  }

  /// Silüet samuray. [base] ayaklarin ortasi, [s] boy olcegi.
  void _samurai(Canvas canvas, Offset base, double s, bool facingRight, Color color, _Pose pose) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    if (!facingRight) canvas.scale(-1, 1);
    if (pose == _Pose.fallen) {
      canvas.translate(-s * 0.1, 0);
      canvas.rotate(-1.35);
    }
    final p = Paint()..color = color;

    // Bacaklar (hakama)
    canvas.drawPath(
      Path()
        ..moveTo(-s * 0.2, 0)
        ..lineTo(-s * 0.12, -s * 0.45)
        ..lineTo(s * 0.14, -s * 0.45)
        ..lineTo(s * 0.24, 0)
        ..lineTo(s * 0.06, 0)
        ..lineTo(s * 0.01, -s * 0.22)
        ..lineTo(-s * 0.04, 0)
        ..close(),
      p,
    );
    // Govde
    canvas.drawPath(
      Path()
        ..moveTo(-s * 0.14, -s * 0.44)
        ..lineTo(-s * 0.1, -s * 0.8)
        ..lineTo(s * 0.12, -s * 0.8)
        ..lineTo(s * 0.16, -s * 0.44)
        ..close(),
      p,
    );
    // Omuz zirhi
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(-s * 0.2, -s * 0.84, s * 0.2, -s * 0.74), Radius.circular(s * 0.03)),
      p,
    );
    // Bas + topuz
    canvas.drawCircle(Offset(s * 0.01, -s * 0.93), s * 0.1, p);
    canvas.drawCircle(Offset(-s * 0.04, -s * 1.05), s * 0.045, p);

    // Kilic
    final blade = Paint()
      ..color = const Color(0xFFE8ECF7)
      ..strokeWidth = s * 0.025
      ..strokeCap = StrokeCap.round;
    final hilt = Paint()
      ..color = color
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round;
    if (pose == _Pose.slash) {
      canvas.drawLine(Offset(s * 0.12, -s * 0.66), Offset(s * 0.24, -s * 0.66), hilt);
      canvas.drawLine(Offset(s * 0.24, -s * 0.66), Offset(s * 0.78, -s * 0.5), blade);
    } else {
      // Kinda, bele yakin, capraz
      canvas.drawLine(Offset(-s * 0.02, -s * 0.5), Offset(s * 0.12, -s * 0.58), hilt);
      canvas.drawLine(Offset(-s * 0.02, -s * 0.5), Offset(-s * 0.42, -s * 0.34), blade);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DuelPainter old) => old.c != c;
}

enum _Pose { ready, slash, fallen }
