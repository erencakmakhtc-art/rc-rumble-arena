import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../data/countries.dart';
import '../data/mock_leaderboard.dart';
import '../models/game_enums.dart';
import '../models/game_mode.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_button.dart';
import '../widgets/mode_glyph.dart';
import '../data/world_countries.dart';

class LeaderboardScreen extends StatelessWidget {
  final GameController controller;
  const LeaderboardScreen({super.key, required this.controller});

  String _fmt(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  @override
  Widget build(BuildContext context) {
    final isCountry = controller.boardTab == BoardTab.country;
    final m = controller.boardMode;
    final String caption;
    if (m == null) {
      caption = isCountry ? '190 ÜLKE · ORTALAMA AŞAMA SÜRESİ' : '1.284.309 OYUNCU · ORTALAMA AŞAMA SÜRESİ';
    } else {
      final unit = GameController.lowerIsBetter(m) ? 'SÜRE' : 'PUAN';
      caption = isCountry
          ? '190 ÜLKE · ${kGameModes[m]!.title.toUpperCase()} · ORTALAMA $unit'
          : '${kGameModes[m]!.title.toUpperCase()} · EN İYİ $unit';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: controller.goHome,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.18)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text('‹', style: baloo(20, FontWeight.w800, AppColors.inkSoft)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dünyanın En Hızlı 1000 İnsanı',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: baloo(20, FontWeight.w800, AppColors.ink, height: 1.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.18),
              border: Border.all(color: Colors.white.withOpacity(0.55)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'Bireysel',
                    active: !isCountry,
                    onTap: () => controller.setBoardTab(BoardTab.solo),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: 'Ülke',
                    active: isCountry,
                    onTap: () => controller.setBoardTab(BoardTab.country),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // --- Bolum filtresi ---
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _ModeChip(
                  label: 'Genel',
                  active: m == null,
                  onTap: () => controller.setBoardMode(null),
                ),
                for (final mode in kModeOrder)
                  _ModeChip(
                    label: kGameModes[mode]!.title,
                    active: m == mode,
                    onTap: () => controller.setBoardMode(mode),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(caption, style: baloo(11, FontWeight.w600, AppColors.inkFaint, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                // Genel + Bireysel: once kullanicinin kendi bolum-bolum
                // skorlarini gosteren ozet kart.
                if (m == null && !isCountry) _MyScoresCard(controller: controller),
                ...(m == null
                    ? (isCountry ? _countryRows() : _soloRows())
                    : (isCountry ? _modeCountryRows(m) : _modeSoloRows(m))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CandyButton(
            onTap: controller.openModes,
            height: 60,
            borderRadius: 20,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE4FFD9), Color(0xFFA8E86A)],
            ),
            depthColor: const Color(0xFF5FA22A),
            child: Text('Sıranı yükselt', style: baloo(20, FontWeight.w800, AppColors.greenInk)),
          ),
        ],
      ),
    );
  }

  List<Widget> _soloRows() {
    final myCc = controller.cc ?? 'TR';
    final avgMs = controller.times.isNotEmpty
        ? controller.times.reduce((a, b) => a + b) / controller.times.length
        : null;
    return List.generate(kBoardSolo.length, (i) {
      final r = kBoardSolo[i];
      final isMe = r.me;
      final name = isMe ? (controller.nick.isEmpty ? 'Sen' : controller.nick) : r.name;
      final cc = isMe ? myCc : r.cc;
      final time = isMe ? (avgMs != null ? (avgMs / 1000).toStringAsFixed(2) : '—') : r.time;
      final rank = isMe ? (controller.rank != null ? '#${_fmt(controller.rank!)}' : '—') : '#${i + 1}';
      final secs = isMe
          ? (avgMs != null ? avgMs / 1000 : null)
          : double.tryParse(r.time.replaceAll(',', '.'));
      return _BoardRowTile(
        rank: rank,
        name: name,
        sub: isMe
            ? (worldCountryOf(cc)?.name ?? kCountries[cc]?.name ?? cc)
            : (kCountries[cc]?.name ?? cc),
        cc: cc,
        time: time,
        highlight: isMe,
        seconds: secs,
      );
    });
  }

  /// Bolum bazli bireysel siralama. Oyuncunun kendi en iyi skoru listeye
  /// dogru sirada yerlestirilir. Sure-tabanli bolumlerde kucuk skor daha
  /// iyidir; needle'da buyuk puan daha iyidir.
  List<Widget> _modeSoloRows(GameMode m) {
    final myCc = controller.cc ?? 'TR';
    final myName = controller.nick.isEmpty ? 'Sen' : controller.nick;
    final myScore = controller.bestScore[m];
    final lowerBetter = GameController.lowerIsBetter(m);

    String fmt(int v) => lowerBetter ? '${(v / 1000).toStringAsFixed(2)} sn' : '$v';

    final rows = List<ModeBoardRow>.from(mockModeBoard(m.name));
    var myIndex = rows.length;
    if (myScore != null) {
      myIndex = rows.indexWhere((r) => lowerBetter ? r.points > myScore : r.points < myScore);
      if (myIndex < 0) myIndex = rows.length;
      rows.insert(myIndex, ModeBoardRow(myName, myScore, myCc));
    }

    return List.generate(rows.length, (i) {
      final r = rows[i];
      final isMe = myScore != null && i == myIndex;
      return _BoardRowTile(
        rank: '#${i + 1}',
        name: r.name,
        sub: kCountries[r.cc]?.name ?? worldCountryOf(r.cc)?.name ?? r.cc,
        cc: r.cc,
        time: fmt(r.points),
        highlight: isMe,
      );
    });
  }

  /// Bolum bazli ulke siralamasi (ortalama puan).
  List<Widget> _modeCountryRows(GameMode m) {
    final myCc = controller.cc ?? 'TR';
    final rows = mockModeCountryBoard(m.name);
    return List.generate(rows.length, (i) {
      final r = rows[i];
      return _BoardRowTile(
        rank: '#${i + 1}',
        name: kCountries[r.cc]!.name,
        sub: '${r.players} oyuncu',
        cc: r.cc,
        time: r.time,
        highlight: r.cc == myCc,
      );
    });
  }

  List<Widget> _countryRows() {
    final myCc = controller.cc ?? 'TR';
    return List.generate(kBoardCountry.length, (i) {
      final r = kBoardCountry[i];
      final isMe = r.cc == myCc;
      return _BoardRowTile(
        rank: '#${i + 1}',
        name: kCountries[r.cc]!.name,
        sub: '${r.players} oyuncu',
        cc: r.cc,
        time: r.time,
        highlight: isMe,
        seconds: double.tryParse(r.time.replaceAll(',', '.')),
      );
    });
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withOpacity(active ? 0.9 : 0)),
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withOpacity(0.55), Colors.white.withOpacity(0.3)],
                )
              : null,
        ),
        child: Text(label, style: baloo(14, FontWeight.w800, active ? AppColors.inkSoft : const Color(0xFF6B70A4))),
      ),
    );
  }
}

class _BoardRowTile extends StatelessWidget {
  final String rank;
  final String name;
  final String sub;
  final String cc;
  final String time;
  final bool highlight;

  /// Sure gosteren tablolarda (Genel / Sekil Avi) 2.80 sn altini yesil yapmak
  /// icin, sure saniye cinsinden verilir. Puan tablolarinda null gecilir.
  final double? seconds;

  const _BoardRowTile({
    required this.rank,
    required this.name,
    required this.sub,
    required this.cc,
    required this.time,
    required this.highlight,
    this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    final fast = seconds != null && seconds! < 2.20;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(highlight ? 0.95 : 0.7), width: 2),
        gradient: highlight
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF8E2), Color(0xFFFFDF95)],
              )
            : null,
        color: highlight ? null : Colors.white.withOpacity(0.32),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(rank, style: baloo(13, FontWeight.w800, highlight ? const Color(0xFF8A5A08) : AppColors.inkPale)),
          ),
          Text(flagEmoji(cc), style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: baloo(14, FontWeight.w700, highlight ? AppColors.goldInk : AppColors.inkSoft),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: baloo(10, FontWeight.w600, highlight ? const Color(0xFFA5791A) : AppColors.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            time,
            style: baloo(
              15,
              FontWeight.w800,
              fast
                  ? const Color(0xFF2E9E3F)
                  : (highlight ? AppColors.goldInk : const Color(0xFF5B5F8E)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Siralama ekranindaki bolum filtresi butonu.
class _ModeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withOpacity(active ? 0.95 : 0.55), width: 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? [Colors.white.withOpacity(0.6), Colors.white.withOpacity(0.34)]
                  : [Colors.white.withOpacity(0.26), Colors.white.withOpacity(0.14)],
            ),
          ),
          child: Text(
            label,
            style: baloo(13, FontWeight.w800, active ? AppColors.inkSoft : const Color(0xFF5F65A0)),
          ),
        ),
      ),
    );
  }
}

/// "Genel" görünümünün başında, oyuncunun her bölümde yazdığı en iyi
/// skoru sütun sütun gösteren özet kart. Bir bölüme dokununca leaderboard
/// o bölüme filtrelenir.
class _MyScoresCard extends StatelessWidget {
  final GameController controller;
  const _MyScoresCard({required this.controller});

  /// Bir bölümün skorunu okunur metne çevirir (süre mi puan mı).
  String _fmtScore(GameMode m, int? v) {
    if (v == null) return '—';
    // Puan tabanli bolumler (needle, bubble...) puan; digerleri sure (ms).
    if (!GameController.lowerIsBetter(m)) return '$v';
    return '${(v / 1000).toStringAsFixed(2)} sn';
  }

  @override
  Widget build(BuildContext context) {
    final scored = <GameMode>[
      for (final mode in kModeOrder)
        if (controller.bestScore[mode] != null) mode,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.28)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('⚡', style: baloo(15, FontWeight.w800, AppColors.goldInkAlt)),
              const SizedBox(width: 6),
              Text('Senin skorların', style: baloo(15, FontWeight.w800, AppColors.inkSoft)),
              const Spacer(),
              Text(
                'bölüme dokun · filtrele',
                style: baloo(10, FontWeight.w600, AppColors.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (scored.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Henüz skorun yok. Bir bölüm oynayınca burada görünür.',
                style: baloo(12, FontWeight.w600, AppColors.inkMuted),
              ),
            )
          else
            ...scored.map((mode) {
              final def = kGameModes[mode]!;
              final v = controller.bestScore[mode];
              return GestureDetector(
                onTap: () => controller.setBoardMode(mode),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: def.accent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: ModeGlyph(mode: mode, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          def.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: baloo(13, FontWeight.w700, AppColors.inkSoft),
                        ),
                      ),
                      Text(
                        _fmtScore(mode, v),
                        style: baloo(14, FontWeight.w800, AppColors.ink),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.inkFaint),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
