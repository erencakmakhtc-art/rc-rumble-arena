import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/audio_manager.dart';
import '../data/mock_leaderboard.dart';
import '../data/pairs.dart';
import '../models/game_enums.dart';
import '../models/game_mode.dart';
import '../models/game_tile.dart';

/// Bir oyun turunda kac asama oldugu.
const int kStages = 3;

/// Her asamada bulunmasi gereken hedef sekil sayisi.
const int kTargetCount = 6;

/// Izgara boyutlari: 5 sutun x 6 satir = 30 hucre.
const int kGridCols = 5;
const int kGridRows = 6;

/// Yanlis dokunusun ekledigi ceza suresi (ms).
const int kWrongPenaltyMs = 500;

/// Bir asamada izin verilen en fazla sure (ms). Bu sure asilirsa asama
/// otomatik olarak 100 saniye uzerinden kapanir ve bir can kaybedilir.
const int kMaxStageMs = 100000;

/// 1. bolumu (Sekil Avi) gecmek icin gereken ortalama asama suresi.
/// Uc asamanin ortalamasi bu degerin altinda kalirsa diger bolumler acilir.
const int kUnlockAvgMs = 2200;

/// Gunluk ucretsiz oynama hakki.
const int kDailyPlayLimit = 4;

/// Odullu reklam izlenince kazanilan ek hak.
const int kAdRewardPlays = 3;

/// Sahte reklamin suresi (saniye).
const int kAdSeconds = 5;

/// Bir ligde kac oyuncu bulunur. Global rank 1..200 = "1. Lig",
/// 201..400 = "2. Lig", ... Kucuk sayi = daha ust lig (1. Lig en iyisi).
const int kPlayersPerLeague = 200;

/// true: bolumler sirayla acilir (bir oncekini gecmek gerekir) - harita modu.
/// false: butun bolumler bastan aciktir (test icin pratik).
const bool kSequentialUnlock = true;

/// Butun oyun durumunu ve kurallarini yoneten ana sinif.
///
/// NOT (veritabani): Bu surumde skor/siralama tamamen yerel/sahte (mock)
/// verilerle calisir - hicbir sunucu/veritabani cagrisi yapilmaz. Ileride
/// Firebase eklendiginde asagidaki noktalar degisecek:
///   - kullanici adi/ulke kaydi (signup) -> Firestore/Auth
///   - `best`, gunluk haklar -> kullaniciya bagli bulut/senkron veri
///   - `_startRank()` -> gercek bir sunucu sorgusu (su an sahte animasyon)
///   - kBoardSolo / kBoardCountry -> gercek liderlik tablosu sorgusu
class GameController extends ChangeNotifier {
  final Random _rng = Random();

  // ------------------------------------------------------------------
  // Uygulama duzeyi durum
  // ------------------------------------------------------------------
  AppScreen screen = AppScreen.signup;
  BoardTab boardTab = BoardTab.solo;

  /// Dunya siralamasinda hangi bolumun tablosu gosteriliyor.
  /// null = "Genel" (Sekil Avi sure bazli klasik tablo).
  GameMode? boardMode;
  String nick = '';
  String? cc;
  int logoIdx = 0;
  bool confirmQuitOpen = false;
  final Difficulty difficulty = Difficulty.normal;

  /// Su an secili olan bolum (mini bolum ekranlarinin hangisinin
  /// gosterilecegini belirler).
  GameMode activeMode = GameMode.shapeHunt;

  /// Oyuncunun "bunu bir daha gosterme" dedigi bolumler.
  /// NOT: su an sadece bellekte tutulur; kalici kayit Firebase/yerel
  /// depolama eklendiginde buraya baglanacak.
  final Set<GameMode> _skipIntro = <GameMode>{};

  /// Bolum bazinda oyuncunun en iyi SKORU (leaderboard icin).
  ///
  /// Her bolumun dogal olcusu farkli:
  ///  - Sure-tabanli (shapeHunt, oddOne, typing): en iyi = en KISA sure (ms).
  ///  - Puan-tabanli (whack sure, needle puan): whack en KISA sure (ms),
  ///    needle en YUKSEK puan.
  /// Karsilastirma yonu [_lowerIsBetter] ile belirlenir.
  final Map<GameMode, int> bestScore = <GameMode, int>{};

  /// Geriye uyumluluk icin eski ad (leaderboard bunu okuyordu).
  Map<GameMode, int> get bestPoints => bestScore;

  /// Sure tabanli bolumlerde dusuk skor (kisa sure), puan tabanli
  /// bolumlerde yuksek skor daha iyidir. Bolum tanimindaki scoreUnit'ten
  /// okunur; yeni bir bolum eklerken burayi degistirmek gerekmez.
  static bool lowerIsBetter(GameMode m) {
    return kGameModes[m]?.scoreUnit != 'puan';
  }

  // ------------------------------------------------------------------
  // Lig sistemi (bkz. widgets/league_badge.dart)
  // Her 200 kisi = 1 lig. 1. Lig en iyi 200 oyuncu, en son lig = yeni
  // kayit + hicbir sey oynamamis oyuncularin baslangic ligi.
  //
  // NOT (Firebase): su an lokal - overallPerformance -> lineer sira eslemesi.
  // Ileride sadece globalRank ve overallPerformance getter'lari sunucudan
  // beslenecek; UI hicbir sey degistirmeden calisir.
  // ------------------------------------------------------------------

  /// Her bolumun normalize hesabinda kullanilan (iyi_esik, kotu_esik) esleri.
  /// Sure bazli modda "iyi" = kucuk deger; puan bazli modda "iyi" = buyuk deger.
  static const Map<GameMode, (num, num)> _kBenchmarks = {
    GameMode.shapeHunt: (1600, 6000),    // ms (asama basina ortalama)
    GameMode.oddOne:    (10000, 18000),  // ms
    GameMode.typing:    (12000, 20000),  // ms
    GameMode.whack:     (45000, 120000), // ms
    GameMode.needle:    (1400, 300),     // puan
    GameMode.goNoGo:    (2800, 800),     // puan
    GameMode.bubble:     (4400, 1000),  // puan
    GameMode.numberHunt: (11000, 40000), // ms
    GameMode.colorTrap:  (4200, 1000),  // puan
    GameMode.arrowStorm: (5200, 1200),  // puan
    GameMode.fruitSlice: (2800, 600),   // puan
    GameMode.aimTarget: (12000, 30000), // ms
    GameMode.quickMath: (3000, 700),    // puan
    GameMode.ringTiming: (3800, 1000),  // puan
    GameMode.memoryCards: (15000, 60000), // ms
    GameMode.laneRunner: (1800, 300),   // puan
    GameMode.dotCount: (2800, 600),     // puan
    GameMode.basketCatch: (1800, 400),  // puan
    GameMode.cupShuffle: (1400, 200),   // puan
    GameMode.fingerDodge: (2600, 500),  // puan
    GameMode.keepUp: (1500, 200),       // puan
    GameMode.samuraiDuel: (215, 330),   // ms (ortalama tepki)
    GameMode.towerStack: (4200, 800),   // puan
    GameMode.bridgeBuilder: (2400, 400), // puan
    GameMode.poleBalance: (2800, 400),  // puan
    GameMode.tileRush: (1400, 200),     // puan
    GameMode.neonTunnel: (2800, 400),   // puan
    GameMode.mirrorTrap: (2600, 500),   // puan
    GameMode.echoSequence: (4700, 400), // puan
    GameMode.meteorDefense: (3000, 600), // puan
    GameMode.sortBelt: (4000, 800),     // puan
  };

  /// Tek bir bolumun en iyi skorunu 0..1 araligina normalize eder.
  double _normalizedScore(GameMode m) => normalizeScore(m, bestScore[m]);

  /// Verilen skoru 0..1 performansa cevirir (null / oynanmamis = 0).
  /// Sonuc kartindaki dunya sirasi da ayni formulu kullanir, boylece
  /// kart ile lig birbiriyle tutarli olur.
  static double normalizeScore(GameMode m, int? s) {
    if (s == null) return 0.0;
    final b = _kBenchmarks[m];
    if (b == null) return 0.0;
    final good = b.$1.toDouble();
    final bad = b.$2.toDouble();
    if (lowerIsBetter(m)) {
      if (s <= good) return 1.0;
      if (s >= bad) return 0.0;
      return 1.0 - (s - good) / (bad - good);
    } else {
      if (s >= good) return 1.0;
      if (s <= bad) return 0.0;
      return (s - bad) / (good - bad);
    }
  }

  /// Menudeki (oynanabilir) bolumlerin normalize skorlarinin ortalamasi (0..1).
  /// Oynanmayan bolum 0 sayilir - cok mod bitiren avantajli, tek modda
  /// ustun olan da yine puan alir. Yayindan kaldirilan bolumler (Git/Dur)
  /// ortalamaya girmez; aksi halde kimse %100'e ulasamazdi.
  double get overallPerformance {
    var sum = 0.0;
    for (final m in kModeOrder) {
      sum += _normalizedScore(m);
    }
    return sum / kModeOrder.length;
  }

  /// Oyuncunun kestirilen global sirasi (1 = en iyi, kTotalPlayers = en son).
  /// Hicbir sey oynanmamissa direkt son sira -> otomatik en son lig.
  int get globalRank {
    final p = overallPerformance;
    if (p <= 0) return kTotalPlayers;
    final r = 1 + ((1 - p) * (kTotalPlayers - 1)).round();
    return r.clamp(1, kTotalPlayers);
  }

  /// Oyuncunun bulundugu lig. 1. Lig en iyi, buyuk numaralar alt ligler.
  int get leagueTier {
    return ((globalRank - 1) ~/ kPlayersPerLeague) + 1;
  }

  /// Sistemdeki toplam lig sayisi (en alttaki ligin numarasi).
  int get totalLeagues {
    return ((kTotalPlayers - 1) ~/ kPlayersPerLeague) + 1;
  }

  /// Kademeli ilerleme: oyuncunun basariyla gectigi bolumler.
  /// Bir bolum gecilince menu sirasindaki bir sonraki bolumun kilidi acilir.
  /// Sekil Avi (ilk bolum) her zaman aciktir.
  final Set<GameMode> passedModes = <GameMode>{};

  /// Haritada "acilma animasyonu" gosterilmis bolum sayisi. Bir bolum gecilip
  /// haritaya donulunce yeni acilan dugum bununla karsilastirilip canlandirilir.
  int mapRevealed = 1;

  /// Bir bolumun basariyla gecildigini isaretler ve sonrakini acar.
  void markModePassed(GameMode m) {
    if (passedModes.add(m)) {
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------
  // Gunluk oynama hakki
  // ------------------------------------------------------------------

  /// Bugun kac kez oynandi.
  int _playsUsedToday = 0;

  /// Reklam izleyerek kazanilan ek haklar.
  int _bonusPlays = 0;

  /// Haklarin hangi gune ait oldugu (gun degisince sifirlanir).
  DateTime _playsDay = DateTime.now();

  /// Reklam teklifi modali acik mi.
  bool adOfferOpen = false;

  /// Reklam "izleniyor" mu (sahte reklam animasyonu).
  bool adPlaying = false;

  /// Sahte reklamda gecen saniye (0..kAdSeconds).
  int adProgress = 0;
  Timer? _adTimer;

  /// Gun degistiyse gunluk haklari sifirlar.
  void _rolloverIfNewDay() {
    final now = DateTime.now();
    final sameDay = now.year == _playsDay.year && now.month == _playsDay.month && now.day == _playsDay.day;
    if (!sameDay) {
      _playsDay = now;
      _playsUsedToday = 0;
      _bonusPlays = 0;
    }
  }

  /// Kalan oynama hakki.
  int get playsLeft {
    _rolloverIfNewDay();
    final left = kDailyPlayLimit + _bonusPlays - _playsUsedToday;
    return left < 0 ? 0 : left;
  }

  bool get hasPlaysLeft => playsLeft > 0;

  /// Bir oyun baslatilirken hak dusurur. Hak yoksa false doner.
  bool _consumePlay() {
    _rolloverIfNewDay();
    if (playsLeft <= 0) return false;
    _playsUsedToday += 1;
    return true;
  }

  /// Hak bitince reklam teklifini acar.
  void openAdOffer() {
    adOfferOpen = true;
    adPlaying = false;
    adProgress = 0;
    notifyListeners();
  }

  void closeAdOffer() {
    _adTimer?.cancel();
    adOfferOpen = false;
    adPlaying = false;
    adProgress = 0;
    notifyListeners();
  }

  /// Sahte reklam izleme akisi.
  ///
  /// NOT: Gercek bir reklam SDK'si (AdMob vb.) baglanmadi. Burasi yalnizca
  /// akisi ve odulu simule eder; gercek entegrasyonda bu fonksiyonun yerini
  /// "odullu reklam goster -> onUserEarnedReward" geri cagrisi alacak.
  /// Reklam odulu verildikten sonra kisa sureligine gosterilen bildirim.
  String? rewardNotice;
  Timer? _rewardNoticeTimer;

  void startAd() {
    if (adPlaying) return;
    adPlaying = true;
    adProgress = 0;
    notifyListeners();

    _adTimer?.cancel();
    _adTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      adProgress += 1;
      if (adProgress >= kAdSeconds) {
        t.cancel();
        _bonusPlays += kAdRewardPlays;
        adPlaying = false;
        adOfferOpen = false;
        adProgress = 0;

        // Kullaniciya odulun verildigini goster.
        rewardNotice = '+$kAdRewardPlays hak kazandın!';
        _rewardNoticeTimer?.cancel();
        _rewardNoticeTimer = Timer(const Duration(milliseconds: 2200), () {
          rewardNotice = null;
          notifyListeners();
        });
      }
      notifyListeners();
    });
  }

  /// Uygulama arka plana alindiginda cagrilir. Oyun ortasindaysa cikis
  /// onayini acarak oyunu fiilen duraklatir; boylece oyuncu geri
  /// dondugunde saniyeler islemis olmaz.
  void onAppBackgrounded() {
    if (screen == AppScreen.game && phase == GamePhase.play) {
      _cancelAll();
      confirmQuitOpen = true;
      notifyListeners();
    }
  }

  bool shouldSkipIntro(GameMode m) => _skipIntro.contains(m);

  void setSkipIntro(GameMode m, bool value) {
    if (value) {
      _skipIntro.add(m);
    } else {
      _skipIntro.remove(m);
    }
    notifyListeners();
  }

  /// Bir bolum bittiginde skoru ve (basariliysa) kilit ilerlemesini gunceller.
  /// [score] bolumun dogal olcusudur (sure ms ya da puan). [passed] bolumun
  /// gecme sartini saglayip saglamadigidir.
  void reportModeResult(GameMode m, int score, bool passed) {
    // Sure bazli bolumlerde yalnizca basarili tur rekor sayilir: erken elenen
    // oyuncunun kisa suresi (orn. 5 kostebek kacirip 12 sn'de biten tur)
    // siralamaya ve lige "en hizli" diye yazilmamali.
    final lower = lowerIsBetter(m);
    if (!lower || passed) {
      final prev = bestScore[m];
      final better = prev == null || (lower ? score < prev : score > prev);
      if (better) bestScore[m] = score;
    }
    if (passed) markModePassed(m);
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Aktif oyun turu durumu
  // ------------------------------------------------------------------
  GamePhase phase = GamePhase.idle;
  int stage = 1;
  int count = 3;
  List<GameTile> tiles = [];
  ShapePair? target;
  int found = 0;
  DateTime? startedAt;
  int elapsedMs = 0;
  int penaltyMs = 0;
  List<int> times = [];
  String? wrongId;
  String? banner;
  int? best;
  bool record = false;
  int _lastTickSecond = -1;

  /// Gecen sureyi 40ms'de bir yayinlayan dar kapsamli bildirici.
  ///
  /// Tick'te notifyListeners() cagirmak tum GameScreen agacini (gradyanli,
  /// golgeli onlarca Container) saniyede 25 kez yeniden kurardi. Bunun
  /// yerine sadece sureye bagli parcalar (sayac metni + ilerleme cubugu)
  /// bu notifier'i dinler; geri kalan agac yalnizca gercek durum
  /// degisikliklerinde (dokunma, asama gecisi) yeniden kurulur.
  final ValueNotifier<int> elapsedNotifier = ValueNotifier<int>(0);

  // ------------------------------------------------------------------
  // Dunya siralamasi (sahte) hesaplama durumu
  // ------------------------------------------------------------------
  RankPhase rankPhase = RankPhase.none;
  int rankStep = 0;
  int? rank;
  double pct = 0;

  Timer? _tickTimer;
  Timer? _announceTimer;
  Timer? _countTimer;
  Timer? _nextStageTimer;
  Timer? _wrongTimer;
  Timer? _rankStepTimer;
  Timer? _rankDoneTimer;
  Timer? _logoTimer;

  /// Ana menudeki logo/sekil ikonunun donusumlu animasyonunu baslatir.
  void startLogoCycle() {
    AudioManager.instance.playMenuMusic();
    _logoTimer?.cancel();
    // Logo yalnizca ana menude gorunur (home_screen). Bu yuzden timer sadece
    // orada is yapmali: aksi halde hassas reaksiyon olcen bir mini bolumun
    // ortasinda bile 1.4 sn'de bir notifyListeners() tetiklenip tum AppRoot
    // agaci (arka plan gorseli, gradyanlar, Stack) bosuna yeniden kurulur.
    _logoTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (screen != AppScreen.home) return;
      logoIdx = (logoIdx + 1) % 1000;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _cancelAll();
    _logoTimer?.cancel();
    _adTimer?.cancel();
    _rewardNoticeTimer?.cancel();
    elapsedNotifier.dispose();
    super.dispose();
  }

  void _cancelAll() {
    _tickTimer?.cancel();
    _announceTimer?.cancel();
    _countTimer?.cancel();
    _nextStageTimer?.cancel();
    _wrongTimer?.cancel();
    _rankStepTimer?.cancel();
    _rankDoneTimer?.cancel();
  }

  // ------------------------------------------------------------------
  // Kayit (signup) ekrani
  // ------------------------------------------------------------------

  void setNick(String value) {
    var v = value.replaceAll(RegExp(r'\s'), '_');
    if (v.length > 14) v = v.substring(0, 14);
    nick = v;
    notifyListeners();
  }

  void setCountry(String code) {
    cc = code;
    notifyListeners();
  }

  bool get canSignup => nick.trim().length >= 2 && cc != null;

  /// Kullanicinin sisteme kacinci sirada kayit oldugu.
  /// NOT: gercek bir backend olmadigi icin simdilik sahte/yerel bir sayi
  /// uretilir. Firebase eklendiginde bu deger kayit aninda sunucudan gelen
  /// gercek sira ile degistirilecek.
  int? signupRank;

  void completeSignup() {
    if (!canSignup) return;
    // Sahte kayit sirasi: mevcut oyuncu sayisinin biraz uzerinde bir yer.
    signupRank ??= 1284309 + 1 + Random().nextInt(9000);
    screen = AppScreen.home;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Genel navigasyon
  // ------------------------------------------------------------------

  void goHome() {
    _cancelAll();
    screen = AppScreen.home;
    phase = GamePhase.idle;
    confirmQuitOpen = false;
    AudioManager.instance.playMenuMusic();
    notifyListeners();
  }

  void openBoard() {
    screen = AppScreen.board;
    notifyListeners();
  }

  /// "Oyuna basla" -> bolum secim listesi.
  void openModes() {
    _cancelAll();
    phase = GamePhase.idle;
    screen = AppScreen.modes;
    AudioManager.instance.playMenuMusic();
    notifyListeners();
  }

  /// Bir bolum, oynanabilir durumda mi (Sekil Avi her zaman acik;
  /// digerleri 1. bolum ort. 2.20 sn altinda bitirilince acilir).
  /// Bir bolum oynanabilir mi? Kademeli kilit:
  ///  - Sekil Avi her zaman acik.
  ///  - Diger her bolum, menu sirasinda kendinden onceki bolum basariyla
  ///    gecilince acilir.
  bool isModeUnlocked(GameMode mode) {
    if (!kSequentialUnlock) return true;
    final idx = kModeOrder.indexOf(mode);
    if (idx <= 0) return true; // Sekil Avi (ya da listede yoksa)
    final prev = kModeOrder[idx - 1];
    return passedModes.contains(prev);
  }

  /// Bolum listesinden bir bolum secildiginde.
  void openMode(GameMode mode) {
    AudioManager.instance.playClick();
    if (!isModeUnlocked(mode)) {
      // Kilitli: kisa bir uyari goster, bolumu acma.
      lockedNoticeMode = mode;
      notifyListeners();
      return;
    }
    // Gunluk hak kontrolu: hak yoksa reklam teklifi acilir, bolum baslamaz.
    if (!_consumePlay()) {
      openAdOffer();
      return;
    }
    activeMode = mode;
    if (mode == GameMode.shapeHunt) {
      // Sekil Avi kendi tam akisina (asama/sonuc) sahip.
      _startShapeHuntRun();
      return;
    }
    _cancelAll();
    phase = GamePhase.idle;
    screen = AppScreen.mini;
    AudioManager.instance.stopMenuMusic();
    notifyListeners();
  }

  /// Kilitli bir bolume dokununca gosterilecek uyarinin hedefi (null = yok).
  GameMode? lockedNoticeMode;

  /// Mini bolumlerdeki "Tekrar oyna" icin: hak varsa dusurur ve true doner,
  /// yoksa reklam teklifini acip false doner.
  bool tryConsumePlayForRetry() {
    if (_consumePlay()) return true;
    openAdOffer();
    return false;
  }

  void dismissLockedNotice() {
    lockedNoticeMode = null;
    notifyListeners();
  }

  /// Bir mini bolumden bolum listesine donus.
  void backToModes() {
    _cancelAll();
    phase = GamePhase.idle;
    confirmQuitOpen = false;
    screen = AppScreen.modes;
    AudioManager.instance.playMenuMusic();
    notifyListeners();
  }

  void setBoardTab(BoardTab tab) {
    boardTab = tab;
    notifyListeners();
  }

  /// Siralama ekranindaki bolum filtresi (null = Genel).
  void setBoardMode(GameMode? m) {
    boardMode = m;
    notifyListeners();
  }

  void askQuit() {
    confirmQuitOpen = true;
    notifyListeners();
  }

  void cancelQuit() {
    confirmQuitOpen = false;
    notifyListeners();
  }

  void confirmQuit() {
    confirmQuitOpen = false;
    // Oyuna bolum listesinden girildigi icin cikista oraya donmek dogal olani.
    backToModes();
  }

  // ------------------------------------------------------------------
  // (Eski can/magaza sistemi kaldirildi.)
  //
  // Onceden can satin alinan sahte bir magaza vardi; yerini "gunluk 4 hak +
  // odullu reklamla 3 hak" sistemi aldi. Gercek bir IAP eklenecekse
  // AdOfferDialog'un yanina bir satin alma secenegi konulabilir.
  // ------------------------------------------------------------------

  // ------------------------------------------------------------------
  // Oyun akisi
  // ------------------------------------------------------------------

  List<ShapePair> _diffPool() => pairsForDifficulty(difficulty);

  /// Sekil Avi turunu baslatir. Hak dusurme isi cagiran tarafta
  /// (openMode / restart) yapilir, burada tekrar dusurulmez.
  void _startShapeHuntRun() {
    screen = AppScreen.game;
    times = [];
    stage = 1;
    rankPhase = RankPhase.none;
    rank = null;
    pct = 0;
    // Tanitim: "bir daha gosterme" secilmediyse once nasil oynanir karti.
    if (!shouldSkipIntro(GameMode.shapeHunt)) {
      phase = GamePhase.intro;
      AudioManager.instance.stopMenuMusic();
      notifyListeners();
      return;
    }
    AudioManager.instance.stopMenuMusic();
    _beginStage(1);
  }

  /// Sekil Avi tanitim kartindaki "Anladim".
  void confirmShapeHuntIntro() {
    if (phase != GamePhase.intro) return;
    _beginStage(1);
  }

  /// Sonuc ekranindaki "Tekrar oyna". Yeni bir tur oldugu icin hak dusurur.
  void restart() {
    _rankStepTimer?.cancel();
    _rankDoneTimer?.cancel();
    if (!_consumePlay()) {
      openAdOffer();
      return;
    }
    times = [];
    stage = 1;
    rankPhase = RankPhase.none;
    rank = null;
    pct = 0;
    AudioManager.instance.stopMenuMusic();
    _beginStage(1);
  }

  List<ShapePair> _shuffled(List<ShapePair> list) {
    final r = List<ShapePair>.from(list);
    for (var i = r.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final tmp = r[i];
      r[i] = r[j];
      r[j] = tmp;
    }
    return r;
  }

  /// [kTargetCount] adet hedefi, hicbiri birbirine komsu olmayacak sekilde
  /// (yatay/dikey yan yana degil) rastgele yerlestirir.
  ///
  /// Komsu hedefler oyunu cok kolaylastiriyordu: goz bir tanesini bulunca
  /// yanindakini de aninda goruyordu. Caprazlar serbest birakildi, aksi
  /// halde 5x6'lik izgarada 6 hedefi yerlestirmek cogu zaman imkansiz olur.
  List<int> _pickSpreadTargetCells() {
    final total = kGridCols * kGridRows;

    bool adjacent(int a, int b) {
      final ra = a ~/ kGridCols, ca = a % kGridCols;
      final rb = b ~/ kGridCols, cb = b % kGridCols;
      final dr = (ra - rb).abs(), dc = (ca - cb).abs();
      return (dr + dc) == 1; // sadece yatay/dikey komsuluk
    }

    // Birkac kez dene; komsuluk kisiti yuzunden sikisirsa bastan basla.
    for (var attempt = 0; attempt < 60; attempt++) {
      final chosen = <int>[];
      final candidates = List<int>.generate(total, (i) => i)..shuffle(_rng);
      for (final c in candidates) {
        if (chosen.length >= kTargetCount) break;
        if (chosen.every((x) => !adjacent(x, c))) chosen.add(c);
      }
      if (chosen.length == kTargetCount) return chosen;
    }

    // Guvenlik agi: kisit saglanamadiysa duz rastgele yerlestir.
    final fallback = List<int>.generate(total, (i) => i)..shuffle(_rng);
    return fallback.take(kTargetCount).toList();
  }

  void _beginStage(int s) {
    _cancelAll();

    // Yeni hedef sec (onceki asamanin hedefinden farkli olsun).
    final pool = _diffPool();
    final picks = pool.where((p) => p != target).toList();
    final newTarget = picks[_rng.nextInt(picks.length)];
    final others = pool.where((p) => p != newTarget).toList();

    // Once hedef hucrelerini komsu olmayacak sekilde sec, sonra kalan
    // hucreleri diger ciftlerle doldur.
    final targetCells = _pickSpreadTargetCells().toSet();
    final total = kGridCols * kGridRows;
    final newTiles = <GameTile>[
      for (var i = 0; i < total; i++)
        GameTile(
          id: 's$i',
          pair: targetCells.contains(i) ? newTarget : others[_rng.nextInt(others.length)],
        ),
    ];

    stage = s;
    phase = GamePhase.announce;
    count = 3;
    elapsedMs = 0;
    elapsedNotifier.value = 0;
    penaltyMs = 0;
    found = 0;
    tiles = newTiles;
    target = newTarget;
    wrongId = null;
    banner = null;
    if (s == 1) {
      AudioManager.instance.playReady();
    } else if (s == 2) {
      AudioManager.instance.playStage2Intro();
    } else if (s == 3) {
      AudioManager.instance.playStage3Intro();
    }
    notifyListeners();

    _announceTimer = Timer(const Duration(milliseconds: 1500), () => _runCount(3));
  }

  void _runCount(int n) {
    if (n == 0) {
      _go();
      return;
    }
    phase = GamePhase.count;
    count = n;
    AudioManager.instance.playCount(n);
    notifyListeners();
    _countTimer = Timer(const Duration(milliseconds: 1000), () => _runCount(n - 1));
  }

  void _go() {
    phase = GamePhase.play;
    startedAt = DateTime.now();
    elapsedMs = 0;
    elapsedNotifier.value = 0;
    _lastTickSecond = -1;
    AudioManager.instance.playGo();
    notifyListeners();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      // Oyun fazi disina cikildiysa timer kendini sonlandirsin; aksi halde
      // sonuc ekranindayken arka planda calismaya devam edip beklenmedik
      // durum degisiklikleri (kendi kendine ilerleme) yaratabiliyor.
      if (phase != GamePhase.play) {
        t.cancel();
        return;
      }
      elapsedMs = DateTime.now().difference(startedAt!).inMilliseconds;
      if (elapsedMs + penaltyMs >= kMaxStageMs) {
        _timeUp();
        return;
      }
      final sec = elapsedMs ~/ 1000;
      if (sec > 0 && sec != _lastTickSecond) {
        _lastTickSecond = sec;
        AudioManager.instance.playTick();
      }
      // Dar kapsamli guncelleme: yalnizca sureye bagli widget'lar yenilenir.
      elapsedNotifier.value = elapsedMs;
    });
  }

  /// Asama suresi 100 saniyeyi asinca cagrilir: bir can yanar, asama
  /// skora tam 100 saniye olarak yazilir ve normal akista devam edilir.
  void _timeUp() {
    _tickTimer?.cancel();
    _completeStage(kMaxStageMs);
  }

  /// Bir hucreye dokunuldugunda cagrilir.
  void tap(GameTile tile) {
    if (phase != GamePhase.play || tile.cleared) return;

    if (tile.pair == target) {
      tile.cleared = true;
      found += 1;
      AudioManager.instance.playCorrect();
      notifyListeners();

      if (found < kTargetCount) return;

      // Asama tamamlandi.
      _tickTimer?.cancel();
      final ms = DateTime.now().difference(startedAt!).inMilliseconds + penaltyMs;
      _completeStage(ms);
    } else {
      wrongId = tile.id;
      penaltyMs += kWrongPenaltyMs;
      AudioManager.instance.playWrong();
      notifyListeners();
      _wrongTimer = Timer(const Duration(milliseconds: 420), () {
        wrongId = null;
        notifyListeners();
      });
    }
  }

  /// Bir asamayi (normal tamamlanma ya da zaman asimi ile) kapatir,
  /// skoru kaydeder ve bir sonraki asamaya / sonuc ekranina gecer.
  void _completeStage(int ms) {
    // Bu asamaya ait butun zamanlayicilari garantiye al: ozellikle 40ms'lik
    // periodic tick timer sonuc ekranindayken hayatta kalirsa oyun kendi
    // kendine ilerliyormus gibi gorunebiliyordu.
    _tickTimer?.cancel();
    _announceTimer?.cancel();
    _countTimer?.cancel();
    _wrongTimer?.cancel();

    times = List<int>.from(times)..add(ms);
    final isRecord = best != null && ms < best!;
    best = best == null ? ms : min(best!, ms);
    record = isRecord;
    final last = stage >= kStages;
    elapsedMs = ms;
    elapsedNotifier.value = ms;

    if (last) {
      phase = GamePhase.final_;
      banner = null;
    } else {
      phase = GamePhase.done;
      banner = (record ? 'Yeni rekor! ' : '') + '${(ms / 1000).toStringAsFixed(2)} sn';
    }
    notifyListeners();

    if (!last) {
      _nextStageTimer = Timer(const Duration(milliseconds: 1400), () => _beginStage(stage + 1));
    } else {
      final avg = times.reduce((a, b) => a + b) / times.length;
      // Ortalama 2.20 sn altindaysa Sekil Avi gecilmis sayilir.
      // Skor (asama basina ortalama ms) rekor, siralama ve lig icin kaydedilir.
      final passedRun = avg < kUnlockAvgMs;
      reportModeResult(GameMode.shapeHunt, avg.round(), passedRun);
      if (passedRun) {
        AudioManager.instance.playWin();
      } else {
        AudioManager.instance.playLose();
      }
      _startRank(avg);
    }
  }

  /// Sahte dunya siralamasi hesaplama animasyonu (gercek sunucu cagrisi yok).
  void _startRank(double avgMs) {
    const total = kTotalPlayers;
    final p = max(0.004, min(0.97, (avgMs - 2200) / 8000));
    final r = max(6, (p * total).round());

    rankPhase = RankPhase.calc;
    rankStep = 0;
    notifyListeners();

    _rankStepTimer = Timer.periodic(const Duration(milliseconds: 780), (_) {
      rankStep += 1;
      notifyListeners();
    });

    _rankDoneTimer = Timer(const Duration(milliseconds: 2500), () {
      _rankStepTimer?.cancel();
      rankPhase = RankPhase.done;
      rank = r;
      pct = p;
      notifyListeners();
    });
  }

  // ------------------------------------------------------------------
  // Sunum katmani icin yardimci getter'lar
  // ------------------------------------------------------------------

  bool get isLive => phase == GamePhase.play;

  bool get isReveal => isLive || phase == GamePhase.done || phase == GamePhase.final_;
}
