import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Oyunun butun seslerini (menu muzigi + konusma efektleri) tek yerden
/// yoneten singleton.
///
/// Tasarim notlari:
///  - Kisa efektler icin her cagrida yeni bir [AudioPlayer] yaratmak
///    (setReleaseMode + setVolume + play = 3 async platform-channel cagrisi)
///    audioplayers'ta bilinen bir gecikme/jank kaynagidir. Bunun yerine her
///    efekt icin onceden hazirlanmis, tekrar kullanilan bir player tutulur
///    ve [PlayerMode.mediaPlayer] ile calinir.
///  - Onemli: [AudioPlayer.stop] sonrasi [AudioPlayer.resume] bazi Android
///    cihazlarinda sessiz kalir (source yeniden yuklenmedigi icin). Bu
///    yuzden tekrar calmak icin dogrudan [AudioPlayer.play] kullaniyoruz;
///    bu, asset'i bastan yukleyip calar ve guvenilirdir.
///  - Eksik bir ses dosyasi uygulamayi cokertmez; sessizce gecilir.
///  - `warmUp()` icindeki hazirlik sirasinda olusan GECICI hatalar player'i
///    kalici olarak devre disi birakmaz; sadece o anki cagri sessizce
///    atlanir. Kalici devre disi birakma yalnizca `_markUnavailable` ile
///    yapilir (su an hicbir yerden cagrilmiyor, ileride gerekirse).
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final AudioPlayer _music = AudioPlayer();
  bool _musicReady = false;

  /// Efekt adi -> onceden hazirlanmis player.
  final Map<String, AudioPlayer> _sfx = {};

  /// Kalici olarak kullanilamaz oldugu TESPIT EDILEN efektler (dosya yok
  /// vs.). Gecici hatalar buraya yazilmaz; boylece kisa bir aksaklik
  /// yuzunden ses tum oturum boyunca kaybolmaz.
  final Set<String> _unavailable = {};

  bool _warmedUp = false;

  /// Uygulama acilirken bir kez cagrilir: butun kisa efektleri onceden
  /// yukler, boylece ilk calmada gecikme olmaz.
  Future<void> warmUp() async {
    if (_warmedUp) return;
    _warmedUp = true;
    const assets = [
      'audio/count_3.mp3',
      'audio/count_2.mp3',
      'audio/count_1.mp3',
      'audio/go.mp3',
      'audio/ready.wav',
      'audio/stage2_intro.wav',
      'audio/stage3_intro.wav',
      'audio/correct.mp3',
      'audio/wrong.mp3',
      'audio/click.mp3',
      'audio/win.mp3',
      'audio/lose.mp3',
    ];
    for (final a in assets) {
      final p = await _prepare(a);
      if (kDebugMode) {
        debugPrint('AudioManager warmUp: $a -> ${p != null ? "OK" : "SKIPPED"}');
      }
    }
  }

  /// Bir efekt icin player'i hazirlar (bir kez). Dosya yoksa sessizce
  /// isaretler. NOT: `setSource` cagrilmaz; source'u `play()` sirasinda
  /// veriyoruz. Bu, `mediaPlayer` modunda bazi Android cihazlarda yasanan
  /// "prepare oldu ama ses yok" durumunu engeller.
  Future<AudioPlayer?> _prepare(String asset) async {
    if (_unavailable.contains(asset)) return null;
    final existing = _sfx[asset];
    if (existing != null) return existing;
    try {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.mediaPlayer);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(1.0);
      _sfx[asset] = p;
      return p;
    } catch (_) {
      // Gecici bir hata olabilir; kalici olarak isaretlemek yerine sadece
      // bu cagri icin null don. Bir sonraki _play tekrar deneyecek.
      return null;
    }
  }

  /// Kisa bir efekti calar. Ayni ses ust uste gelirse bastan baslatilir.
  Future<void> _play(String asset, {double volume = 1.0}) async {
    if (_unavailable.contains(asset)) return;
    try {
      final p = await _prepare(asset);
      if (p == null) return;
      await p.setVolume(volume);
      // stop + resume yerine dogrudan play: player basa alinir ve asset
      // yeniden yuklenir. Bazi Android cihazlarda stop sonrasi resume'un
      // sessiz kalmasi bilinen bir sorun.
      await p.play(AssetSource(asset));
    } catch (_) {
      // Tek bir efektin calmamasi oyunu etkilememeli.
    }
  }

  /// (Su an kullanilmiyor.) Bir asset'i kalici olarak devre disi birakir.
  /// Dosyanin gercekten olmadigi netlestiginde cagrilabilir.
  void _markUnavailable(String asset) {
    _unavailable.add(asset);
  }

  // ------------------------------------------------------------------
  // Menu muzigi
  // ------------------------------------------------------------------

  Future<void> playMenuMusic() async {
    if (_musicReady) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.12);
      await _music.play(AssetSource('audio/menu_music.mp3'));
      _musicReady = true;
    } catch (_) {
      // menu_music.mp3 yoksa sessizce gec.
    }
  }

  /// Uygulama arka plana alininca muzigi duraklatir (ekran kapansa bile
  /// ses calmaya devam etmesin). [resumeFromBackground] ile geri doner.
  bool _musicPausedByLifecycle = false;

  Future<void> pauseForBackground() async {
    if (_musicReady) {
      _musicPausedByLifecycle = true;
      try {
        await _music.pause();
      } catch (_) {}
    }
  }

  Future<void> resumeFromBackground() async {
    if (_musicPausedByLifecycle && _musicReady) {
      _musicPausedByLifecycle = false;
      try {
        await _music.resume();
      } catch (_) {}
    }
  }

  Future<void> stopMenuMusic() async {
    if (!_musicReady) return;
    _musicReady = false;
    _musicPausedByLifecycle = false;
    try {
      await _music.stop();
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // Seslendirme efektleri (hepsi kullanicinin kendi kayitlari)
  // ------------------------------------------------------------------

  /// Geri sayimda "3", "2", "1".
  void playCount(int n) {
    switch (n) {
      case 3:
        _play('audio/count_3.mp3');
        break;
      case 2:
        _play('audio/count_2.mp3');
        break;
      case 1:
        _play('audio/count_1.mp3');
        break;
    }
  }

  /// 1. asama basindaki "Hazir" anonsu.
  void playReady() => _play('audio/ready.wav');

  /// Geri sayim bitip oyun basladigi an "Go".
  void playGo() => _play('audio/go.mp3');

  /// 2. asama anonsu.
  void playStage2Intro() => _play('audio/stage2_intro.wav');

  /// 3. (final) asama anonsu.
  void playStage3Intro() => _play('audio/stage3_intro.wav');

  // ------------------------------------------------------------------
  // Dokunma ve sonuc efektleri
  // ------------------------------------------------------------------

  /// Dogru sekle/hedefe dokunuldugunda.
  void playCorrect() => _play('audio/correct.mp3', volume: 0.9);

  /// Yanlis dokunus / hata.
  void playWrong() => _play('audio/wrong.mp3', volume: 0.9);

  /// Menulerde gezinirken (buton dokunusu).
  void playClick() => _play('audio/click.mp3', volume: 0.7);

  /// Bolum basariyla bitince.
  void playWin() => _play('audio/win.mp3');

  /// Bolum basarisiz bitince (sure doldu / hak bitti).
  void playLose() => _play('audio/lose.mp3');

  /// Saniye tiki: ayri bir ses dosyasi yok, sessiz.
  void playTick() {}

  /// Uygulama kapanirken kaynaklari birakir.
  Future<void> disposeAll() async {
    for (final p in _sfx.values) {
      await p.dispose();
    }
    _sfx.clear();
    await _music.dispose();
  }
}