import 'dart:math';

import 'package:flutter/widgets.dart';

import '../audio/audio_manager.dart';
import 'mini_base.dart';

/// Ekranda kisa sure yukari suzulup kaybolan yazi ("+50", "Mükemmel!" gibi).
class FloatText {
  final String text;
  final Offset pos;
  final Color color;
  final double size;
  double ageMs = 0;
  FloatText(this.text, this.pos, this.color, this.size);
}

/// Kare kare (Ticker ile) guncellenen "arena" bolumlerinin ortak iskeleti:
/// Meyve Kesici, Hedef Tahtasi, Halka Zamani, Serit Kosusu, Kova Yakala,
/// Kacis Parmagi, Bardak Oyunu, Havada Tut.
///
/// Ortak sorumluluklar:
///  - oyun saati: yalnizca oynanis sirasinda ilerler (menu acikken durur),
///    bu yuzden duraklatarak avantaj saglanamaz,
///  - oyun alaninin piksel boyutu ([field]),
///  - sadece cizimi tetikleyen kare sayaci ([frame]),
///  - rekor takibi ve bitis sesi,
///  - uçan yazilar ([floats]).
abstract class ArenaGameController extends MiniGameController {
  final Random rng = Random();

  /// CustomPaint bunu dinler; butun ekrani yeniden kurmadan her karede cizer.
  final ValueNotifier<int> frame = ValueNotifier<int>(0);

  /// Oyun alaninin piksel boyutu (ArenaView bildirir).
  Size field = Size.zero;

  /// Oynanista gecen sure (ms).
  double playMs = 0;

  final List<FloatText> floats = [];

  Duration? _lastTick;
  final Stopwatch _sinceTick = Stopwatch();
  int _shownSec = -1;
  int? _best;
  bool _newRecord = false;

  // ------------------------------------------------------------------
  // Alt sinifin ayarladiklari
  // ------------------------------------------------------------------

  /// Bolum suresi (ms). [timed] true ise dolunca bolum biter.
  int get durationMs => 20000;

  /// false: bolum kendi bitisini yonetir (sure yalnizca bir guvenlik siniri degil).
  bool get timed => true;

  /// true iken oyun saati ilerlemez (orn. "parmagini koy" beklemesi).
  bool get waiting => false;

  /// Rekor karsilastirmasi: true = yuksek deger iyi (puan), false = dusuk iyi (sure).
  bool get higherIsBetter => true;

  /// Siralamaya yazilan deger.
  int get recordValue => points;

  @override
  int? get resultScore => recordValue;

  /// Alt sinifin kendi durumunu sifirlamasi.
  void resetArena();

  /// Her karede cagrilir.
  void update(double dtMs);

  // ------------------------------------------------------------------
  // Olculer
  // ------------------------------------------------------------------

  double get progress => (playMs / durationMs).clamp(0.0, 1.0).toDouble();

  /// Dokunus aninin hassas oyun saati: son kareden bu yana gecen sureyi de
  /// ekler. Ritim/nisan olcumlerinde kare araligi (~16 ms) kadar hata olmaz.
  double get nowMs {
    if (phase != MiniPhase.play || menuOpen || waiting) return playMs;
    return playMs + min(50.0, _sinceTick.elapsedMicroseconds / 1000.0);
  }
  int get remainingSec => max(0, ((durationMs - playMs) / 1000).ceil());

  // ------------------------------------------------------------------
  // Akis
  // ------------------------------------------------------------------

  @override
  void resetState() {
    playMs = 0;
    _lastTick = null;
    _shownSec = -1;
    floats.clear();
    resetArena();
    frame.value++;
  }

  @override
  void onPlayStart() {
    _lastTick = null;
  }

  @override
  void onPause() {
    _lastTick = null;
    _sinceTick
      ..stop()
      ..reset();
  }

  @override
  void onResume(int pausedMs) {
    _lastTick = null;
  }

  /// ArenaView'deki Ticker her karede cagirir.
  void tick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (phase != MiniPhase.play || menuOpen || field.isEmpty) return;
    if (last == null || elapsed <= last) return;

    // Takilma sonrasi buyuk sicramalari engelle.
    final dtMs = min(50.0, (elapsed - last).inMicroseconds / 1000.0);

    for (final f in floats) {
      f.ageMs += dtMs;
    }
    floats.removeWhere((f) => f.ageMs > 750);

    if (waiting) {
      frame.value++;
      return;
    }

    playMs += dtMs;
    _sinceTick
      ..reset()
      ..start();
    update(dtMs);
    if (phase != MiniPhase.play) return;

    if (timed && playMs >= durationMs) {
      playMs = durationMs.toDouble();
      endRun();
      return;
    }

    frame.value++;
    final sec = remainingSec;
    if (sec != _shownSec) {
      _shownSec = sec;
      safeNotify();
    }
  }

  void addFloat(String text, Offset pos, Color color, {double size = 18}) {
    floats.add(FloatText(text, pos, color, size));
  }

  /// Bolumu bitirir; basariliysa rekoru gunceller.
  void endRun() {
    if (phase != MiniPhase.play) return;
    if (passed) {
      AudioManager.instance.playWin();
      final v = recordValue;
      final prev = _best;
      final better = prev == null || (higherIsBetter ? v > prev : v < prev);
      if (better) _best = v;
      _newRecord = prev != null && better;
    } else {
      AudioManager.instance.playLose();
      _newRecord = false;
    }
    finish();
    frame.value++;
  }

  @override
  bool get isRecord => _newRecord;

  @override
  void dispose() {
    frame.dispose();
    super.dispose();
  }
}
