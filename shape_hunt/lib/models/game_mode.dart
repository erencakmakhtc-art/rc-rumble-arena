import 'package:flutter/material.dart';

/// Uygulamadaki oynanabilir bolumler.
enum GameMode {
  shapeHunt,
  oddOne,
  goNoGo,
  whack,
  typing,
  needle,
  bubble,
  numberHunt,
  colorTrap,
  arrowStorm,
  fruitSlice,
  aimTarget,
  quickMath,
  ringTiming,
  memoryCards,
  laneRunner,
  dotCount,
  basketCatch,
  cupShuffle,
  fingerDodge,
  keepUp,
  samuraiDuel,
  towerStack,
  bridgeBuilder,
  poleBalance,
  tileRush,
  neonTunnel,
  mirrorTrap,
  echoSequence,
  meteorDefense,
  sortBelt,
}

/// Bir bolumun menude ve oyun ici baslikta kullanilan tanitim bilgileri.
class GameModeDef {
  final String title;
  final String tagline;
  final String howTo;

  /// Tanitim kartinda gosterilen puanlama kurallari.
  final List<String> scoring;

  final List<Color> accent;
  final Color depth;
  final Color ink;

  /// Basarisiz oldugunda ust baslikta gosterilecek kisa metin.
  /// (Orn. "HEDEF TUTTURULAMADI", "SURE DOLDU".)
  final String failLabel;

  /// Basarisiz oldugunda kullaniciya hedefi hatirlatan cumle.
  /// (Orn. "Ortalaman 2.20 sn altinda olmali".)
  final String failHint;

  /// Ana sayinin birimi: 'sn' (sure bazli) veya 'puan' (puan bazli).
  final String scoreUnit;

  const GameModeDef({
    required this.title,
    required this.tagline,
    required this.howTo,
    required this.scoring,
    required this.accent,
    required this.depth,
    required this.ink,
    required this.failLabel,
    required this.failHint,
    this.scoreUnit = 'sn',
  });
}

/// Bolum tanimlari. Renkler uygulamanin mevcut seker/parlak paletiyle uyumlu
/// secildi; her bolum kendi tonunu tasir ama ayni gorsel dili korur.
const Map<GameMode, GameModeDef> kGameModes = {
  GameMode.shapeHunt: GameModeDef(
    title: 'Şekil Avı',
    tagline: '3 aşama · her aşamada 6 işaret',
    howTo: 'Hedef şeklin 6 kopyasını ızgarada bul.',
    scoring: [
      'Her aşama: kalan süreye göre puan',
      'Yanlış dokunuş 500ms ceza ekler',
      'Yeni rekor kırarsan ekstra rozet',
    ],
    accent: [Color(0xFFE4FFD9), Color(0xFFA8E86A)],
    depth: Color(0xFF5FA22A),
    ink: Color(0xFF356810),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: 'Ortalaman 2.20 sn altında olmalı',
    scoreUnit: 'sn',
  ),
  GameMode.oddOne: GameModeDef(
    title: 'Farklı Olanı Bul',
    tagline: '12 tur · 18 saniye',
    howTo:
        'Aynı görünen şekiller arasından farklı olanı seç. 18 saniyede 12 turu bitir. Yanlış seçim 0,5 sn ceza.',
    scoring: [
      '12 turu 18 saniyeden önce bitir',
      'Yanlış seçim 0,5 sn ceza ekler',
      'En kısa sürede bitirmek rekordur',
    ],
    accent: [Color(0xFFFFE6F3), Color(0xFFFF9CCB)],
    depth: Color(0xFFC94F8E),
    ink: Color(0xFF8A2E5C),
    failLabel: 'SÜRE DOLDU',
    failHint: '18 saniyede 12 turu bitirmelisin',
    scoreUnit: 'sn',
  ),
  GameMode.goNoGo: GameModeDef(
    title: 'Git / Dur',
    tagline: '16 deneme · dürtünü tut',
    howTo: 'Yeşil gelince anında dokun, kırmızı gelince sakın dokunma.',
    scoring: [
      'Zamanında dokunma 100 puan + hız bonusu (300ms altı çift puan)',
      'Kırmızıda durmak 60 puan',
      'Erken dokunma ve yanlış alarm 80 puan götürür',
    ],
    accent: [Color(0xFFDDF4FF), Color(0xFF7FC9F5)],
    depth: Color(0xFF2E7FAD),
    ink: Color(0xFF14567A),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: 'Daha hızlı ve dikkatli olmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.whack: GameModeDef(
    title: 'Köstebek Avı',
    tagline: '7000 puana ulaş · süreye karşı',
    howTo:
        'Deliklerden çıkan köstebekleri kaybolmadan yakala. 7000 puana en kısa sürede ulaş; sona doğru hızlanır, bazen iki köstebek birden çıkar.',
    scoring: [
      'Her köstebek 50 puan, hızlı vurursan +40\'a kadar bonus',
      'Combo: 5 art arda +100, 10 art arda +300',
      'Boşa vuruş 20 puan götürür · 7000\'e en kısa sürede ulaş',
    ],
    accent: [Color(0xFFFFEAC7), Color(0xFFFFB454)],
    depth: Color(0xFFC77A18),
    ink: Color(0xFF7A3F00),
    failLabel: 'HEDEFE ULAŞILAMADI',
    failHint: '5\'ten az köstebek kaçırmalısın',
    scoreUnit: 'sn',
  ),
  GameMode.typing: GameModeDef(
    title: 'Hızlı Klavye',
    tagline: '8 satırlık hikaye · 20 saniye',
    howTo:
        'Ekrandaki hikayeyi satır satır yaz ve her satırda enter\'a bas. 8 satırı 20 saniyede bitir.',
    scoring: [
      '8 satırı 20 saniyede bitir',
      'Her oyunda rastgele bir hikaye gelir',
      'En kısa sürede bitirmek rekordur',
    ],
    accent: [Color(0xFFE9E4FF), Color(0xFFAFA0F0)],
    depth: Color(0xFF6A5AC0),
    ink: Color(0xFF3F3580),
    failLabel: 'SÜRE DOLDU',
    failHint: '8 satırı 20 saniyede bitirmelisin',
    scoreUnit: 'sn',
  ),
  GameMode.needle: GameModeDef(
    title: 'İbreyi Durdur',
    tagline: '12 tur · hızlı ve isabetli',
    howTo:
        'Gidip gelen ibreyi yeşil bölgenin tam ortasında durdur. En kısa sürede en yüksek puan önemli.',
    scoring: [
      'Yeşil bölge: merkeze yakınlığa göre 40-100 puan',
      'Tam ortada durdurursan +75 tam isabet bonusu',
      'Üst üste isabet: her turda artan combo bonusu',
    ],
    accent: [Color(0xFFD9FBF0), Color(0xFF6FD8B8)],
    depth: Color(0xFF2E9877),
    ink: Color(0xFF13624A),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: 'En fazla 1 kez ıskalayabilirsin',
    scoreUnit: 'puan',
  ),
  GameMode.bubble: GameModeDef(
    title: 'Baloncuk Patlat',
    tagline: '20 saniye · balinanın baloncukları',
    howTo:
        'Minik balina durmadan baloncuk üflüyor. Kaçmadan patlat! Dikenli baloncuklara sakın dokunma.',
    scoring: [
      'Baloncuk 50 puan, erken patlatırsan +30\'a kadar bonus',
      'Küçük baloncuk 80, altın baloncuk 150 puan · her 10\'lu seri bonus',
      'Dikenli baloncuk −150 · boşa dokunuş −10',
    ],
    accent: [Color(0xFFD8F7FF), Color(0xFF5CC6EE)],
    depth: Color(0xFF1F86B3),
    ink: Color(0xFF0B4F6E),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '20 saniyede 3600 puana ulaşmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.numberHunt: GameModeDef(
    title: 'Sayı Avı',
    tagline: '1’den 25’e · her 5 sayıda karışır',
    howTo:
        'Sayılara 1’den 25’e kadar sırayla dokun. Her 5 sayıda bir bütün tahta karışır, sayıların boyu ve rengi değişir.',
    scoring: [
      '25 sayıyı 18 saniyenin altında bitir',
      'Her 5 sayıda tahta baştan karışır · bulunanlar soluk kalır',
      'Yanlış dokunuş +1 sn ceza · 3 yanlışta elenirsin',
    ],
    accent: [Color(0xFFFFF7CC), Color(0xFFF5D547)],
    depth: Color(0xFFB8961A),
    ink: Color(0xFF6B5200),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '25 sayıyı 18 sn altında, 3’ten az hatayla bitirmelisin',
    scoreUnit: 'sn',
  ),
  GameMode.colorTrap: GameModeDef(
    title: 'Renk Tuzağı',
    tagline: '20 saniye · gözüne değil kurala güven',
    howTo:
        'Kural RENGİNE BAS diyorsa kelimenin boyasını, ANLAMINA BAS diyorsa ne yazdığını seç. Butonlarda sadece YAZIYA bak, boyasına kanma!',
    scoring: [
      'Doğru cevap 100 puan, 0,8 sn altında +60’a kadar hız bonusu',
      'Her 5’li seride artan bonus · kural her an değişebilir',
      'Yanlış −150, geç kalma −100 · 3 hatada elenirsin',
    ],
    accent: [Color(0xFFFFE3E0), Color(0xFFFF8F80)],
    depth: Color(0xFFD1503F),
    ink: Color(0xFF7E2418),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '3 hata yapmadan 3000 puana ulaşmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.arrowStorm: GameModeDef(
    title: 'Ok Fırtınası',
    tagline: '20 saniye · ortadaki oka odaklan',
    howTo:
        'Ortadaki ok hangi yöne bakıyorsa ekranı o yöne kaydır. Yandaki oklar seni yanıltır. Ortadaki ok KIRMIZI ise TERS yöne kaydır!',
    scoring: [
      'Doğru kaydırma 100 puan, 0,65 sn altında +60’a kadar bonus',
      'Kırmızı orta ok = ters yön · yan okların rengi önemsiz',
      'Yanlış −150, geç kalma −100 · 3 hatada elenirsin',
    ],
    accent: [Color(0xFFDCE6FF), Color(0xFF6C8CF5)],
    depth: Color(0xFF3656C4),
    ink: Color(0xFF1C2F7A),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '3 hata yapmadan 3800 puana ulaşmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.fruitSlice: GameModeDef(
    title: 'Meyve Kesici',
    tagline: '20 saniye · bombaya dokunma',
    howTo:
        'Havaya fırlayan meyveleri parmağını kaydırarak kes. Tek bir bombaya dokunursan oyun anında biter!',
    scoring: [
      'Meyve 40–80, altın yıldız 150 puan · her 10’lu seride +100',
      'Tek hamlede 3 ve üzeri meyve kesersen kombo bonusu',
      'Bombayı kesersen anında elenirsin',
    ],
    accent: [Color(0xFFFFE0EC), Color(0xFFFF7AA8)],
    depth: Color(0xFFD13F74),
    ink: Color(0xFF7A1840),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: 'Bombaya dokunmadan 2200 puana ulaşmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.aimTarget: GameModeDef(
    title: 'Hedef Tahtası',
    tagline: '30 hedef · küçülür ve kaçar',
    howTo:
        'Beliren hedeflere olabildiğince hızlı dokun. Hedefler küçülür ve kaybolur. Gri çarpılı sahte hedeflere dokunma!',
    scoring: [
      '30 hedefi 16 saniyenin altında vur',
      'Kaçan ya da sahte hedef +1 sn ceza · boş dokunuş +0,3 sn',
      '3 hatada (kaçan + sahte) elenirsin',
    ],
    accent: [Color(0xFFFFE5E5), Color(0xFFFF7B7B)],
    depth: Color(0xFFC62828),
    ink: Color(0xFF6E1414),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '30 hedefi 16 sn altında, 3’ten az hatayla vurmalısın',
    scoreUnit: 'sn',
  ),
  GameMode.quickMath: GameModeDef(
    title: 'Hızlı Hesap',
    tagline: '20 saniye · işlem önceliğine dikkat',
    howTo:
        'Ekrandaki işlemin sonucu doğru mu yanlış mı? Hızla karar ver. Butonların yeri bazen değişir!',
    scoring: [
      'Doğru cevap 100, 1,1 sn altında +60’a kadar bonus',
      'Yanlış sonuçlar hep çok yakındır · çarpma önce yapılır',
      'Yanlış −150, geç kalma −100 · 3 hatada elenirsin',
    ],
    accent: [Color(0xFFE6F7FF), Color(0xFF5FB3E8)],
    depth: Color(0xFF1F78B3),
    ink: Color(0xFF0B3F63),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '3 hata yapmadan 2200 puana ulaşmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.ringTiming: GameModeDef(
    title: 'Halka Zamanı',
    tagline: '20 saniye · milisaniyelik zamanlama',
    howTo:
        'Dış halka daralıp çembere tam oturduğu an dokun. Erken ya da geç dokunmak puan kaybettirir.',
    scoring: [
      '±45 ms Mükemmel 100 · ±100 ms İyi 60 · ±170 ms Tamam 30',
      'Her 10’lu seride +100 · sonlara doğru aynı anda iki hedef',
      'Kaçırmak ya da çok erken dokunmak ıska · 3 ıskada elenirsin',
    ],
    accent: [Color(0xFFE0E3FF), Color(0xFF8C92E6)],
    depth: Color(0xFF3F4478),
    ink: Color(0xFF23264F),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '3 kez ıskalamadan 3300 puana ulaşmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.memoryCards: GameModeDef(
    title: 'Hafıza Kartları',
    tagline: '10 çift · kartlar yer değiştirir',
    howTo:
        'Kartları ikişer ikişer çevir ve eşlerini bul. Şekiller ve renkler birbirine çok benzer. Her 4 yanlışta iki kart yer değiştirir!',
    scoring: [
      '10 çifti 21 saniyenin altında bul',
      'Her 4 yanlış eşleşmede 2 kapalı kart yer değiştirir',
      'Hızlı dokunarak açık kartları beklemeden kapatabilirsin',
    ],
    accent: [Color(0xFFEDE7FF), Color(0xFF9C8BF0)],
    depth: Color(0xFF5A48C4),
    ink: Color(0xFF2E2266),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '10 çifti 21 sn altında bulmalısın',
    scoreUnit: 'sn',
  ),
  GameMode.laneRunner: GameModeDef(
    title: 'Şerit Koşusu',
    tagline: '20 saniye · tek çarpma yeter',
    howTo:
        'Ekranın soluna dokun sola, sağına dokun sağa geç. Engellerden kaç, yıldızları topla. Tek çarpışmada oyun biter!',
    scoring: [
      'Yıldız başına 100 puan',
      'Hız sürekli artar · çift engeller tek boşluk bırakır',
      'Engele çarparsan anında elenirsin',
    ],
    accent: [Color(0xFFFFF0D9), Color(0xFFFFB35C)],
    depth: Color(0xFFC9731A),
    ink: Color(0xFF6B3A00),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: 'Çarpmadan 1300 puan toplamalısın',
    scoreUnit: 'puan',
  ),
  GameMode.dotCount: GameModeDef(
    title: 'Göz Kararı',
    tagline: '20 saniye · bir anlık bakış',
    howTo:
        'Noktalar bir an görünüp kaybolur. Kaç nokta olduğunu seç. İki renk de sayılır, gri kareler sayılmaz!',
    scoring: [
      'Doğru cevap 100, 1,1 sn altında +60’a kadar bonus',
      'Görünme süresi 0,45 sn’den 0,25 sn’ye iner',
      'Yanlış −150, geç kalma −100 · 3 hatada elenirsin',
    ],
    accent: [Color(0xFFFFF4E0), Color(0xFFF2B65A)],
    depth: Color(0xFFB57A1C),
    ink: Color(0xFF5E3C00),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '3 hata yapmadan 2000 puana ulaşmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.basketCatch: GameModeDef(
    title: 'Kova Yakala',
    tagline: '20 saniye · çürüğe dikkat',
    howTo:
        'Sepeti parmağınla sağa sola sürükle. Meyveleri yakala; taşlardan ve çürük elmalardan uzak dur.',
    scoring: [
      'Meyve 50, kivi 80, altın yıldız 150 · her 10’lu seride +100',
      'Taş ya da çürük elma −150 · kaçan meyve seriyi bozar',
      '3 kötü şey yakalarsan elenirsin',
    ],
    accent: [Color(0xFFE3F4FF), Color(0xFF6FC0F0)],
    depth: Color(0xFF2A7DB0),
    ink: Color(0xFF0E4467),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '3 hata yapmadan 1400 puana ulaşmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.cupShuffle: GameModeDef(
    title: 'Bardak Oyunu',
    tagline: '8 tur · gözünü ayırma',
    howTo:
        'Top bir bardağın altına girer, bardaklar karışır. Karıştırma bitince topun olduğu bardağa dokun.',
    scoring: [
      'Doğru bardak 100 puan, hızlı seçimde +50’ye kadar',
      'Her tur daha hızlı · ikili ve sahte hamleler gelir',
      'İkinci yanlışta elenirsin (tek hata hakkın var)',
    ],
    accent: [Color(0xFFDDF5E6), Color(0xFF6FBF8E)],
    depth: Color(0xFF2F7A52),
    ink: Color(0xFF14432A),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '8 turu en fazla 1 hatayla bitirmelisin',
    scoreUnit: 'puan',
  ),
  GameMode.fingerDodge: GameModeDef(
    title: 'Kaçış Parmağı',
    tagline: '20 saniye · parmağını kaldırma',
    howTo:
        'Parmağını ekrana koy ve 20 saniye boyunca kaldırmadan toplardan kaç. Mor gözlü toplar seni takip eder!',
    scoring: [
      'Hayatta kaldığın her saniye 100 puan',
      'Kıl payı kaçış +50 · her 2,5 saniyede yeni top',
      'Top değerse ya da parmağını kaldırırsan elenirsin',
    ],
    accent: [Color(0xFFF1EAFF), Color(0xFFB39AF2)],
    depth: Color(0xFF6A3FD0),
    ink: Color(0xFF3A1F80),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '20 saniye boyunca hiç dokunulmadan kalmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.keepUp: GameModeDef(
    title: 'Havada Tut',
    tagline: '20 saniye · 4 top',
    howTo:
        'Düşen toplara dokunarak yukarı sektir. Hiçbiri yere değmemeli! Topun kenarına dokunursan ters yöne gider.',
    scoring: [
      'Her sektirme 20 puan · yere yakın kurtarış +60',
      'Yeni toplar 4., 9. ve 14. saniyede gelir',
      'Tek bir top yere düşerse elenirsin',
    ],
    accent: [Color(0xFFFFEFE0), Color(0xFFFF9E5E)],
    depth: Color(0xFFD1612A),
    ink: Color(0xFF6E2A06),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '20 saniye boyunca hiçbir topu düşürmemelisin',
    scoreUnit: 'puan',
  ),
  GameMode.samuraiDuel: GameModeDef(
    title: 'Samuray Düellosu',
    tagline: '7 düello · kılıç çekme anı',
    howTo:
        'Kırmızı ! göründüğü an ekrana dokun ve rakipten önce kılıcını çek. Gri ! ya da ? sahtedir, erken davranırsan kaybedersin!',
    scoring: [
      'Rakip her düelloda hızlanır: 350 ms’den 252 ms’ye',
      'Gri !, soru işareti ve uçan kuş tuzaktır',
      'En fazla 1 düello kaybedebilirsin',
    ],
    accent: [Color(0xFFFFE1D6), Color(0xFFFF8A65)],
    depth: Color(0xFFD84315),
    ink: Color(0xFF6D1F0A),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: 'En fazla 1 düello kaybederek 7 rakibi yenmelisin',
    scoreUnit: 'sn',
  ),
  GameMode.towerStack: GameModeDef(
    title: 'Kule Ustası',
    tagline: '22 kat · taşan kısım kesilir',
    howTo:
        'Kayan bloğu tam alttakinin üstüne gelince bırak. Taşan kısım kesilir ve kule daralır. Blok hiç değmezse kule yıkılır!',
    scoring: [
      'Her kat 100 puan · tam hizada bırakırsan 250 ve genişlik korunur',
      'Her katta blok daha hızlı kayar',
      'Bloğu boşluğa bırakırsan elenirsin',
    ],
    accent: [Color(0xFFE3F2FF), Color(0xFF7FB8F0)],
    depth: Color(0xFF2F6FB5),
    ink: Color(0xFF123B66),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: 'Kuleyi yıkmadan 22 kata ulaşmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.bridgeBuilder: GameModeDef(
    title: 'Köprü Ustası',
    tagline: '15 köprü · tek düşüş hakkı',
    howTo:
        'Basılı tut, çubuk uzasın. Bıraktığında çubuk yatar: karşı sütuna yetişmeli ama aşmamalı!',
    scoring: [
      'Her köprü 100 · kırmızı merkeze denk getirirsen +100',
      'Sütunlar daralır, çubuk giderek hızlı uzar',
      'İkinci düşüşte elenirsin',
    ],
    accent: [Color(0xFFFFE4E1), Color(0xFFFF9EAA)],
    depth: Color(0xFFC8506A),
    ink: Color(0xFF6B1F30),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '15 köprüyü en fazla 1 düşüşle geçmelisin',
    scoreUnit: 'puan',
  ),
  GameMode.poleBalance: GameModeDef(
    title: 'Denge Çubuğu',
    tagline: '20 saniye · rüzgâra dikkat',
    howTo:
        'Parmağını ekranda tut ve arabayı sağa sola kaydırarak çubuğu dik tut. Çubuk nereye yatıyorsa arabayı oraya götür!',
    scoring: [
      'Her saniye 100 puan · çubuk dikken +50',
      'Çubuk kısaldıkça daha hızlı devrilir, 6. saniyeden sonra rüzgâr',
      'Devrilirse ya da parmağını kaldırırsan elenirsin',
    ],
    accent: [Color(0xFFF3E5FF), Color(0xFFC08BF0)],
    depth: Color(0xFF7B3FC4),
    ink: Color(0xFF3B1466),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '20 saniye boyunca çubuğu devirmemelisin',
    scoreUnit: 'puan',
  ),
  GameMode.tileRush: GameModeDef(
    title: 'Tuş Yağmuru',
    tagline: '20 saniye · tek hata yeter',
    howTo:
        'Aşağı akan koyu tuşlara dokun. Beyaz alana dokunmak ya da bir tuşu kaçırmak oyunu bitirir!',
    scoring: [
      'Her tuş 20 puan · her 25’li seride +100',
      'Hız saniyede 2 satırdan 3,8 satıra çıkar',
      '8. saniyeden sonra aynı satırda iki tuş gelebilir',
    ],
    accent: [Color(0xFFEDEFF7), Color(0xFF8C92B8)],
    depth: Color(0xFF3F4478),
    ink: Color(0xFF1C1F3F),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '20 saniye tek hata yapmadan dayanmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.neonTunnel: GameModeDef(
    title: 'Neon Tünel',
    tagline: '20 saniye · duvarlara değme',
    howTo:
        'Parmağını tünelin içine koy ve kaldırmadan tünelle birlikte hareket et. Tünel kıvrılır, daralır ve hızlanır!',
    scoring: [
      'Her saniye 100 puan · enerji küresi +50',
      'Tünel genişliği giderek üçte birine iner',
      'Duvara değersen ya da parmağını kaldırırsan elenirsin',
    ],
    accent: [Color(0xFFE0FDFF), Color(0xFF5CE1F0)],
    depth: Color(0xFF1B8FA3),
    ink: Color(0xFF07424D),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '20 saniye boyunca duvara değmemelisin',
    scoreUnit: 'puan',
  ),
  GameMode.mirrorTrap: GameModeDef(
    title: 'Ayna Tuzağı',
    tagline: '20 saniye · zihninde döndür',
    howTo:
        'Üstteki şeklin döndürülmüş halini bul. Ayna görüntüsü aynı gibi görünür ama değildir!',
    scoring: [
      'Doğru cevap 100, 1,5 sn altında +60’a kadar bonus',
      'Seçeneklerin ikisi hep ayna tuzağıdır',
      'Yanlış −150, geç kalma −100 · 3 hatada elenirsin',
    ],
    accent: [Color(0xFFFFF0F6), Color(0xFFF59AC4)],
    depth: Color(0xFFC23C7E),
    ink: Color(0xFF661840),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '3 hata yapmadan 1500 puana ulaşmalısın',
    scoreUnit: 'puan',
  ),
  GameMode.echoSequence: GameModeDef(
    title: 'Yankı Dizisi',
    tagline: '6 seviye · dönen disk',
    howTo:
        'Yanan renkleri izle ve aynı sırayla dokun. 3. seviyeden sonra disk döner: konumu değil RENGİ takip et. Bazen dizi tersten istenir!',
    scoring: [
      'Her doğru basış 20×seviye · seviye sonu 100×seviye',
      'Dizi 3’ten 8’e uzar, gösterim hızlanır',
      'Tek yanlış basış ya da 2,5 sn beklemek oyunu bitirir',
    ],
    accent: [Color(0xFFE8E6FF), Color(0xFF8D84F0)],
    depth: Color(0xFF4B3FC4),
    ink: Color(0xFF1E1B4B),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '6. seviyeyi tek hata yapmadan bitirmelisin',
    scoreUnit: 'puan',
  ),
  GameMode.meteorDefense: GameModeDef(
    title: 'Meteor Savunması',
    tagline: '20 saniye · gezegeni koru',
    howTo:
        'Gezegene düşen meteorlara dokun. Büyük meteorlar ikiye bölünür! Uydulara dokunma, kalkanın zarar görür.',
    scoring: [
      'Büyük meteor 40, küçük 60 · her 10’lu seride +100',
      'Kalkana çarpan meteor ya da vurulan uydu −1 kalkan',
      '3 kalkan da biterse elenirsin',
    ],
    accent: [Color(0xFFDDE6FF), Color(0xFF6F86E8)],
    depth: Color(0xFF2C3E9E),
    ink: Color(0xFF0B1030),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '20 saniye boyunca gezegeni korumalısın',
    scoreUnit: 'puan',
  ),
  GameMode.sortBelt: GameModeDef(
    title: 'Ayırma Bandı',
    tagline: '20 saniye · kural değişir',
    howTo:
        'Sarı halkalı ürünü kurala göre yukarı ya da aşağı kaydır. Kural RENK ile ŞEKİL arasında değişir, kutular da yer değiştirir!',
    scoring: [
      'Doğru kutu 100, bandın ortasından önce +40 · 5’li serilerde bonus',
      'Bant sürekli hızlanır, ürün kaçarsa hata sayılır',
      'Yanlış kutu −150 · 3 hatada elenirsin',
    ],
    accent: [Color(0xFFEEF1F8), Color(0xFFA3AECB)],
    depth: Color(0xFF5A6488),
    ink: Color(0xFF2E3250),
    failLabel: 'HEDEF TUTTURULAMADI',
    failHint: '3 hata yapmadan 3500 puana ulaşmalısın',
    scoreUnit: 'puan',
  ),
};

/// Menude gosterilme sirasi. Git/Dur (goNoGo) su an yayindan kaldirildi;
/// tanimi duruyor ama listede yok, yani menude gorunmez ve oynanmaz.
const List<GameMode> kModeOrder = [
  GameMode.shapeHunt,
  GameMode.oddOne,
  GameMode.whack,
  GameMode.typing,
  GameMode.needle,
  GameMode.bubble,
  GameMode.numberHunt,
  GameMode.colorTrap,
  GameMode.arrowStorm,
  GameMode.fruitSlice,
  GameMode.aimTarget,
  GameMode.quickMath,
  GameMode.ringTiming,
  GameMode.memoryCards,
  GameMode.laneRunner,
  GameMode.dotCount,
  GameMode.basketCatch,
  GameMode.cupShuffle,
  GameMode.fingerDodge,
  GameMode.keepUp,
  GameMode.samuraiDuel,
  GameMode.towerStack,
  GameMode.bridgeBuilder,
  GameMode.poleBalance,
  GameMode.tileRush,
  GameMode.neonTunnel,
  GameMode.mirrorTrap,
  GameMode.echoSequence,
  GameMode.meteorDefense,
  GameMode.sortBelt,
];