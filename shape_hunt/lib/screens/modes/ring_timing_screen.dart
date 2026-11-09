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

/// Gecme sarti: 20 saniyede (3 iskalamadan) ulasilmasi gereken puan.
const int _kRingTarget = 3300;

/// Bu kadar iskalamada oyun biter.
const int _kRingMaxMiss = 3;

/// Zamanlama pencereleri (ms, hedef andan +/-).
const double _kPerfectMs = 45;
const double _kGoodMs = 100;
const double _kOkMs = 170;

const List<(Color, Color)> _kRingColors = [
  (Color(0xFFFFB3D8), Color(0xFFE8559C)),
  (Color(0xFFBFE0FF), Color(0xFF3F7BE6)),
  (Color(0xFFE6FFBD), Color(0xFF6FB51A)),
  (Color(0xFFFFE0A8), Color(0xFFF08A00)),
  (Color(0xFFDED3FF), Color(0xFF7A55E0)),
];

class RingNote {
  final Offset pos;
  final double radius;
  final double hitAt;
  final double approachMs;
  final int number;
  final int colorIdx;
  RingNote(this.pos, this.radius, this.hitAt, this.approachMs, this.number, this.colorIdx);
}

class RingTimingController extends ArenaGameController {
  final List<RingNote> notes = [];

  /// Degerlendirme efektleri: (konum, zaman, renk).
  final List<(Offset, double, Color)> bursts = [];

  double _nextHitAt = 0;
  int _num = 0;
  int _colorIdx = 0;

  int perfect = 0;
  int good = 0;
  int ok = 0;
  int misses = 0;

  double get noteRadius => field.width * 0.085;

  @override
  void resetArena() {
    notes.clear();
    bursts.clear();
    _nextHitAt = 1000;
    _num = 0;
    _colorIdx = 0;
    perfect = 0;
    good = 0;
    ok = 0;
    misses = 0;
  }

  @override
  void update(double dtMs) {
    final p = progress;
    // Halkanin daralma suresi 950ms -> 600ms.
    final approach = 950 - 350 * p;

    while (playMs >= _nextHitAt - approach && _nextHitAt < durationMs - 150) {
      _spawn(_nextHitAt, approach);
      // Yarinin sonrasinda bazen ayni anda iki hedef: iki parmak gerekir.
      if (p > 0.5 && rng.nextDouble() < 0.25) _spawn(_nextHitAt, approach);
      // Hedefler arasi 720ms -> 360ms.
      _nextHitAt += 720 - 360 * p + rng.nextInt(80);
    }

    for (var i = notes.length - 1; i >= 0; i--) {
      final n = notes[i];
      if (playMs > n.hitAt + _kOkMs) {
        notes.removeAt(i);
        _miss(n.pos, 'Kaçtı');
        if (phase != MiniPhase.play) return;
      }
    }
    bursts.removeWhere((b) => playMs - b.$2 > 350);
  }

  void _spawn(double hitAt, double approach) {
    final w = field.width;
    final h = field.height;
    final r = noteRadius;
    final margin = r * 1.4;
    Offset pos = Offset(w / 2, h / 2);
    for (var i = 0; i < 20; i++) {
      pos = Offset(
        margin + rng.nextDouble() * (w - 2 * margin),
        margin + rng.nextDouble() * (h - 2 * margin),
      );
      if (notes.every((n) => (n.pos - pos).distance > r * 2.8)) break;
    }
    _num = _num % 9 + 1;
    _colorIdx = (_colorIdx + 1) % _kRingColors.length;
    notes.add(RingNote(pos, r, hitAt, approach, _num, _colorIdx));
  }

  void tap(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen) return;
    // Dokunusun altindaki hedeflerden zamani en yakin olan.
    RingNote? target;
    for (final n in notes) {
      if ((n.pos - pos).distance > n.radius * 1.25) continue;
      if (target == null || n.hitAt < target.hitAt) target = n;
    }
    if (target == null) return;

    final diff = nowMs - target.hitAt;
    notes.remove(target);
    if (diff < -_kOkMs) {
      _miss(target.pos, 'Erken!');
      return;
    }

    final ad = diff.abs();
    final int base;
    final String label;
    final Color color;
    if (ad <= _kPerfectMs) {
      base = 100;
      label = 'Mükemmel!';
      color = const Color(0xFF7CFFB0);
      perfect += 1;
    } else if (ad <= _kGoodMs) {
      base = 60;
      label = 'İyi';
      color = const Color(0xFF8FD3FF);
      good += 1;
    } else {
      base = 30;
      label = diff < 0 ? 'Biraz erken' : 'Biraz geç';
      color = const Color(0xFFFFC27A);
      ok += 1;
    }
    bumpStreak();
    var gained = base;
    String? toast;
    if (streak % 10 == 0) {
      gained += 100;
      toast = 'Seri x$streak! +$gained';
    }
    addPoints(gained, label: toast);
    addFloat(label, target.pos, color, size: 16);
    bursts.add((target.pos, playMs, color));
    AudioManager.instance.playCorrect();
    safeNotify();
  }

  void _miss(Offset at, String text) {
    misses += 1;
    breakStreak();
    addFloat(text, at, const Color(0xFFFF8A8A), size: 16);
    bursts.add((at, playMs, const Color(0xFFFF8A8A)));
    AudioManager.instance.playWrong();
    if (misses >= _kRingMaxMiss) {
      endRun();
      return;
    }
    safeNotify();
  }

  @override
  bool get passed => misses < _kRingMaxMiss && points >= _kRingTarget;

  @override
  String get headlineLabel {
    if (passed) return 'Toplam puanın';
    if (misses >= _kRingMaxMiss) return '$_kRingMaxMiss kez ıskaladın';
    return '$_kRingTarget puana ulaşamadın';
  }

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('MÜKEMMEL', '$perfect'),
        MiniStat('İYİ / TAMAM', '$good / $ok'),
        MiniStat('ISKA', '$misses/$_kRingMaxMiss'),
      ];

  @override
  String get verdict {
    final total = perfect + good + ok;
    if (total > 0 && perfect / total > 0.7) return 'Metronom gibisin. Neredeyse her vuruş mükemmel!';
    if (misses == 0) return 'Hiç ıskalamadın! Mükemmel oranını artırırsan zirve senin.';
    return 'Ritmi yakaladın. Halka çembere değdiği an dokun!';
  }
}

class RingTimingScreen extends StatelessWidget {
  final GameController app;
  const RingTimingScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<RingTimingController>(
      app: app,
      mode: GameMode.ringTiming,
      create: RingTimingController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SÜRE', value: '${c.remainingSec} sn', highlight: c.remainingSec <= 5),
        HudPill(label: 'ISKA', value: '${c.misses}/$_kRingMaxMiss', highlight: c.misses >= 2),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(controller: c, painter: _RingPainter(c), onDown: c.tap),
    );
  }
}

/// Arka plandaki sabit yildizlar (0..1 konum, boyut). Her karede ayni kalir.
final List<(double, double, double)> _kStars = () {
  final r = Random(7);
  return [for (var i = 0; i < 38; i++) (r.nextDouble(), r.nextDouble(), 0.6 + r.nextDouble() * 1.4)];
}();

class _RingPainter extends CustomPainter {
  final RingTimingController c;
  _RingPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    paintPlayfield(canvas, size, const [Color(0xFF4A3F8F), Color(0xFF2A2660)]);
    final center = Offset(size.width / 2, size.height * 0.45);
    canvas.drawCircle(
      center,
      size.shortestSide * 0.75,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF8C7BFF).withOpacity(0.28), const Color(0xFF8C7BFF).withOpacity(0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: size.shortestSide * 0.75)),
    );
    final now = c.playMs;
    final twinkle = now / 1000;
    for (var i = 0; i < _kStars.length; i++) {
      final (sx, sy, sr) = _kStars[i];
      final a = 0.35 + 0.3 * sin(twinkle * 2 + i);
      canvas.drawCircle(Offset(sx * size.width, sy * size.height), sr, Paint()..color = Colors.white.withOpacity(a));
    }

    // Once cizilen (sonra vurulacak) hedefler altta kalsin.
    final sorted = [...c.notes]..sort((a, b) => b.hitAt.compareTo(a.hitAt));
    for (final n in sorted) {
      final (light, dark) = _kRingColors[n.colorIdx];
      final appearT = ((now - (n.hitAt - n.approachMs)) / 150).clamp(0.0, 1.0).toDouble();
      final left = ((n.hitAt - now) / n.approachMs).clamp(0.0, 1.0).toDouble();

      canvas.saveLayer(null, Paint()..color = Colors.white.withOpacity(appearT));
      paintGlossBall(canvas, n.pos, n.radius, light, dark);
      canvas.drawCircle(
        n.pos,
        n.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white,
      );
      paintLabel(canvas, '${n.number}', n.pos, n.radius * 0.95, Colors.white);
      // Daralan halka: hedef cembere oturdugu an dokunulmali.
      canvas.drawCircle(
        n.pos,
        n.radius * (1 + 2.2 * left),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = light,
      );
      canvas.restore();
    }

    for (final b in c.bursts) {
      final k = ((now - b.$2) / 350).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        b.$1,
        c.noteRadius * (1 + 0.7 * k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * (1 - k)
          ..color = b.$3.withOpacity(1 - k),
      );
    }
    paintFloats(canvas, c.floats);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.c != c;
}
