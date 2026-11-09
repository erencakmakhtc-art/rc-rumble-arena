import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';

const int _kTrials = 16;

/// Ekranin o an ne gosterdigi.
enum GoNoGoSignal { waiting, go, stop, feedback }

class GoNoGoController extends MiniGameController {
  final Random _rng = Random();

  GoNoGoSignal signal = GoNoGoSignal.waiting;
  int trial = 0;
  int hits = 0;
  int misses = 0;
  int falseAlarms = 0;
  int earlyTaps = 0;
  String feedback = '';
  bool feedbackGood = false;

  final List<int> reactionTimes = [];
  DateTime? _signalAt;
  int? _bestAvg;
  bool _newRecord = false;

  @override
  void resetState() {
    signal = GoNoGoSignal.waiting;
    trial = 0;
    hits = 0;
    misses = 0;
    falseAlarms = 0;
    earlyTaps = 0;
    feedback = '';
    reactionTimes.clear();
    _signalAt = null;
  }

  @override
  void onPlayStart() {
    _nextTrial();
  }

  /// Duraklatma sirasinda bekleyen isaret zamanlayicilari iptal oldugu icin,
  /// devam edilince icinde bulunulan deneme bastan kurulur (tur sayaci artmaz).
  @override
  void onResume(int pausedMs) {
    trial -= 1;
    _nextTrial();
  }

  void _nextTrial() {
    if (trial >= _kTrials) {
      _finishRun();
      return;
    }
    trial += 1;
    signal = GoNoGoSignal.waiting;
    feedback = '';
    _signalAt = null;
    safeNotify();

    // Bekleme suresi rastgele: oyuncu ne zaman gelecegini tahmin edemesin.
    final waitMs = 700 + _rng.nextInt(1500);
    own(Timer(Duration(milliseconds: waitMs), () {
      if (phase != MiniPhase.play) return;
      // Denemelerin ~%30'u "dur" olsun.
      final isStop = _rng.nextDouble() < 0.3;
      signal = isStop ? GoNoGoSignal.stop : GoNoGoSignal.go;
      _signalAt = DateTime.now();
      safeNotify();

      if (isStop) {
        // Dokunmadan atlatirsa basarili.
        own(Timer(const Duration(milliseconds: 900), () {
          if (phase != MiniPhase.play || signal != GoNoGoSignal.stop) return;
          hits += 1;
          bumpStreak();
          addPoints(60);
          _showFeedback('Durdun, doğru! +60', true);
        }));
      } else {
        // Zamaninda dokunmazsa kacirdi.
        own(Timer(const Duration(milliseconds: 1500), () {
          if (phase != MiniPhase.play || signal != GoNoGoSignal.go) return;
          misses += 1;
          breakStreak();
          _showFeedback('Kaçırdın', false);
        }));
      }
    }));
  }

  void tap() {
    if (phase != MiniPhase.play) return;

    switch (signal) {
      case GoNoGoSignal.waiting:
        // Isaret gelmeden dokundu.
        earlyTaps += 1;
        breakStreak();
        addPoints(-80);
        AudioManager.instance.playWrong();
        _showFeedback('Çok erken! -80', false);
        break;
      case GoNoGoSignal.go:
        final ms = DateTime.now().difference(_signalAt!).inMilliseconds;
        reactionTimes.add(ms);
        hits += 1;
        bumpStreak();
        // 300ms altinda cift puan, sonrasinda 600ms'e kadar azalan bonus.
        final int gained;
        if (ms <= 300) {
          gained = 200;
        } else if (ms < 600) {
          gained = 100 + ((600 - ms) / 300 * 100).round();
        } else {
          gained = 100;
        }
        addPoints(gained);
        AudioManager.instance.playCorrect();
        _showFeedback('$ms ms  +$gained', true);
        break;
      case GoNoGoSignal.stop:
        falseAlarms += 1;
        breakStreak();
        addPoints(-80);
        AudioManager.instance.playWrong();
        _showFeedback('Dur demiştik! -80', false);
        break;
      case GoNoGoSignal.feedback:
        break;
    }
  }

  void _showFeedback(String text, bool good) {
    cancelTimers();
    signal = GoNoGoSignal.feedback;
    feedback = text;
    feedbackGood = good;
    safeNotify();
    own(Timer(const Duration(milliseconds: 750), _nextTrial));
  }

  void _finishRun() {
    final avg = avgMs;
    final prev = _bestAvg;
    if (avg > 0 && (prev == null || avg < prev)) _bestAvg = avg;
    _newRecord = avg > 0 && prev != null && avg < prev;
    finish();
  }

  int get avgMs {
    if (reactionTimes.isEmpty) return 0;
    return (reactionTimes.reduce((a, b) => a + b) / reactionTimes.length).round();
  }

  int get errors => misses + falseAlarms + earlyTaps;

  int get accuracy {
    final total = hits + errors;
    if (total == 0) return 0;
    return ((hits / total) * 100).round();
  }

  @override
  bool get isRecord => _newRecord;

  @override
  String get headlineLabel => 'Ortalama tepki süren';

  @override
  String get headlineValue => avgMs == 0 ? '—' : '$avgMs ms';

  @override
  List<MiniStat> get stats => [
        MiniStat('İSABET', '%$accuracy'),
        MiniStat('EN İYİ COMBO', '$bestStreak'),
        MiniStat('HATA', '${misses + falseAlarms + earlyTaps}'),
      ];

  @override
  String get verdict {
    if (avgMs == 0) return 'Hiç zamanında dokunamadın, tekrar dene.';
    if (errors == 0 && avgMs < 350) return 'Olağanüstü. Hem hızlı hem kontrollü.';
    if (falseAlarms > 2) return 'Hızlısın ama kırmızıya de basıyorsun. Biraz fren.';
    if (earlyTaps > 2) return 'Tahmin etmeye çalışma, işareti bekle.';
    if (avgMs < 400) return 'Keskin refleks. Sinyali anında yakalıyorsun.';
    return 'İyi iş. Biraz daha odakla süre düşecek.';
  }
}

class GoNoGoScreen extends StatefulWidget {
  final GameController app;
  const GoNoGoScreen({super.key, required this.app});

  @override
  State<GoNoGoScreen> createState() => _GoNoGoScreenState();
}

class _GoNoGoScreenState extends State<GoNoGoScreen> {
  late final GoNoGoController _c;

  @override
  void initState() {
    super.initState();
    _c = GoNoGoController();
    _c.onFinished = () => widget.app.reportModeResult(GameMode.goNoGo, _c.points, false);
    _c.begin(skipIntro: widget.app.shouldSkipIntro(GameMode.goNoGo));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return MiniStage(
          mode: GameMode.goNoGo,
          controller: _c,
          onQuit: widget.app.backToModes,
          dontShowIntro: widget.app.shouldSkipIntro(GameMode.goNoGo),
          onDontShowIntroChanged: (v) => widget.app.setSkipIntro(GameMode.goNoGo, v),
          onRetry: () {
            if (widget.app.tryConsumePlayForRetry()) _c.begin(skipIntro: true);
          },
          hud: [
            HudPill(label: 'DENEME', value: '${_c.trial.clamp(0, _kTrials)}/$_kTrials'),
            HudPill(label: 'PUAN', value: '${_c.points}', highlight: true),
          ],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _c.tap(),
            child: Center(child: _SignalPad(controller: _c)),
          ),
        );
      },
    );
  }
}

class _SignalPad extends StatelessWidget {
  final GoNoGoController controller;
  const _SignalPad({required this.controller});

  @override
  Widget build(BuildContext context) {
    late final List<Color> colors;
    late final String title;
    late final String sub;
    late final Color ink;

    switch (controller.signal) {
      case GoNoGoSignal.waiting:
        colors = [Colors.white, const Color(0xFFE2E6FF)];
        title = 'Hazır ol';
        sub = 'İşareti bekle';
        ink = AppColors.inkMuted;
        break;
      case GoNoGoSignal.go:
        colors = [const Color(0xFFD8FFC0), const Color(0xFF79D62F)];
        title = 'GİT';
        sub = 'Hemen dokun';
        ink = AppColors.greenInk;
        break;
      case GoNoGoSignal.stop:
        colors = [const Color(0xFFFFD2D2), const Color(0xFFF05454)];
        title = 'DUR';
        sub = 'Sakın dokunma';
        ink = const Color(0xFF7E1A1A);
        break;
      case GoNoGoSignal.feedback:
        colors = controller.feedbackGood
            ? [const Color(0xFFEFFFE4), const Color(0xFFBFEB96)]
            : [const Color(0xFFFFEAEA), const Color(0xFFF3ACAC)];
        title = controller.feedback;
        sub = '';
        ink = controller.feedbackGood ? AppColors.greenInk : const Color(0xFF7E1A1A);
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 340, minHeight: 240),
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.95), width: 4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: baloo(
              controller.signal == GoNoGoSignal.feedback ? 34 : 52,
              FontWeight.w800,
              ink,
              height: 1.1,
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(sub, style: baloo(15, FontWeight.w700, ink.withOpacity(0.75))),
          ],
        ],
      ),
    );
  }
}
