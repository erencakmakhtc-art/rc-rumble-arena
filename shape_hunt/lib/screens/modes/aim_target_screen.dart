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

/// Vurulmasi gereken hedef sayisi.
const int _kAimHits = 30;

/// Gecme sarti: 30 hedefi (cezalar dahil) bu surenin altinda bitirmek.
const int _kAimPassMs = 16000;

/// Guvenlik ust siniri.
const int _kAimLimitMs = 40000;

/// Bu kadar hatada (hedef kacirma + sahte hedef) oyun biter.
const int _kAimMaxErrors = 3;

/// Hedef kacirma / sahte hedefe vurma cezasi ve bos dokunus cezasi (ms).
const int _kAimMissPenalty = 1000;
const int _kAimEmptyPenalty = 300;

class AimDot {
  final Offset pos;
  final double radius;
  final double bornMs;
  final double lifeMs;
  final bool decoy;
  AimDot(this.pos, this.radius, this.bornMs, this.lifeMs, {this.decoy = false});

  double lifeFrac(double now) => ((now - bornMs) / lifeMs).clamp(0.0, 1.0).toDouble();

  /// Hedef omru boyunca %55 kuculur.
  double radiusAt(double now) => radius * (1 - 0.55 * lifeFrac(now));
}

class AimTargetController extends ArenaGameController {
  AimDot? target;
  final List<AimDot> decoys = [];

  /// Vurus efektleri: (konum, zaman, iyi mi).
  final List<(Offset, double, bool)> bursts = [];

  int hits = 0;
  int errors = 0;
  int emptyTaps = 0;
  int penaltyMs = 0;
  Offset? _lastPos;
  int _shownTenth = -1;

  @override
  int get durationMs => _kAimLimitMs;

  @override
  bool get higherIsBetter => false;

  bool get finishedAll => hits >= _kAimHits;

  /// Cezalar dahil gecen sure (ms).
  int get elapsedMs => (playMs + penaltyMs).round();

  /// Bitiremeyen oyuncu siralamaya kisa sure yazamasin.
  @override
  int get recordValue => finishedAll ? elapsedMs : _kAimLimitMs;

  @override
  void resetArena() {
    target = null;
    decoys.clear();
    bursts.clear();
    hits = 0;
    errors = 0;
    emptyTaps = 0;
    penaltyMs = 0;
    _lastPos = null;
    _shownTenth = -1;
  }

  @override
  void update(double dtMs) {
    if (target == null) _spawn();
    final t = target!;
    if (playMs - t.bornMs > t.lifeMs) {
      _error(t.pos, 'Kaçtı! +1 sn');
      if (phase != MiniPhase.play) return;
      _spawn();
    }
    decoys.removeWhere((d) => playMs - d.bornMs > d.lifeMs);
    bursts.removeWhere((b) => playMs - b.$2 > 320);

    if (playMs + penaltyMs >= _kAimLimitMs) {
      endRun();
      return;
    }
    final tenth = elapsedMs ~/ 100;
    if (tenth != _shownTenth) {
      _shownTenth = tenth;
      safeNotify();
    }
  }

  void _spawn() {
    final w = field.width;
    final h = field.height;
    final hp = hits / _kAimHits;
    // Hedefler kuculur (~32px -> ~17px) ve omurleri kisalir (1,3 sn -> 0,75 sn).
    final r = w * (0.085 - 0.04 * hp);
    final life = 1300 - 550 * hp;
    final minJump = min(w, h) * 0.35;

    Offset pos = Offset(w / 2, h / 2);
    for (var i = 0; i < 14; i++) {
      pos = Offset(
        r + 8 + rng.nextDouble() * (w - 2 * r - 16),
        r + 8 + rng.nextDouble() * (h - 2 * r - 16),
      );
      if (_lastPos == null || (pos - _lastPos!).distance >= minJump) break;
    }
    target = AimDot(pos, r, playMs, life);
    _lastPos = pos;

    // Sahte (dokunulmamasi gereken) hedefler hedefin hemen yanina konur.
    decoys.clear();
    var count = 0;
    if (hits >= 18) {
      count = rng.nextDouble() < 0.5 ? 2 : 1;
    } else if (hits >= 8) {
      count = rng.nextDouble() < 0.45 ? 1 : 0;
    }
    for (var i = 0; i < count; i++) {
      final a = rng.nextDouble() * pi * 2;
      final d = r * (2.6 + rng.nextDouble() * 1.4);
      final dp = Offset(
        (pos.dx + cos(a) * d).clamp(r + 6, w - r - 6).toDouble(),
        (pos.dy + sin(a) * d).clamp(r + 6, h - r - 6).toDouble(),
      );
      if ((dp - pos).distance < r * 2.2) continue;
      decoys.add(AimDot(dp, r, playMs, life, decoy: true));
    }
  }

  void tap(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen) return;
    final t = target;
    if (t == null) return;
    final now = nowMs;
    const tol = 6.0;

    final dT = (pos - t.pos).distance - t.radiusAt(now);
    AimDot? decoy;
    var dD = double.infinity;
    for (final d in decoys) {
      final v = (pos - d.pos).distance - d.radiusAt(now);
      if (v < dD) {
        dD = v;
        decoy = d;
      }
    }

    if (dT <= tol && dT <= dD) {
      hits += 1;
      bumpStreak();
      bursts.add((t.pos, playMs, true));
      addFloat('${(now - t.bornMs).round()} ms', t.pos, AppColors.ink, size: 14);
      AudioManager.instance.playCorrect();
      if (finishedAll) {
        endRun();
        return;
      }
      _spawn();
      safeNotify();
      return;
    }
    if (decoy != null && dD <= tol) {
      decoys.remove(decoy);
      _error(decoy.pos, 'Sahte! +1 sn');
      return;
    }
    emptyTaps += 1;
    penaltyMs += _kAimEmptyPenalty;
    breakStreak();
    addFloat('+0,3 sn', pos, AppColors.red, size: 13);
  }

  void _error(Offset at, String text) {
    errors += 1;
    penaltyMs += _kAimMissPenalty;
    breakStreak();
    bursts.add((at, playMs, false));
    addFloat(text, at, AppColors.red, size: 15);
    AudioManager.instance.playWrong();
    if (errors >= _kAimMaxErrors) {
      endRun();
      return;
    }
    safeNotify();
  }

  @override
  bool get passed => finishedAll && errors < _kAimMaxErrors && elapsedMs <= _kAimPassMs;

  @override
  String get headlineLabel {
    if (passed) return 'Bitirme süren';
    if (errors >= _kAimMaxErrors) return '$_kAimMaxErrors hata yaptın';
    if (finishedAll) return '${_kAimPassMs ~/ 1000} sn sınırını aştın';
    return 'Süre doldu';
  }

  @override
  String get headlineValue =>
      finishedAll ? '${(elapsedMs / 1000).toStringAsFixed(2)} sn' : '$hits/$_kAimHits';

  @override
  List<MiniStat> get stats => [
        MiniStat('VURUŞ', '$hits/$_kAimHits'),
        MiniStat('CEZA', '${(penaltyMs / 1000).toStringAsFixed(1)} sn'),
        MiniStat('HATA', '$errors/$_kAimMaxErrors'),
      ];

  @override
  String get verdict {
    final perHit = elapsedMs / _kAimHits;
    if (errors == 0 && emptyTaps == 0) return 'Tek bir kurşun bile boşa gitmedi. Keskin nişancı!';
    if (perHit < 420) return 'Hedef başına ${perHit.round()} ms. Elin gözünden hızlı!';
    return 'Tahtayı temizledin! Boş dokunuşları azaltırsan süre düşer.';
  }
}

class AimTargetScreen extends StatelessWidget {
  final GameController app;
  const AimTargetScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<AimTargetController>(
      app: app,
      mode: GameMode.aimTarget,
      create: AimTargetController.new,
      score: (c) => c.recordValue,
      hud: (c) => [
        HudPill(label: 'VURUŞ', value: '${c.hits}/$_kAimHits', highlight: true),
        HudPill(
          label: 'SÜRE',
          value: (c.elapsedMs / 1000).toStringAsFixed(1),
          highlight: c.elapsedMs > _kAimPassMs,
        ),
        HudPill(label: 'HATA', value: '${c.errors}/$_kAimMaxErrors', highlight: c.errors >= 2),
      ],
      body: (c) => ArenaView(controller: c, painter: _AimPainter(c), onDown: c.tap),
    );
  }
}

class _AimPainter extends CustomPainter {
  final AimTargetController c;
  _AimPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    paintPlayfield(canvas, size, const [Color(0xFFF6F7FF), Color(0xFFDDE2FA)]);
    final grid = Paint()
      ..color = const Color(0xFF8C92CD).withOpacity(0.15)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final now = c.playMs;
    for (final d in c.decoys) {
      _decoy(canvas, d.pos, d.radiusAt(now));
    }
    final t = c.target;
    if (t != null) _target(canvas, t, now);

    for (final b in c.bursts) {
      final k = ((now - b.$2) / 320).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        b.$1,
        20 + 30 * k,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - k)
          ..color = (b.$3 ? const Color(0xFF3FBF6A) : AppColors.red).withOpacity(1 - k),
      );
    }
    paintFloats(canvas, c.floats);
  }

  void _target(Canvas canvas, AimDot t, double now) {
    final r = t.radiusAt(now);
    const colors = [Color(0xFFE53935), Colors.white, Color(0xFFE53935), Colors.white];
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(t.pos, r * (1 - i * 0.24), Paint()..color = colors[i]);
    }
    canvas.drawCircle(t.pos, r * 0.12, Paint()..color = const Color(0xFFB71C1C));
    // Kalan omur yayi
    final left = 1 - t.lifeFrac(now);
    canvas.drawArc(
      Rect.fromCircle(center: t.pos, radius: r + 6),
      -pi / 2,
      pi * 2 * left,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = left < 0.3 ? AppColors.red : AppColors.ink,
    );
  }

  void _decoy(Canvas canvas, Offset c0, double r) {
    paintGlossBall(canvas, c0, r, const Color(0xFF9EA3C0), const Color(0xFF4A4F6B));
    final x = Paint()
      ..color = Colors.white
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.round;
    final k = r * 0.42;
    canvas.drawLine(c0 + Offset(-k, -k), c0 + Offset(k, k), x);
    canvas.drawLine(c0 + Offset(-k, k), c0 + Offset(k, -k), x);
  }

  @override
  bool shouldRepaint(covariant _AimPainter old) => old.c != c;
}
