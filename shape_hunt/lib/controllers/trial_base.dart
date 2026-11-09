import 'dart:async';
import 'dart:math';

import '../audio/audio_manager.dart';
import 'mini_base.dart';

/// Bir denemenin sonucu (arayuzde kisa sureli renk geri bildirimi icin).
enum TrialFeedback { none, correct, wrong, timeout }

/// "Hizli deneme" tipi bolumlerin ortak iskeleti.
///
/// Renk Tuzagi, Ok Firtinasi (ve ileride Hizli Hesap gibi) bolumlerin hepsi
/// ayni kurala dayanir:
///  - sabit toplam sure (varsayilan 20 sn),
///  - her denemenin kendi cevap penceresi (oyun ilerledikce daralir),
///  - dogru cevapta hiz bonusu + her 5'li seride artan bonus,
///  - yanlis/gec cevapta puan cezasi ve zaman kaybi,
///  - [maxErrors] hataya ulasinca oyun aninda biter.
///
/// Alt sinif yalnizca denemeyi uretir ([buildTrial]) ve oyuncunun cevabini
/// degerlendirip [answer] cagirir.
abstract class TrialGameController extends MiniGameController {
  final Random rng = Random();

  // ------------------------------------------------------------------
  // Alt sinifin ayarladiklari
  // ------------------------------------------------------------------

  /// Toplam bolum suresi (ms).
  int get durationMs => 20000;

  /// Gecmek icin gereken puan.
  int get targetPoints;

  /// Bu kadar hata (yanlis + gec kalma) olunca oyun biter.
  int get maxErrors => 3;

  /// Bu surenin altindaki dogru cevaplar hiz bonusu alir (ms).
  int get fastMs;

  /// Ilerlemeye (0..1) gore bir denemenin cevap penceresi (ms).
  int trialWindowMs(double progress);

  /// Yeni bir deneme uretir; alt sinif kendi alanlarini doldurur.
  void buildTrial();

  /// Alt sinifin kendi alanlarini sifirlamasi icin.
  void resetTrialState() {}

  // ------------------------------------------------------------------
  // Durum
  // ------------------------------------------------------------------

  int elapsedMs = 0;
  int correct = 0;
  int wrong = 0;
  int timeouts = 0;
  int trials = 0;
  final List<int> _reactions = [];

  TrialFeedback feedback = TrialFeedback.none;

  /// Denemenin cevap penceresinden kalan oran (1 -> 0). Zaman cubugu icin.
  double windowLeft = 1.0;

  DateTime? _startedAt;
  DateTime? _trialAt;
  int _windowMs = 1000;
  bool _awaitingNext = false;
  Timer? _tick;
  int? _best;
  bool _newRecord = false;

  int get errors => wrong + timeouts;
  bool get failedByErrors => errors >= maxErrors;
  double get progress => (elapsedMs / durationMs).clamp(0.0, 1.0).toDouble();
  int get remainingMs => max(0, durationMs - elapsedMs);

  /// Su anki denemenin baslangicindan bu yana gecen sure (ms).
  int get trialElapsedMs => _trialAt == null ? 0 : DateTime.now().difference(_trialAt!).inMilliseconds;

  int get avgReactionMs {
    if (_reactions.isEmpty) return 0;
    return (_reactions.reduce((a, b) => a + b) / _reactions.length).round();
  }

  /// Su an cevap kabul ediliyor mu (geri bildirim/gecis anlarinda kilitli).
  bool get acceptingInput =>
      phase == MiniPhase.play && !menuOpen && !_awaitingNext && feedback == TrialFeedback.none;

  // ------------------------------------------------------------------
  // Akis
  // ------------------------------------------------------------------

  @override
  void resetState() {
    elapsedMs = 0;
    correct = 0;
    wrong = 0;
    timeouts = 0;
    trials = 0;
    _reactions.clear();
    feedback = TrialFeedback.none;
    windowLeft = 1.0;
    _startedAt = null;
    _trialAt = null;
    _awaitingNext = false;
    _tick?.cancel();
    resetTrialState();
  }

  @override
  void onPlayStart() {
    _startedAt = DateTime.now();
    _startTick();
    _nextTrial();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = own(Timer.periodic(const Duration(milliseconds: 40), (_) => _onTick()));
  }

  void _onTick() {
    if (phase != MiniPhase.play || menuOpen || _startedAt == null) return;
    final now = DateTime.now();
    elapsedMs = now.difference(_startedAt!).inMilliseconds;
    if (elapsedMs >= durationMs) {
      elapsedMs = durationMs;
      _finishRun();
      return;
    }
    if (!_awaitingNext && _trialAt != null) {
      final used = now.difference(_trialAt!).inMilliseconds;
      windowLeft = (1 - used / _windowMs).clamp(0.0, 1.0).toDouble();
      if (used >= _windowMs) {
        _onTimeout();
        return;
      }
    }
    safeNotify();
  }

  /// Menude gecen sure ne toplam sureye ne de denemenin penceresine sayilir.
  /// Duraklatma sirasinda iptal edilen zamanlayicilar yeniden kurulur.
  @override
  void onResume(int pausedMs) {
    final d = Duration(milliseconds: pausedMs);
    if (_startedAt != null) _startedAt = _startedAt!.add(d);
    if (_trialAt != null) _trialAt = _trialAt!.add(d);
    _startTick();
    if (_awaitingNext) _scheduleNext(200);
  }

  void _nextTrial() {
    if (phase != MiniPhase.play) return;
    if (failedByErrors) {
      _finishRun();
      return;
    }
    _awaitingNext = false;
    feedback = TrialFeedback.none;
    trials += 1;
    buildTrial();
    _windowMs = trialWindowMs(progress);
    _trialAt = DateTime.now();
    windowLeft = 1.0;
    safeNotify();
  }

  void _scheduleNext(int ms) {
    _awaitingNext = true;
    own(Timer(Duration(milliseconds: ms), _nextTrial));
  }

  /// Alt sinif, oyuncunun cevabini degerlendirdikten sonra cagirir.
  void answer(bool isCorrect) {
    if (!acceptingInput || _trialAt == null) return;
    final rt = DateTime.now().difference(_trialAt!).inMilliseconds;

    if (isCorrect) {
      correct += 1;
      _reactions.add(rt);
      bumpStreak();
      var gained = 100;
      if (rt < fastMs) gained += ((fastMs - rt) / fastMs * 60).round();
      String? label;
      if (streak % 5 == 0) {
        // 5'li seri +100, 10'lu +150, 15'li +200 ...
        gained += 50 + 50 * (streak ~/ 5);
        label = 'Seri x$streak! +$gained';
      }
      addPoints(gained, label: label);
      feedback = TrialFeedback.correct;
      AudioManager.instance.playCorrect();
      _scheduleNext(140);
    } else {
      wrong += 1;
      breakStreak();
      addPoints(-150, label: 'Yanlış! −150', good: false);
      feedback = TrialFeedback.wrong;
      AudioManager.instance.playWrong();
      // Hata zaman da kaybettirir; son hatada sonucu gorsun diye kisa bekleme.
      _scheduleNext(failedByErrors ? 550 : 450);
    }
    safeNotify();
  }

  void _onTimeout() {
    timeouts += 1;
    breakStreak();
    addPoints(-100, label: 'Geç kaldın! −100', good: false);
    feedback = TrialFeedback.timeout;
    windowLeft = 0;
    AudioManager.instance.playWrong();
    _scheduleNext(failedByErrors ? 550 : 350);
    safeNotify();
  }

  void _finishRun() {
    if (phase != MiniPhase.play) return;
    _tick?.cancel();
    if (passed) {
      AudioManager.instance.playWin();
      final prev = _best;
      if (prev == null || points > prev) _best = points;
      _newRecord = prev != null && points > prev;
    } else {
      AudioManager.instance.playLose();
      _newRecord = false;
    }
    finish();
  }

  // ------------------------------------------------------------------
  // Sonuc
  // ------------------------------------------------------------------

  @override
  bool get passed => !failedByErrors && points >= targetPoints;

  @override
  bool get isRecord => _newRecord;

  @override
  String get headlineLabel {
    if (passed) return 'Toplam puanın';
    if (failedByErrors) return '$maxErrors hata yaptın';
    return '$targetPoints puana ulaşamadın';
  }

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('DOĞRU', '$correct'),
        MiniStat('ORT. TEPKİ', avgReactionMs == 0 ? '—' : '$avgReactionMs ms'),
        MiniStat('HATA', '$errors/$maxErrors'),
      ];
}
