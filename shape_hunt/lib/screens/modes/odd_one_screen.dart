import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../data/color_defs.dart';
import '../../data/pairs.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';
import '../../widgets/shape_view.dart';

const int _kOddRounds = 12;
const int _kOddPenaltyMs = 500;
const int _kOddTimeLimitMs = 18000;

/// Bir turun tanimi: izgara boyutu, hangi hucrenin farkli oldugu ve
/// farkin ne kadar belirgin oldugu.
class _OddRound {
  final int cols;
  final int rows;
  final int oddIndex;
  final ShapePair pair;
  final List<Color> baseColors;
  final List<Color> oddColors;

  const _OddRound({
    required this.cols,
    required this.rows,
    required this.oddIndex,
    required this.pair,
    required this.baseColors,
    required this.oddColors,
  });

  int get cells => cols * rows;
}

class OddOneController extends MiniGameController {
  final Random _rng = Random();

  int round = 0;
  int penaltyMs = 0;
  int wrongTaps = 0;
  int? wrongIndex;
  int solved = 0;

  /// Toplam gecen sure (ms). 18 sn'yi asarsa oyun basarisiz biter.
  int elapsedMs = 0;
  bool timedOut = false;

  _OddRound? current;
  DateTime? _startedAt;
  Timer? _tick;
  int? _bestMs;
  bool _newRecord = false;

  @override
  void resetState() {
    round = 0;
    penaltyMs = 0;
    wrongTaps = 0;
    wrongIndex = null;
    solved = 0;
    elapsedMs = 0;
    timedOut = false;
    current = null;
    _startedAt = null;
    _tick?.cancel();
  }

  @override
  void onPlayStart() {
    _startedAt = DateTime.now();
    _startTick();
    _nextRound();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (phase != MiniPhase.play) return;
      elapsedMs = DateTime.now().difference(_startedAt!).inMilliseconds + penaltyMs;
      if (elapsedMs >= _kOddTimeLimitMs) {
        elapsedMs = _kOddTimeLimitMs;
        timedOut = true;
        _finishRun();
        return;
      }
      safeNotify();
    });
    own(_tick!);
  }

  /// Duraklatma: gecen sure menu aciksa isletilmemeli.
  /// Menu acilinca sayac iptal edildigi icin burada yeniden kurulur; aksi
  /// halde sure donar ve 18 sn siniri hic dolmazdi.
  @override
  void onResume(int pausedMs) {
    if (_startedAt != null) {
      _startedAt = _startedAt!.add(Duration(milliseconds: pausedMs));
    }
    wrongIndex = null;
    _startTick();
  }

  /// Kalan sure (ms).
  int get remainingMs => (_kOddTimeLimitMs - elapsedMs).clamp(0, _kOddTimeLimitMs);

  /// Bu bolumu "gecti" mi: 18 sn dolmadan 12 turu bitirdiyse.
  @override
  bool get passed => solved >= _kOddRounds && !timedOut;

  @override
  int? get resultScore => passed ? elapsedMs : null;

  void _nextRound() {
    if (round >= _kOddRounds) {
      _finishRun();
      return;
    }
    round += 1;

    final int cols;
    final int rows;
    if (round <= 2) {
      cols = 3;
      rows = 3;
    } else if (round <= 5) {
      cols = 4;
      rows = 4;
    } else if (round <= 9) {
      cols = 5;
      rows = 5;
    } else {
      cols = 5;
      rows = 6;
    }

    // Saydamlik (fark) 0.50'den azalir ama en fazla 9. tur seviyesine kadar;
    // 10, 11 ve 12. turlar 9. tur ile AYNI saydamliktadir (asiri zorlasmasin).
    final effRound = round > 9 ? 9 : round;
    final t = (effRound - 1) / (_kOddRounds - 1);
    final delta = 0.50 - (0.50 - 0.14) * t;

    final pair = kPairs[_rng.nextInt(kPairs.length)];
    final base = kColorGradients[pair.color]!;
    final odd = <Color>[
      for (final c in base) Color.lerp(c, Colors.white, delta)!,
    ];

    current = _OddRound(
      cols: cols,
      rows: rows,
      oddIndex: _rng.nextInt(cols * rows),
      pair: pair,
      baseColors: base,
      oddColors: odd,
    );
    wrongIndex = null;
    safeNotify();
  }

  void tap(int index) {
    if (phase != MiniPhase.play || current == null) return;

    if (index == current!.oddIndex) {
      solved += 1;
      AudioManager.instance.playCorrect();
      _nextRound();
    } else {
      // Yanlis: 0,5 sn ceza (sureye eklenir).
      wrongTaps += 1;
      penaltyMs += _kOddPenaltyMs;
      wrongIndex = index;
      AudioManager.instance.playWrong();
      safeNotify();
      own(Timer(const Duration(milliseconds: 360), () {
        wrongIndex = null;
        safeNotify();
      }));
    }
  }

  void _finishRun() {
    _tick?.cancel();
    if (!timedOut && _startedAt != null) {
      elapsedMs = DateTime.now().difference(_startedAt!).inMilliseconds + penaltyMs;
    }
    if (passed) {
      AudioManager.instance.playWin();
      final prev = _bestMs;
      if (prev == null || elapsedMs < prev) _bestMs = elapsedMs;
      _newRecord = prev != null && elapsedMs < prev;
    } else {
      AudioManager.instance.playLose();
      _newRecord = false;
    }
    finish();
  }

  @override
  bool get isRecord => _newRecord;

  @override
  String get headlineLabel => passed ? 'Bitirme süren' : 'Süre doldu';

  @override
  String get headlineValue =>
      passed ? '${(elapsedMs / 1000).toStringAsFixed(2)} sn' : '$solved/$_kOddRounds';

  @override
  List<MiniStat> get stats => [
        MiniStat('DOĞRU', '$solved/$_kOddRounds'),
        MiniStat('CEZA', '${(penaltyMs / 1000).toStringAsFixed(1)} sn'),
        MiniStat('HATA', '$wrongTaps'),
      ];

  @override
  String get verdict {
    if (!passed) return '18 saniyede bitiremedin. Farkları daha hızlı yakalamayı dene!';
    final s = elapsedMs / 1000;
    if (wrongTaps == 0 && s < 10) return 'Kusursuz ve hızlı. Gözün hiç şaşmadı.';
    if (s < 12) return 'Keskin göz. Farkları anında yakalıyorsun.';
    return 'Bitirdin! Daha az hatayla süren düşer.';
  }
}

class OddOneScreen extends StatefulWidget {
  final GameController app;
  const OddOneScreen({super.key, required this.app});

  @override
  State<OddOneScreen> createState() => _OddOneScreenState();
}

class _OddOneScreenState extends State<OddOneScreen> {
  late final OddOneController _c;

  @override
  void initState() {
    super.initState();
    _c = OddOneController();
    _c.onFinished = () => widget.app.reportModeResult(GameMode.oddOne, _c.elapsedMs, _c.passed);
    _c.begin(skipIntro: widget.app.shouldSkipIntro(GameMode.oddOne));
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
        final r = _c.current;
        return MiniStage(
          mode: GameMode.oddOne,
          controller: _c,
          onQuit: widget.app.backToModes,
          dontShowIntro: widget.app.shouldSkipIntro(GameMode.oddOne),
          onDontShowIntroChanged: (v) => widget.app.setSkipIntro(GameMode.oddOne, v),
          onRetry: () {
            if (widget.app.tryConsumePlayForRetry()) _c.begin(skipIntro: true);
          },
          hud: [
            HudPill(label: 'DOĞRU', value: '${_c.solved}/$_kOddRounds'),
            HudPill(
              label: 'SÜRE',
              value: (_c.remainingMs / 1000).toStringAsFixed(1),
              highlight: _c.remainingMs < 5000,
            ),
          ],
          child: r == null
              ? const SizedBox.shrink()
              : Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.75), width: 2),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white.withOpacity(0.32), Colors.white.withOpacity(0.14)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: r.cols,
                            mainAxisSpacing: 7,
                            crossAxisSpacing: 7,
                          ),
                          itemCount: r.cells,
                          itemBuilder: (context, i) {
                            final isOdd = i == r.oddIndex;
                            return RepaintBoundary(
                              child: _OddTile(
                                pair: r.pair,
                                colors: isOdd ? r.oddColors : r.baseColors,
                                wrong: _c.wrongIndex == i,
                                onTap: () => _c.tap(i),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}

class _OddTile extends StatefulWidget {
  final ShapePair pair;
  final List<Color> colors;
  final bool wrong;
  final VoidCallback onTap;

  const _OddTile({
    required this.pair,
    required this.colors,
    required this.wrong,
    required this.onTap,
  });

  @override
  State<_OddTile> createState() => _OddTileState();
}

class _OddTileState extends State<_OddTile> with SingleTickerProviderStateMixin {
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  }

  @override
  void didUpdateWidget(covariant _OddTile old) {
    super.didUpdateWidget(old);
    if (widget.wrong && !old.wrong) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  double _offset(double t) {
    if (t <= 0 || t >= 1) return 0;
    return sin(t * pi * 5) * 6 * (1 - t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(_offset(_shake.value), 0),
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: widget.wrong ? AppColors.red.withOpacity(0.9) : Colors.white.withOpacity(0.92),
              width: 2,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFEFF1FF)],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final s = min(c.maxWidth, c.maxHeight) * 0.62;
              return Center(
                child: ShapeView(pair: widget.pair, size: s, colorsOverride: widget.colors),
              );
            },
          ),
        ),
      ),
    );
  }
}
