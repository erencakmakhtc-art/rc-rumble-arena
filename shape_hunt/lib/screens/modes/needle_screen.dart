import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';

const int _kNeedleRounds = 12;

/// Bu kadar kez yesilde durduramazsa oyun basarisiz biter.
const int _kNeedleMaxMisses = 2;

class NeedleController extends MiniGameController {
  final Random _rng = Random();

  int round = 0;
  int score = 0;
  int perfectCount = 0;
  int missCount = 0;

  /// Hedef bolgenin merkezi ve yari genisligi (0..1 arasinda oran).
  double zoneCenter = 0.5;
  double zoneHalf = 0.12;

  /// Son turun sonucu (gosterim icin).
  double? lastStopAt;
  int? lastPoints;
  bool showResult = false;

  int? _bestScore;
  bool _newRecord = false;

  /// Toplam gecen sure (dusuk sure + yuksek puan = iyi).
  int elapsedMs = 0;
  DateTime? _startedAt;

  @override
  void resetState() {
    round = 0;
    score = 0;
    perfectCount = 0;
    missCount = 0;
    lastStopAt = null;
    lastPoints = null;
    showResult = false;
    zoneCenter = 0.5;
    zoneHalf = 0.12;
    elapsedMs = 0;
    _startedAt = null;
  }

  @override
  void onPlayStart() {
    _startedAt = DateTime.now();
    _nextRound();
  }

  /// Menude beklenen sure toplam sureye eklenmemeli.
  /// Tur sonucu gosterilirken menu acildiysa "sonraki tur" zamanlayicisi
  /// iptal edilmistir; burada yeniden kurulur, yoksa oyun takili kalirdi.
  @override
  void onResume(int pausedMs) {
    if (_startedAt != null) {
      _startedAt = _startedAt!.add(Duration(milliseconds: pausedMs));
    }
    if (showResult) {
      final done = missCount >= _kNeedleMaxMisses;
      own(Timer(const Duration(milliseconds: 400), done ? _finishRun : _nextRound));
    }
  }

  /// Ibre hizi: 1-2. turlarda kademeli, 3. turdan itibaren en yuksek hizda
  /// (son bolumdeki gibi) sabit kalir.
  int get sweepDurationMs {
    if (round >= 3) return 600; // maksimum hiz
    final t = round <= 1 ? 0.0 : (round - 1) / 2.0;
    return (1500 - 900 * t).round().clamp(600, 1500);
  }

  void _nextRound() {
    if (round >= _kNeedleRounds) {
      _finishRun();
      return;
    }
    round += 1;

    // Bolge genisligi: 3. turdan itibaren en dar (zor) seviyede sabit.
    if (round >= 3) {
      zoneHalf = 0.055;
    } else {
      final t = (round - 1) / 2.0;
      zoneHalf = 0.135 - (0.135 - 0.055) * t;
    }
    // Merkez kenarlara cok yapismasin.
    zoneCenter = 0.18 + _rng.nextDouble() * 0.64;

    lastStopAt = null;
    lastPoints = null;
    showResult = false;
    safeNotify();
  }

  /// Oyuncu ibreyi [pos] (0..1) konumunda durdurdu.
  void stopAt(double pos) {
    if (phase != MiniPhase.play || showResult) return;

    final dist = (pos - zoneCenter).abs();
    // base: turun ham puani (0-100), bonus: tam isabet/combo eklentileri.
    int base;
    var bonus = 0;
    String? label;

    if (dist <= zoneHalf) {
      // Bolge icinde: merkeze yakinlik oraninda 40-100 puan.
      final closeness = 1 - (dist / zoneHalf);
      base = (40 + 60 * closeness).round();
      bumpStreak();
      if (closeness > 0.88) {
        perfectCount += 1;
        bonus += 75;
        label = 'Tam isabet! +${base + bonus}';
      }
      // Ust uste isabette artan combo bonusu.
      if (streak >= 3) {
        bonus += 25 * (streak - 2);
        label = '$streak’lü seri! +${base + bonus}';
      }
      AudioManager.instance.playCorrect();
    } else {
      // Disarida: ne kadar yakin kaldiysa kismi puan, en fazla 25.
      final overshoot = dist - zoneHalf;
      base = max(0, (25 - overshoot * 120).round());
      missCount += 1;
      breakStreak();
      AudioManager.instance.playWrong();
    }

    addPoints(base + bonus, label: label);
    score += base;
    lastStopAt = pos;
    lastPoints = base + bonus;
    showResult = true;
    safeNotify();

    // 2 kez yesilde durduramazsa (2 hata) oyun basarisiz biter.
    if (missCount >= _kNeedleMaxMisses) {
      own(Timer(const Duration(milliseconds: 900), _finishRun));
    } else {
      own(Timer(const Duration(milliseconds: 900), _nextRound));
    }
  }

  void _finishRun() {
    if (_startedAt != null) {
      elapsedMs = DateTime.now().difference(_startedAt!).inMilliseconds;
    }
    if (passed) {
      AudioManager.instance.playWin();
      final prev = _bestScore;
      if (prev == null || score > prev) _bestScore = score;
      _newRecord = prev != null && score > prev;
    } else {
      AudioManager.instance.playLose();
      _newRecord = false;
    }
    finish();
  }

  /// Basari: 12 turu 2'den az hatayla tamamlamak.
  @override
  bool get passed => missCount < _kNeedleMaxMisses && round >= _kNeedleRounds;

  int get maxScore => _kNeedleRounds * 100;

  @override
  bool get isRecord => _newRecord;

  @override
  String get headlineLabel => passed ? 'Toplam puanın' : '2 kez ıskaladın';

  /// Siralamaya giden skor (bonussuz); sonuc karti da bunu gosterir.
  @override
  int? get resultScore => score;

  @override
  String get headlineValue => '$score';

  @override
  List<MiniStat> get stats => [
        MiniStat('SÜRE', '${(elapsedMs / 1000).toStringAsFixed(1)} sn'),
        MiniStat('TAM İSABET', '$perfectCount'),
        MiniStat('HATA', '$missCount/$_kNeedleMaxMisses'),
      ];

  @override
  String get verdict {
    if (!passed) return 'İki kez yeşilde durduramadın. Bölgeye odaklan ve erken bas!';
    if (perfectCount >= 5) return 'Saat gibi zamanlama. İbre sana teslim.';
    if (score / maxScore > 0.8) return 'Çok iyi kontrol. Hızlanınca da şaşmadın.';
    return 'Bitirdin! Tam ortayı yakalayınca puanın artar.';
  }
}

class NeedleScreen extends StatefulWidget {
  final GameController app;
  const NeedleScreen({super.key, required this.app});

  @override
  State<NeedleScreen> createState() => _NeedleScreenState();
}

class _NeedleScreenState extends State<NeedleScreen> with SingleTickerProviderStateMixin {
  late final NeedleController _c;
  late final AnimationController _sweep;
  int _lastRound = 0;
  MiniPhase _lastPhase = MiniPhase.intro;

  @override
  void initState() {
    super.initState();
    _c = NeedleController();
    _c.onFinished = () => widget.app.reportModeResult(GameMode.needle, _c.score, _c.passed);
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _c.addListener(_sync);
    _c.begin(skipIntro: widget.app.shouldSkipIntro(GameMode.needle));
  }

  /// Tur degistiginde ibrenin hizini gunceller; oynanis disinda durdurur.
  void _sync() {
    if (!mounted) return;

    if (_c.phase != _lastPhase) {
      _lastPhase = _c.phase;
      if (_c.phase != MiniPhase.play) _sweep.stop();
    }

    if (_c.phase == MiniPhase.play) {
      if (_c.showResult) {
        // Sonuc gosterilirken ibre dursun.
        if (_sweep.isAnimating) _sweep.stop();
      } else if (_c.round != _lastRound || !_sweep.isAnimating) {
        _lastRound = _c.round;
        _sweep.duration = Duration(milliseconds: _c.sweepDurationMs);
        _sweep.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _c.removeListener(_sync);
    _c.dispose();
    _sweep.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_c.phase != MiniPhase.play || _c.showResult) return;
    _c.stopAt(_sweep.value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return MiniStage(
          mode: GameMode.needle,
          controller: _c,
          onQuit: widget.app.backToModes,
          dontShowIntro: widget.app.shouldSkipIntro(GameMode.needle),
          onDontShowIntroChanged: (v) => widget.app.setSkipIntro(GameMode.needle, v),
          onRetry: () {
            if (!widget.app.tryConsumePlayForRetry()) return;
            _lastRound = 0;
            _c.begin(skipIntro: true);
          },
          hud: [
            HudPill(label: 'TUR', value: '${_c.round.clamp(0, _kNeedleRounds)}/$_kNeedleRounds'),
            HudPill(label: 'HATA', value: '${_c.missCount}/$_kNeedleMaxMisses', highlight: _c.missCount >= 1),
            HudPill(label: 'PUAN', value: '${_c.points}', highlight: true),
          ],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _handleTap(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- Kadran ---
                AnimatedBuilder(
                  animation: _sweep,
                  builder: (context, _) {
                    final pos = _c.showResult && _c.lastStopAt != null ? _c.lastStopAt! : _sweep.value;
                    return AspectRatio(
                      aspectRatio: 1.55,
                      child: CustomPaint(
                        painter: _GaugePainter(
                          needlePos: pos,
                          zoneCenter: _c.zoneCenter,
                          zoneHalf: _c.zoneHalf,
                          settled: _c.showResult,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                // --- Tur sonucu / yonerge ---
                SizedBox(
                  height: 78,
                  child: _c.showResult
                      ? _RoundResult(points: _c.lastPoints ?? 0)
                      : Column(
                          children: [
                            Text(
                              'Ekrana dokun',
                              style: baloo(20, FontWeight.w800, AppColors.inkSoft),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'İbre yeşil bölgenin ortasındayken',
                              style: baloo(13, FontWeight.w600, AppColors.inkMuted),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoundResult extends StatelessWidget {
  final int points;
  const _RoundResult({required this.points});

  @override
  Widget build(BuildContext context) {
    final good = points >= 40;
    final label = points >= 88
        ? 'Tam isabet!'
        : (good ? 'Bölge içinde' : (points > 0 ? 'Kıl payı kaçtı' : 'Çok uzak'));
    return Column(
      children: [
        Text(
          '+$points',
          style: baloo(34, FontWeight.w800, good ? const Color(0xFF13624A) : AppColors.red),
        ),
        Text(label, style: baloo(14, FontWeight.w700, AppColors.inkMuted)),
      ],
    );
  }
}

/// Yarim daire kadran, hedef bolge ve ibreyi cizer.
class _GaugePainter extends CustomPainter {
  final double needlePos;
  final double zoneCenter;
  final double zoneHalf;
  final bool settled;

  _GaugePainter({
    required this.needlePos,
    required this.zoneCenter,
    required this.zoneHalf,
    required this.settled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = min(size.width * 0.45, size.height * 0.86);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = radius * 0.22;

    // Zemin yayi
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFCBD2F0);
    canvas.drawArc(rect, pi, pi, false, track);

    // Hedef bolge
    final zoneStart = pi + pi * (zoneCenter - zoneHalf).clamp(0.0, 1.0);
    final zoneSweep = pi * (2 * zoneHalf).clamp(0.0, 1.0);
    final zone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..shader = const LinearGradient(
        colors: [Color(0xFF8FE8CB), Color(0xFF2E9877)],
      ).createShader(rect);
    canvas.drawArc(rect, zoneStart, zoneSweep, false, zone);

    // Bolgenin tam ortasi (ince beyaz cizgi)
    final midAngle = pi + pi * zoneCenter;
    final mid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.02
      ..color = Colors.white.withOpacity(0.9);
    canvas.drawLine(
      Offset(center.dx + cos(midAngle) * (radius - stroke / 2), center.dy + sin(midAngle) * (radius - stroke / 2)),
      Offset(center.dx + cos(midAngle) * (radius + stroke / 2), center.dy + sin(midAngle) * (radius + stroke / 2)),
      mid,
    );

    // Ibre
    final angle = pi + pi * needlePos.clamp(0.0, 1.0);
    final tip = Offset(
      center.dx + cos(angle) * radius * 1.02,
      center.dy + sin(angle) * radius * 1.02,
    );
    final needlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.055
      ..strokeCap = StrokeCap.round
      ..color = settled ? const Color(0xFF13624A) : AppColors.ink;
    canvas.drawLine(center, tip, needlePaint);

    // Merkez topuz
    final knobRect = Rect.fromCircle(center: center, radius: radius * 0.1);
    final knob = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFD6DBF5)],
      ).createShader(knobRect);
    canvas.drawCircle(center, radius * 0.1, knob);
    canvas.drawCircle(
      center,
      radius * 0.1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.018
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) {
    return old.needlePos != needlePos ||
        old.zoneCenter != zoneCenter ||
        old.zoneHalf != zoneHalf ||
        old.settled != settled;
  }
}
