import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_manager.dart';

/// Bir mini bolumun icinde bulundugu faz.
/// intro: "nasil oynanir" karti gosteriliyor, oyuncunun onayi bekleniyor.
/// count: 3-2-1 geri sayimi.
/// play: bolum oynaniyor.
/// done: bolum bitti, sonuc karti gosteriliyor.
enum MiniPhase { intro, count, play, done }

/// Bolum sonunda sonuc kartinda gosterilecek tek bir olcum satiri.
class MiniStat {
  final String label;
  final String value;
  const MiniStat(this.label, this.value);
}

/// Oyun sirasinda kisa sureligine ekranda beliren puan/bonus bildirimi.
class MiniToast {
  final String text;
  final bool good;
  final int id;
  const MiniToast(this.text, this.good, this.id);
}

/// Butun mini bolumlerin ortak iskeleti.
///
/// Ortak sorumluluklar: intro -> 3-2-1 geri sayim -> oynanis -> sonuc akisi,
/// duraklatma (menu acilinca), puan birikimi, bonus bildirimleri ve
/// zamanlayicilarin guvenli temizlenmesi.
abstract class MiniGameController extends ChangeNotifier {
  MiniPhase phase = MiniPhase.intro;
  int count = 3;
  bool _disposed = false;

  /// Menu (cikis onayi) acik mi. Acikken bolum duraklatilir.
  bool menuOpen = false;
  DateTime? _pausedAt;

  /// Bolumde toplanan puan. Her bolum kendi kurallariyla arttirir.
  int points = 0;

  /// Ard arda dogru yapma sayaci (combo). Bonus hesabinda kullanilir.
  int streak = 0;
  int bestStreak = 0;

  /// Ekranda kisa sureligine gosterilen son bildirim.
  MiniToast? toast;
  int _toastSeq = 0;

  Timer? _countTimer;
  Timer? _toastTimer;
  final List<Timer> _ownedTimers = [];

  /// Bolum sonunda sonuc kartinda gosterilecek ana deger.
  String get headlineValue;

  /// Ana degerin ustundeki aciklama.
  String get headlineLabel;

  /// Sonuc kartindaki kucuk olcum kutulari.
  List<MiniStat> get stats;

  /// Oyuncuya kisa geri bildirim cumlesi.
  String get verdict;

  /// Bu turda yeni bir kisisel rekor kirildi mi.
  bool get isRecord => false;

  /// Bolum basariyla gecildi mi (kademeli kilit icin). Alt siniflar kendi
  /// gecme kuralina gore override eder; varsayilan true (basari sarti yok).
  bool get passed => true;

  /// Bu turun siralamaya yazilan sayisal skoru (sure bazli bolumde ms, puan
  /// bazlida puan). null ise sonuc karti puan bazli bolumde [points]'i
  /// kullanir. Sonuc kartindaki dunya sirasi bu degerden hesaplanir.
  int? get resultScore => null;

  /// Geri sayim bitip oynanis basladiginda cagrilir.
  void onPlayStart();

  /// Bolum bastan baslatilirken tum duruma sifirlanir.
  void resetState();

  /// Menu acilip bolum duraklatildiginda cagrilir (alt sinif kendi
  /// zaman referanslarini dondurabilir).
  void onPause() {}

  /// Menuden devam edildiginde cagrilir. [pausedMs] duraklamanin ne kadar
  /// surdugudur; alt sinif zaman referanslarini bu kadar ileri kaydirarak
  /// oyuncunun duraklatarak avantaj saglamasini engeller.
  void onResume(int pausedMs) {}

  // ------------------------------------------------------------------
  // Akis
  // ------------------------------------------------------------------

  /// Bolumu hazirlar. [skipIntro] true ise tanitim karti atlanip dogrudan
  /// geri sayima gecilir (tekrar oyna, ya da "bir daha gosterme" secildiyse).
  void begin({bool skipIntro = false}) {
    cancelTimers();
    resetState();
    points = 0;
    streak = 0;
    bestStreak = 0;
    toast = null;
    menuOpen = false;
    _pausedAt = null;
    count = 3;

    if (skipIntro) {
      _runCount(3);
    } else {
      phase = MiniPhase.intro;
      safeNotify();
    }
  }

  /// Tanitim kartindaki "Anladim" butonu.
  void confirmIntro() {
    if (phase != MiniPhase.intro) return;
    _runCount(3);
  }

  void _runCount(int n) {
    if (_disposed) return;
    if (n == 0) {
      phase = MiniPhase.play;
      AudioManager.instance.playGo();
      safeNotify();
      onPlayStart();
      return;
    }
    phase = MiniPhase.count;
    count = n;
    AudioManager.instance.playCount(n);
    safeNotify();
    _countTimer = Timer(const Duration(milliseconds: 1000), () => _runCount(n - 1));
  }

  /// Bolum bittiginde cagrilir (skoru uygulama duzeyinde kaydetmek icin).
  VoidCallback? onFinished;

  /// Bolumu bitirir ve sonuc kartini acar.
  void finish() {
    cancelTimers();
    if (streak > bestStreak) bestStreak = streak;
    phase = MiniPhase.done;
    toast = null;
    onFinished?.call();
    safeNotify();
  }

  // ------------------------------------------------------------------
  // Duraklatma (menu)
  // ------------------------------------------------------------------

  void openMenu() {
    if (menuOpen) return;
    menuOpen = true;
    _pausedAt = DateTime.now();
    cancelTimers();
    // Bildirimin kapanma zamanlayicisi iptal edildi; ekranda takili kalmasin.
    toast = null;
    onPause();
    safeNotify();
  }

  void closeMenu() {
    if (!menuOpen) return;
    menuOpen = false;
    final pausedMs = _pausedAt == null ? 0 : DateTime.now().difference(_pausedAt!).inMilliseconds;
    _pausedAt = null;

    if (phase == MiniPhase.count) {
      // Geri sayim yarida kaldiysa bastan saydir.
      _runCount(3);
    } else if (phase == MiniPhase.play) {
      onResume(pausedMs);
    }
    safeNotify();
  }

  // ------------------------------------------------------------------
  // Puan / bonus
  // ------------------------------------------------------------------

  /// Puan ekler ve istege bagli olarak ekranda bir bildirim gosterir.
  void addPoints(int amount, {String? label, bool good = true}) {
    points += amount;
    if (points < 0) points = 0;
    if (label != null) showToast(label, good: good);
  }

  /// Dogru hamle: combo sayacini arttirir.
  void bumpStreak() {
    streak += 1;
    if (streak > bestStreak) bestStreak = streak;
  }

  /// Hatali hamle: combo sifirlanir.
  void breakStreak() {
    if (streak > bestStreak) bestStreak = streak;
    streak = 0;
  }

  void showToast(String text, {bool good = true, int ms = 850}) {
    _toastSeq += 1;
    toast = MiniToast(text, good, _toastSeq);
    safeNotify();
    _toastTimer?.cancel();
    _toastTimer = Timer(Duration(milliseconds: ms), () {
      toast = null;
      safeNotify();
    });
  }

  // ------------------------------------------------------------------
  // Zamanlayici yonetimi
  // ------------------------------------------------------------------

  /// Alt siniflarin olusturdugu zamanlayicilari kaydeder ki tek noktadan
  /// iptal edilebilsinler. Uzun bolumlerde onlarca kisa timer uretildigi
  /// icin, yeni kayit sirasinda islevi bitmis olanlar listeden ayiklanir.
  Timer own(Timer t) {
    _ownedTimers.removeWhere((x) => !x.isActive);
    _ownedTimers.add(t);
    return t;
  }

  void cancelTimers() {
    _countTimer?.cancel();
    _toastTimer?.cancel();
    for (final t in _ownedTimers) {
      t.cancel();
    }
    _ownedTimers.clear();
  }

  /// dispose sonrasi notifyListeners cagrisini engeller.
  void safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  bool get disposedSafely => _disposed;

  @override
  void dispose() {
    _disposed = true;
    cancelTimers();
    super.dispose();
  }
}
