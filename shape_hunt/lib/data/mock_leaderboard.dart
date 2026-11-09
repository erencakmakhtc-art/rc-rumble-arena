// NOT: Bu dosyadaki veriler tamamen yereldir (sahte / mock).
// Ileride Firebase entegre edildiginde bu sabit listelerin yerini
// gercek bir ScoreRepository / Firestore sorgusu alacak.
// Orijinal tasarimdaki BOARD / COUNTRIES dizileriyle birebir aynidir.

import '../models/game_mode.dart';

class BoardRow {
  final String name;
  final String time; // saniye, orn '1.86'. Bos string = 'ben' satiri icin hesaplanacak.
  final String cc;
  final bool me;

  const BoardRow(this.name, this.time, this.cc, {this.me = false});
}

const List<BoardRow> kBoardSolo = [
  BoardRow('Kaya_92', '1.86', 'TR'),
  BoardRow('mint.owl', '2.04', 'JP'),
  BoardRow('Zeynep', '2.11', 'DE'),
  BoardRow('fastfox', '2.39', 'US'),
  BoardRow('Deniz K.', '2.52', 'TR'),
  BoardRow('nova', '2.74', 'BR'),
  BoardRow('Sen', '', 'TR', me: true),
  BoardRow('orkun', '3.18', 'NL'),
  BoardRow('lilac', '3.41', 'FR'),
];

class CountryRow {
  final String cc;
  final String time;
  final String players;

  const CountryRow(this.cc, this.time, this.players);
}

const List<CountryRow> kBoardCountry = [
  CountryRow('JP', '2.21', '184.902'),
  CountryRow('KR', '2.34', '96.410'),
  CountryRow('TR', '2.48', '212.774'),
  CountryRow('DE', '2.57', '131.508'),
  CountryRow('FR', '2.66', '88.230'),
  CountryRow('US', '2.71', '243.117'),
  CountryRow('BR', '2.88', '157.640'),
  CountryRow('ES', '2.96', '74.055'),
  CountryRow('NL', '3.05', '41.328'),
];

const int kTotalPlayers = 1284309;

// ---------------------------------------------------------------------------
// BOLUM BAZLI SIRALAMA (sahte veri)
//
// Her bolumun kendi puan sistemi oldugu icin siralama da bolum bazinda
// tutulur. Asagidaki uretim tamamen yereldir ve sadece arayuzu doldurmak
// icindir; Firebase eklendiginde bu fonksiyonlarin yerini gercek sorgular
// alacak (ornegin: scores/{modeId} koleksiyonundan ilk N kayit).
// ---------------------------------------------------------------------------

/// Bir bolum siralamasindaki tek satir.
class ModeBoardRow {
  final String name;
  final int points;
  final String cc;
  const ModeBoardRow(this.name, this.points, this.cc);
}

const List<String> _kNames = [
  'Kaya_92', 'mint.owl', 'Zeynep', 'fastfox', 'Deniz K.',
  'nova', 'orkun', 'lilac', 'byte.kid', 'seda__',
];

const List<String> _kCcs = ['TR', 'JP', 'DE', 'US', 'TR', 'BR', 'NL', 'FR', 'KR', 'ES'];

/// Her bolumun siralamasindaki en iyi (1.) deger.
/// Sure bazli bolumlerde ms (kucuk = iyi), puan bazlilarda puan (buyuk = iyi).
const Map<String, int> _kModeBest = {
  // sure (ms)
  'shapeHunt': 1650,
  'oddOne': 7400,
  'whack': 38000,
  'typing': 10200,
  'numberHunt': 9600,
  'aimTarget': 11200,
  'memoryCards': 14200,
  'samuraiDuel': 198,
  // puan
  'needle': 1450,
  'goNoGo': 2900,
  'bubble': 4700,
  'colorTrap': 4400,
  'arrowStorm': 5500,
  'fruitSlice': 3100,
  'quickMath': 3300,
  'ringTiming': 4000,
  'laneRunner': 1900,
  'dotCount': 3100,
  'basketCatch': 1900,
  'cupShuffle': 1450,
  'fingerDodge': 3000,
  'keepUp': 1700,
  'towerStack': 4600,
  'bridgeBuilder': 2800,
  'poleBalance': 2950,
  'tileRush': 1480,
  'neonTunnel': 2950,
  'mirrorTrap': 2900,
  'echoSequence': 4760,
  'meteorDefense': 3300,
  'sortBelt': 4300,
};

bool _isTimeMode(String modeKey) {
  for (final m in GameMode.values) {
    if (m.name == modeKey) return kGameModes[m]?.scoreUnit != 'puan';
  }
  return false;
}

/// Verilen bolum icin sahte bir ilk-10 listesi uretir.
/// Ayni bolum icin her zaman ayni sonucu verir (rastgelelik yok).
/// Sure bazli bolumlerde degerler kucukten buyuge, puan bazlilarda buyukten
/// kucuge dizilir (her iki durumda da 1. sira en iyisidir).
List<ModeBoardRow> mockModeBoard(String modeKey) {
  final best = _kModeBest[modeKey] ?? 3000;
  final timeMode = _isTimeMode(modeKey);
  final stepRate = 0.035 + (modeKey.length % 3) * 0.006;
  return List<ModeBoardRow>.generate(_kNames.length, (i) {
    final step = (best * stepRate * i).round();
    return ModeBoardRow(_kNames[i], timeMode ? best + step : best - step, _kCcs[i]);
  });
}

/// Verilen bolum icin sahte ulke siralamasi (ulke ortalamasi, bicimlenmis).
List<CountryRow> mockModeCountryBoard(String modeKey) {
  final best = _kModeBest[modeKey] ?? 3000;
  final timeMode = _isTimeMode(modeKey);
  const ccs = ['JP', 'KR', 'TR', 'DE', 'FR', 'US', 'BR', 'ES', 'NL'];
  const players = [
    '184.902', '96.410', '212.774', '131.508', '88.230',
    '243.117', '157.640', '74.055', '41.328',
  ];
  return List<CountryRow>.generate(ccs.length, (i) {
    if (timeMode) {
      final avgMs = best * 1.55 + best * 0.06 * i;
      return CountryRow(ccs[i], '${(avgMs / 1000).toStringAsFixed(2)} sn', players[i]);
    }
    final avg = (best * 0.62 - best * 0.035 * i).round();
    return CountryRow(ccs[i], '$avg', players[i]);
  });
}
