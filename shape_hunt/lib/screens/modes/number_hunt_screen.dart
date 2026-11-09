import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';

/// Tahtadaki sayi adedi (5x5).
const int _kNumCount = 25;
const int _kNumCols = 5;

/// Gecme sarti: 25 sayiyi (cezalar dahil) bu surenin altinda bitirmek.
const int _kNumPassMs = 18000;

/// Guvenlik ust siniri: bu sureye ulasilirsa oyun biter.
const int _kNumLimitMs = 45000;

/// Yanlis dokunusun ekledigi ceza (ms).
const int _kNumPenaltyMs = 1000;

/// Bu kadar yanlis dokunusta oyun biter.
const int _kNumMaxWrong = 3;

/// Her bu kadar sayi bulununca butun tahta yeniden karisir.
const int _kNumShuffleEvery = 5;

/// Sayilarin boyandigi renkler (her sayi rastgele birini alir).
const List<Color> _kNumInks = [
  Color(0xFF3F4478),
  Color(0xFFD9437F),
  Color(0xFF1E7FC0),
  Color(0xFF2B9453),
  Color(0xFFD9701A),
  Color(0xFF7446C8),
];

/// Tahtadaki tek bir sayinin gorunumu. Boyut, aci ve renk her karistirmada
/// yeniden rastgele secilir ki goz sabit bir desene alismasin.
class NumberCell {
  final int value;
  final double scale;
  final double angle;
  final Color ink;
  const NumberCell(this.value, this.scale, this.angle, this.ink);
}

class NumberHuntController extends MiniGameController {
  final Random _rng = Random();

  /// 25 hucre. Oyun baslamadan once bos (geri sayimda on-tarama olmasin).
  List<NumberCell?> cells = List<NumberCell?>.filled(_kNumCount, null);

  /// Bulunan sayilar (soluk gosterilir ama tahtada kalir; dikkat dagitirlar).
  final Set<int> found = <int>{};

  /// Siradaki aranan sayi.
  int next = 1;

  int wrongTaps = 0;
  int penaltyMs = 0;
  int elapsedMs = 0;
  bool timedOut = false;
  int? wrongIndex;

  /// Her karistirmada artar; hucrelerin giris animasyonu icin anahtar.
  int shuffleGen = 0;

  DateTime? _startedAt;
  Timer? _tick;
  int? _bestMs;
  bool _newRecord = false;

  bool get finishedAll => next > _kNumCount;

  @override
  int? get resultScore => finishedAll ? elapsedMs : null;

  @override
  void resetState() {
    cells = List<NumberCell?>.filled(_kNumCount, null);
    found.clear();
    next = 1;
    wrongTaps = 0;
    penaltyMs = 0;
    elapsedMs = 0;
    timedOut = false;
    wrongIndex = null;
    shuffleGen = 0;
    _startedAt = null;
    _tick?.cancel();
  }

  @override
  void onPlayStart() {
    _shuffle();
    _startedAt = DateTime.now();
    _startTick();
    safeNotify();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = own(Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (phase != MiniPhase.play || menuOpen || _startedAt == null) return;
      elapsedMs = DateTime.now().difference(_startedAt!).inMilliseconds + penaltyMs;
      if (elapsedMs >= _kNumLimitMs) {
        elapsedMs = _kNumLimitMs;
        timedOut = true;
        _finishRun();
        return;
      }
      safeNotify();
    }));
  }

  /// Menude gecen sure sayilmaz; duraklatmada iptal edilen sayac yeniden kurulur.
  @override
  void onResume(int pausedMs) {
    if (_startedAt != null) {
      _startedAt = _startedAt!.add(Duration(milliseconds: pausedMs));
    }
    wrongIndex = null;
    _startTick();
  }

  /// 1..25'i rastgele hucrelere dagitir; her sayiya yeni boyut/aci/renk verir.
  void _shuffle() {
    final values = List<int>.generate(_kNumCount, (i) => i + 1)..shuffle(_rng);
    cells = [
      for (final v in values)
        NumberCell(
          v,
          0.72 + _rng.nextDouble() * 0.43,
          (_rng.nextDouble() * 2 - 1) * 0.35,
          _kNumInks[_rng.nextInt(_kNumInks.length)],
        ),
    ];
    shuffleGen += 1;
  }

  void tap(int index) {
    if (phase != MiniPhase.play || menuOpen) return;
    final cell = cells[index];
    if (cell == null) return;

    if (cell.value == next) {
      found.add(cell.value);
      next += 1;
      AudioManager.instance.playCorrect();
      if (finishedAll) {
        _finishRun();
        return;
      }
      if ((next - 1) % _kNumShuffleEvery == 0) {
        _shuffle();
        showToast('Karıştı!', ms: 600);
      }
      safeNotify();
      return;
    }

    // Yanlis sayi (ya da daha once bulunmus soluk bir sayi).
    wrongTaps += 1;
    penaltyMs += _kNumPenaltyMs;
    wrongIndex = index;
    AudioManager.instance.playWrong();
    if (wrongTaps >= _kNumMaxWrong) {
      _finishRun();
      return;
    }
    showToast('+1 sn ceza', good: false, ms: 600);
    safeNotify();
    own(Timer(const Duration(milliseconds: 360), () {
      wrongIndex = null;
      safeNotify();
    }));
  }

  void _finishRun() {
    if (phase != MiniPhase.play) return;
    _tick?.cancel();
    if (_startedAt != null && !timedOut) {
      elapsedMs = DateTime.now().difference(_startedAt!).inMilliseconds + penaltyMs;
    }
    // Bitiremediyse (3 yanlis ya da sure) siralamaya kisa sure yazilmasin.
    if (!finishedAll) elapsedMs = _kNumLimitMs;

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
  bool get passed => finishedAll && wrongTaps < _kNumMaxWrong && elapsedMs <= _kNumPassMs;

  @override
  bool get isRecord => _newRecord;

  @override
  String get headlineLabel {
    if (passed) return 'Bitirme süren';
    if (wrongTaps >= _kNumMaxWrong) return '$_kNumMaxWrong yanlış dokunuş';
    if (finishedAll) return '${_kNumPassMs ~/ 1000} sn sınırını aştın';
    return 'Süre doldu';
  }

  @override
  String get headlineValue => finishedAll
      ? '${(elapsedMs / 1000).toStringAsFixed(2)} sn'
      : '${found.length}/$_kNumCount';

  @override
  List<MiniStat> get stats => [
        MiniStat('BULUNAN', '${found.length}/$_kNumCount'),
        MiniStat('CEZA', '${(penaltyMs / 1000).toStringAsFixed(0)} sn'),
        MiniStat('HATA', '$wrongTaps/$_kNumMaxWrong'),
      ];

  @override
  String get verdict {
    final s = elapsedMs / 1000;
    if (wrongTaps == 0 && s < 12) return 'Gözlerin tarayıcı gibi. Karışıklık seni durduramadı.';
    if (wrongTaps == 0) return 'Hatasız bitirdin! Tarama hızını artırırsan rekor gelir.';
    return 'Bitirdin! Cezasız bir tur süreni ciddi düşürür.';
  }
}

class NumberHuntScreen extends StatefulWidget {
  final GameController app;
  const NumberHuntScreen({super.key, required this.app});

  @override
  State<NumberHuntScreen> createState() => _NumberHuntScreenState();
}

class _NumberHuntScreenState extends State<NumberHuntScreen> {
  late final NumberHuntController _c;

  @override
  void initState() {
    super.initState();
    _c = NumberHuntController();
    _c.onFinished = () => widget.app.reportModeResult(GameMode.numberHunt, _c.elapsedMs, _c.passed);
    _c.begin(skipIntro: widget.app.shouldSkipIntro(GameMode.numberHunt));
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
          mode: GameMode.numberHunt,
          controller: _c,
          onQuit: widget.app.backToModes,
          dontShowIntro: widget.app.shouldSkipIntro(GameMode.numberHunt),
          onDontShowIntroChanged: (v) => widget.app.setSkipIntro(GameMode.numberHunt, v),
          onRetry: () {
            if (widget.app.tryConsumePlayForRetry()) _c.begin(skipIntro: true);
          },
          hud: [
            HudPill(label: 'SIRADAKİ', value: _c.finishedAll ? '✓' : '${_c.next}', highlight: true),
            HudPill(
              label: 'SÜRE',
              value: (_c.elapsedMs / 1000).toStringAsFixed(1),
              highlight: _c.elapsedMs > _kNumPassMs,
            ),
            HudPill(label: 'HATA', value: '${_c.wrongTaps}/$_kNumMaxWrong', highlight: _c.wrongTaps >= 2),
          ],
          child: Center(
            child: Container(
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
                  BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 7)),
                ],
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _kNumCols,
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                ),
                itemCount: _kNumCount,
                itemBuilder: (context, i) {
                  final cell = _c.cells[i];
                  return RepaintBoundary(
                    child: _NumberTile(
                      key: ValueKey('${_c.shuffleGen}-$i'),
                      cell: cell,
                      found: cell != null && _c.found.contains(cell.value),
                      wrong: _c.wrongIndex == i,
                      onTap: () => _c.tap(i),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NumberTile extends StatelessWidget {
  final NumberCell? cell;
  final bool found;
  final bool wrong;
  final VoidCallback onTap;

  const _NumberTile({
    super.key,
    required this.cell,
    required this.found,
    required this.wrong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = cell;
    return Listener(
      // Aninda tepki: jest arenasini beklemeden dokunusu yakalar.
      onPointerDown: (_) => onTap(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: wrong ? AppColors.red.withOpacity(0.95) : Colors.white.withOpacity(0.92),
            width: wrong ? 3 : 2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: wrong
                ? const [Color(0xFFFFE3E3), Color(0xFFFFC2C2)]
                : const [Colors.white, Color(0xFFEFF1FF)],
          ),
        ),
        child: c == null
            ? const SizedBox.expand()
            : TweenAnimationBuilder<double>(
                // Karistirmada yeni tahta hafifce buyuyerek belirir.
                tween: Tween(begin: 0.55, end: 1.0),
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutBack,
                builder: (context, s, child) => Transform.scale(scale: s, child: child),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final size = min(box.maxWidth, box.maxHeight) * 0.5 * c.scale;
                    return Center(
                      child: Opacity(
                        opacity: found ? 0.22 : 1.0,
                        child: Transform.rotate(
                          angle: c.angle,
                          child: Text(
                            '${c.value}',
                            style: baloo(size, FontWeight.w800, c.ink, height: 1.0),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
