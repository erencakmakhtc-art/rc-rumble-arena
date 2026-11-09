import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../controllers/mini_base.dart';
import '../models/game_mode.dart';
import '../theme/app_theme.dart';
import 'candy_button.dart';
import 'mode_glyph.dart';
import 'result_theme.dart';

/// Ust bardaki kucuk bilgi kutusu (etiket + deger).
class HudPill extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const HudPill({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
        gradient: highlight
            ? AppGradients.gold
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(0.72), Colors.white.withOpacity(0.48)],
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: baloo(
              9,
              FontWeight.w700,
              highlight ? AppColors.goldInkAlt : AppColors.inkMuted,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            value,
            style: baloo(
              16,
              FontWeight.w800,
              highlight ? AppColors.goldInk : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ana oyundaki ile ayni hamburger menu butonu.
class MiniMenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const MiniMenuButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.75), Colors.white.withOpacity(0.5)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _MenuBar(),
            SizedBox(height: 3),
            _MenuBar(short: true),
            SizedBox(height: 3),
            _MenuBar(),
          ],
        ),
      ),
    );
  }
}

class _MenuBar extends StatelessWidget {
  final bool short;
  const _MenuBar({this.short = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: short ? 12 : 18,
      height: 2.5,
      decoration: BoxDecoration(
        color: AppColors.inkSoft,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Mini bolumlerin ust bari: menu butonu, baslik ve HUD kutulari.
class MiniTopBar extends StatelessWidget {
  final GameMode mode;
  final VoidCallback onMenu;
  final List<Widget> hud;

  const MiniTopBar({
    super.key,
    required this.mode,
    required this.onMenu,
    this.hud = const [],
  });

  @override
  Widget build(BuildContext context) {
    final def = kGameModes[mode]!;
    return Row(
      children: [
        MiniMenuButton(onTap: onMenu),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            def.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: baloo(18, FontWeight.w800, AppColors.ink),
          ),
        ),
        for (final w in hud) ...[const SizedBox(width: 7), w],
      ],
    );
  }
}

/// Bolum basinda gosterilen tanitim karti: nasil oynanir + puanlama +
/// "Anladim" onayi ve "bir daha gosterme" secenegi.
class MiniIntroCard extends StatefulWidget {
  final GameMode mode;
  final VoidCallback onConfirm;
  final ValueChanged<bool> onDontShowChanged;
  final bool dontShow;

  const MiniIntroCard({
    super.key,
    required this.mode,
    required this.onConfirm,
    required this.onDontShowChanged,
    required this.dontShow,
  });

  @override
  State<MiniIntroCard> createState() => _MiniIntroCardState();
}

class _MiniIntroCardState extends State<MiniIntroCard> {
  @override
  Widget build(BuildContext context) {
    final def = kGameModes[widget.mode]!;
    return Container(
      color: const Color(0x66787EC3),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 3),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withOpacity(0.92), Colors.white.withOpacity(0.78)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ModeGlyph(mode: widget.mode, size: 54),
              const SizedBox(height: 12),
              Text(def.title, style: baloo(22, FontWeight.w800, AppColors.ink)),
              const SizedBox(height: 10),
              Text(
                def.howTo,
                textAlign: TextAlign.center,
                style: baloo(15, FontWeight.w700, AppColors.inkSoft, height: 1.35),
              ),
              const SizedBox(height: 12),
              // --- Puanlama kutusu ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0x2E7B80B2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PUANLAMA',
                      style: baloo(
                        9,
                        FontWeight.w700,
                        AppColors.inkFaint,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    for (final line in def.scoring) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '• $line',
                          style: baloo(
                            12,
                            FontWeight.w600,
                            AppColors.inkMuted,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CandyButton(
                onTap: widget.onConfirm,
                height: 52,
                borderRadius: 18,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: def.accent,
                ),
                depthColor: def.depth,
                child: Text(
                  'Anladım',
                  style: baloo(19, FontWeight.w800, def.ink),
                ),
              ),
              const SizedBox(height: 6),
              // --- Bir daha gosterme ---
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onDontShowChanged(!widget.dontShow),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: widget.dontShow ? def.depth : AppColors.inkFaint,
                            width: 2,
                          ),
                          color: widget.dontShow
                              ? def.depth
                              : Colors.white.withOpacity(0.7),
                        ),
                        alignment: Alignment.center,
                        child: widget.dontShow
                            ? const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bunu bir daha gösterme',
                        style: baloo(13, FontWeight.w700, AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ortada beliren 3-2-1 geri sayim balonu.
class MiniCountdown extends StatelessWidget {
  final int? count;
  const MiniCountdown({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween<double>(begin: 1.5, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOut),
            ),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: count == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(count),
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.95),
                      width: 5,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.92),
                        const Color(0xFFE0E5FF).withOpacity(0.85),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: baloo(76, FontWeight.w800, AppColors.inkSoft),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Oyun sirasinda beliren "+25 Combo!" tarzi kisa bildirim.
class MiniToastView extends StatelessWidget {
  final MiniToast? toast;
  const MiniToastView({super.key, required this.toast});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.42),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: toast == null
              ? const SizedBox.shrink(key: ValueKey('none'))
              : Container(
                  key: ValueKey(toast!.id),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.9),
                      width: 2,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: toast!.good
                          ? [const Color(0xFFFFF8E2), const Color(0xFFFFD873)]
                          : [const Color(0xFFFFE6E6), const Color(0xFFFFA9A9)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    toast!.text,
                    style: baloo(
                      17,
                      FontWeight.w800,
                      toast!.good
                          ? AppColors.goldInk
                          : const Color(0xFF7E1A1A),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Menuye basilinca cikan cikis onayi.
class MiniQuitDialog extends StatelessWidget {
  final VoidCallback onQuit;
  final VoidCallback onResume;

  const MiniQuitDialog({
    super.key,
    required this.onQuit,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x80787EC3),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 3),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.94), Colors.white.withOpacity(0.8)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Çıkmak istediğine emin misin?',
              textAlign: TextAlign.center,
              style: baloo(22, FontWeight.w800, AppColors.ink, height: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu turdaki puanların kaydedilmez.',
              textAlign: TextAlign.center,
              style: baloo(12, FontWeight.w600, AppColors.inkPale, height: 1.35),
            ),
            const SizedBox(height: 14),
            CandyButton(
              onTap: onQuit,
              height: 54,
              borderRadius: 18,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFDCAE), Color(0xFFFF9F3D)],
              ),
              depthColor: const Color(0xFFD1701A),
              child: Text(
                'Evet, çık',
                style: baloo(19, FontWeight.w800, AppColors.orangeInk),
              ),
            ),
            const SizedBox(height: 8),
            CandyButton(
              onTap: onResume,
              height: 54,
              borderRadius: 18,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFDFDFF), Color(0xFFDFE3F8)],
              ),
              depthColor: const Color(0x99969CCD),
              child: Text(
                'Devam et',
                style: baloo(19, FontWeight.w800, AppColors.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bolum bitince gosterilen sonuc karti.
///
/// Tasarim ResultDialog (Sekil Avi) ile birebir ayni dili kullanir:
/// basari durumuna gore yesil/kirmizi tema, ust baslik + hedef, toplam puan,
/// ana metrik, istatistik kutulari, dunya siralamasi ve iki buton.
class MiniResultCard extends StatelessWidget {
  final GameMode mode;
  final MiniGameController controller;
  final VoidCallback onRetry;
  final VoidCallback onModes;

  const MiniResultCard({
    super.key,
    required this.mode,
    required this.controller,
    required this.onRetry,
    required this.onModes,
  });

  String _fmt(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  /// Bu turun skorundan tahmini dunya sirasi. Lig sistemiyle ayni formul:
  /// skor bolumun esiklerine gore 0..1 performansa cevrilir, performans
  /// dogrusal olarak siraya eslenir (1 = en iyi). Gercek backend gelince
  /// yerini sunucu sorgusu alacak.
  (int rank, double pct) _fakeRank(int? score) {
    const total = kTotalPlayersForRank;
    final perf = GameController.normalizeScore(mode, score);
    final rank = (1 + ((1 - perf) * (total - 1)).round()).clamp(1, total);
    return (rank, rank / total);
  }

  @override
  Widget build(BuildContext context) {
    final def = kGameModes[mode]!;
    final stats = controller.stats;
    final success = controller.passed;
    final theme = ResultTheme(success);

    // Ana metrik: scoreUnit == 'puan' ise toplam puan, degilse headlineValue
    // (ki o zaten 'XX.XX sn' formatindadir).
    final runScore = controller.resultScore ?? (def.scoreUnit == 'puan' ? controller.points : null);
    final headlineValue = def.scoreUnit == 'puan'
        ? '${runScore ?? controller.points} puan'
        : controller.headlineValue;

    // Basariliysa verdict, basarisizsa hedefi hatirlatan failHint.
    final subtitle = success ? controller.verdict : def.failHint;

    // Sahte dunya siralamasi.
    final (rank, pct) = _fakeRank(runScore);

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

              // --- Yeni rekor rozeti (her iki durumda da) ---
              if (controller.isRecord) ...[
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

              // --- Toplam puan kutusu (bolumun kendi rengiyle) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: def.accent,
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.9),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOPLAM PUAN',
                      style: baloo(
                        9,
                        FontWeight.w700,
                        def.ink.withOpacity(0.75),
                        letterSpacing: 1.8,
                      ),
                    ),
                    Text(
                      '${controller.points}',
                      style: baloo(44, FontWeight.w800, def.ink, height: 1.05),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // --- Ana metrik (sure veya puan) ---
              Text(
                controller.headlineLabel,
                textAlign: TextAlign.center,
                style: baloo(13, FontWeight.w700, theme.verdictInk),
              ),
              Text(
                headlineValue,
                textAlign: TextAlign.center,
                style: baloo(
                  30,
                  FontWeight.w800,
                  theme.headlineInk,
                  height: 1.15,
                ),
              ),

              // --- Istatistik kutulari ---
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 9,
                            horizontal: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: theme.statBoxBg,
                          ),
                          child: Column(
                            children: [
                              Text(
                                stats[i].label,
                                textAlign: TextAlign.center,
                                style: baloo(
                                  9,
                                  FontWeight.w700,
                                  theme.statLabelInk,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stats[i].value,
                                textAlign: TextAlign.center,
                                style: baloo(
                                  15,
                                  FontWeight.w800,
                                  theme.statValueInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // --- Alt aciklama ---
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: baloo(
                  13,
                  FontWeight.w600,
                  theme.verdictInk,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 12),

              // --- Dunya siralamasi ---
              _MiniRankCard(
                rank: rank,
                pct: pct,
                theme: theme,
                fmt: _fmt,
              ),

              const SizedBox(height: 16),

              // --- Tekrar oyna ---
              CandyButton(
                onTap: onRetry,
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
                onTap: onModes,
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

/// Mini bolumlerin sonuc kartinda gosterilen sahte dunya siralamasi kutusu.
/// Sekil Avi'ndaki _RankDone ile ayni gorsel dili kullanir.
class _MiniRankCard extends StatelessWidget {
  final int rank;
  final double pct;
  final ResultTheme theme;
  final String Function(int) fmt;

  const _MiniRankCard({
    required this.rank,
    required this.pct,
    required this.theme,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
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
                widthFactor: (1 - pct).clamp(0.04, 1.0).toDouble(),
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
            'En hızlı %${(pct * 100).round().clamp(1, 100)} içindesin',
            style: baloo(11, FontWeight.w700, theme.rankSubInk),
          ),
        ],
      ),
    );
  }
}

/// Bir mini bolumun tam ekran duzeni.
class MiniStage extends StatelessWidget {
  final GameMode mode;
  final MiniGameController controller;

  /// Bolumden cikis (bolum listesine donus).
  final VoidCallback onQuit;
  final VoidCallback onRetry;

  /// "Bunu bir daha gosterme" secili mi ve degistiginde ne olacak.
  final bool dontShowIntro;
  final ValueChanged<bool> onDontShowIntroChanged;

  final List<Widget> hud;
  final Widget child;

  const MiniStage({
    super.key,
    required this.mode,
    required this.controller,
    required this.onQuit,
    required this.onRetry,
    required this.dontShowIntro,
    required this.onDontShowIntroChanged,
    required this.child,
    this.hud = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            children: [
              MiniTopBar(mode: mode, onMenu: controller.openMenu, hud: hud),
              const SizedBox(height: 14),
              Expanded(child: child),
            ],
          ),
        ),
        if (controller.phase == MiniPhase.play)
          MiniToastView(toast: controller.toast),
        if (controller.phase == MiniPhase.intro)
          MiniIntroCard(
            mode: mode,
            onConfirm: controller.confirmIntro,
            dontShow: dontShowIntro,
            onDontShowChanged: onDontShowIntroChanged,
          ),
        if (controller.phase == MiniPhase.count)
          MiniCountdown(count: controller.count),
        if (controller.phase == MiniPhase.done)
          MiniResultCard(
            mode: mode,
            controller: controller,
            onRetry: onRetry,
            onModes: onQuit,
          ),
        if (controller.menuOpen)
          MiniQuitDialog(onQuit: onQuit, onResume: controller.closeMenu),
      ],
    );
  }
}

/// Sonuc kartindaki tahmini sira icin toplam oyuncu sayisi
/// (mock_leaderboard.dart'taki kTotalPlayers ile ayni).
const int kTotalPlayersForRank = 1284309;
