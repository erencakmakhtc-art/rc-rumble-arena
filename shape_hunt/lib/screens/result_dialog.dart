import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../models/game_enums.dart';
import '../models/game_mode.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_button.dart';
import '../widgets/result_theme.dart';

/// Sekil Avi (ilk bolum) sonuc ekrani.
///
/// Basari kriteri: 3 asamanin ortalamasi [kUnlockAvgMs] (2200 ms) altinda
/// olmali. Bu tutulmazsa kirmizi "basarisiz" temasi kullanilir.
class ResultDialog extends StatelessWidget {
  final GameController controller;
  const ResultDialog({super.key, required this.controller});

  String _secs(int ms) => '${(ms / 1000).toStringAsFixed(2)} sn';

  String _fmt(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  @override
  Widget build(BuildContext context) {
    final times = controller.times;
    final avgMs = times.isEmpty
        ? 0
        : (times.reduce((a, b) => a + b) / times.length).round();

    // Basari = ortalama 2.20 sn altinda.
    final success = avgMs > 0 && avgMs < kUnlockAvgMs;
    final theme = ResultTheme(success);
    final def = kGameModes[GameMode.shapeHunt]!;

    // Basariliysa tesvik, basarisizsa hedefi hatirlat.
    final subtitle = success
        ? '3 aşama tamam'
        : def.failHint;

    final verdict = avgMs == 0
        ? ''
        : (success
            ? (avgMs < 1600
                ? 'İnanılmaz! Reflekslerin şampiyon seviyesinde.'
                : 'Refleksler keskin. Sıradaki bölüm açıldı!')
            : 'Ortalaman ${(kUnlockAvgMs / 1000).toStringAsFixed(2)} sn altında olmalı.');

    return Container(
      color: const Color(0x73787EC3),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      child: SingleChildScrollView(
        child: Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.cardBorder, width: 3),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: theme.cardColors,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Ust baslik ---
              Text(
                success ? 'BÖLÜM TAMAMLANDI' : def.failLabel,
                textAlign: TextAlign.center,
                style: baloo(
                  13,
                  FontWeight.w800,
                  theme.topLabelInk,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: baloo(
                  12,
                  FontWeight.w600,
                  theme.verdictInk,
                  height: 1.3,
                ),
              ),

              // --- Yeni rekor rozeti (her iki durumda da gosterilir) ---
              if (controller.record) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.95),
                      width: 2,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: theme.recordBadgeGradient,
                    ),
                  ),
                  child: Text(
                    '⚡ Yeni rekor',
                    style: baloo(13, FontWeight.w800, theme.recordBadgeInk),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // --- Ana metrik basligi ---
              Text(
                'Ortalama tepki süren',
                style: baloo(15, FontWeight.w800, theme.verdictInk),
              ),
              const SizedBox(height: 2),

              // --- Buyuk sayi ---
              Text(
                avgMs == 0 ? '—' : _secs(avgMs),
                style: baloo(
                  54,
                  FontWeight.w800,
                  theme.headlineInk,
                  height: 1.05,
                ),
              ),

              const SizedBox(height: 14),

              // --- 3 asama kutusu ---
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: _StatBox(
                        label: 'AŞAMA ${i + 1}',
                        value: i < times.length
                            ? (times[i] / 1000).toStringAsFixed(2)
                            : '—',
                        bg: theme.statBoxBg,
                        labelInk: theme.statLabelInk,
                        valueInk: theme.statValueInk,
                      ),
                    ),
                    if (i != 2) const SizedBox(width: 8),
                  ],
                ],
              ),

              const SizedBox(height: 14),

              // --- Alt aciklama ---
              if (verdict.isNotEmpty)
                Text(
                  verdict,
                  textAlign: TextAlign.center,
                  style: baloo(
                    12,
                    FontWeight.w600,
                    theme.verdictInk,
                    height: 1.35,
                  ),
                ),

              // --- Dunya siralamasi ---
              if (controller.rankPhase == RankPhase.calc) ...[
                const SizedBox(height: 12),
                _RankCalc(controller: controller, theme: theme),
              ],
              if (controller.rankPhase == RankPhase.done) ...[
                const SizedBox(height: 12),
                _RankDone(
                  controller: controller,
                  theme: theme,
                  fmt: _fmt,
                ),
              ],

              const SizedBox(height: 16),

              // --- Tekrar oyna ---
              CandyButton(
                onTap: controller.restart,
                height: 54,
                borderRadius: 18,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: theme.retryGradient,
                ),
                depthColor: theme.retryDepth,
                child: Text(
                  'Tekrar oyna',
                  style: baloo(19, FontWeight.w800, theme.retryInk),
                ),
              ),
              const SizedBox(height: 8),

              // --- Bolumler ---
              CandyButton(
                onTap: controller.backToModes,
                height: 54,
                borderRadius: 18,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: theme.modesGradient,
                ),
                depthColor: theme.modesDepth,
                child: Text(
                  'Bölümler',
                  style: baloo(19, FontWeight.w800, theme.modesInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Yardimci widget'lar
// ------------------------------------------------------------------

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color labelInk;
  final Color valueInk;

  const _StatBox({
    required this.label,
    required this.value,
    required this.bg,
    required this.labelInk,
    required this.valueInk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: bg,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: baloo(9, FontWeight.w700, labelInk, letterSpacing: 1),
          ),
          const SizedBox(height: 2),
          Text(value, style: baloo(15, FontWeight.w800, valueInk)),
        ],
      ),
    );
  }
}

class _RankCalc extends StatelessWidget {
  final GameController controller;
  final ResultTheme theme;
  const _RankCalc({required this.controller, required this.theme});

  @override
  Widget build(BuildContext context) {
    const messages = [
      'Skorun sunucuya gönderiliyor…',
      '1.284.309 oyuncuyla karşılaştırılıyor…',
      'Sıralaman hesaplanıyor…',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.loadingBoxBg,
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              messages[controller.rankStep % messages.length],
              style: baloo(
                11.5,
                FontWeight.w600,
                AppColors.inkSoft,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankDone extends StatelessWidget {
  final GameController controller;
  final ResultTheme theme;
  final String Function(int) fmt;

  const _RankDone({
    required this.controller,
    required this.theme,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final rank = controller.rank ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.rankBorder, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.rankCardColors,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DÜNYA SIRALAMASI',
                    style: baloo(
                      9,
                      FontWeight.w600,
                      theme.rankLabelInk,
                      letterSpacing: 1.4,
                    ),
                  ),
                  Text(
                    '#${fmt(rank)}',
                    style: baloo(26, FontWeight.w800, theme.rankValueInk),
                  ),
                ],
              ),
              Text(
                '${fmt(1284309)}\noyuncu içinde',
                textAlign: TextAlign.right,
                style: baloo(
                  11,
                  FontWeight.w700,
                  theme.rankSubInk,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 9,
              color: theme.rankTrackBg,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (1 - controller.pct).clamp(0.04, 1.0).toDouble(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: theme.rankBarGradient),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'En hızlı %${(controller.pct * 100).round().clamp(1, 100)} içindesin',
            style: baloo(11, FontWeight.w700, theme.rankSubInk),
          ),
        ],
      ),
    );
  }
}