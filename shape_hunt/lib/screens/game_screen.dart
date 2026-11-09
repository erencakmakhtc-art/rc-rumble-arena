import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../data/color_defs.dart';
import '../data/pairs.dart';
import '../data/shape_defs.dart';
import '../models/game_enums.dart';
import '../models/game_mode.dart';
import '../models/game_tile.dart';
import '../theme/app_theme.dart';
import '../widgets/candy_button.dart';
import '../widgets/mode_glyph.dart';
import '../widgets/shape_view.dart';
import 'result_dialog.dart';

class GameScreen extends StatelessWidget {
  final GameController controller;
  const GameScreen({super.key, required this.controller});

  String _secs(int ms) => '${(ms / 1000).toStringAsFixed(2)} sn';

  @override
  Widget build(BuildContext context) {
    final live = controller.phase == GamePhase.play;
    final reveal = live || controller.phase == GamePhase.done || controller.phase == GamePhase.final_;

    String kicker;
    String headline;
    String sub;
    double hSize;

    switch (controller.phase) {
      case GamePhase.count:
        kicker = 'BAŞLIYOR';
        headline = 'Hazır…';
        sub = '${controller.count} saniye';
        hSize = 24;
        break;
      case GamePhase.play:
        {
          kicker = 'ŞİMDİ BUL';
          headline = _secs(controller.elapsedMs + controller.penaltyMs);
          final t = controller.target;
          final tName = t != null ? '${kColorNamesTr[t.color]} ${kShapeDefs[t.shape]!.nameTr} · ' : '';
          sub = '${tName}kalan ${6 - controller.found}';
          hSize = 30;
        }
        break;
      case GamePhase.done:
      case GamePhase.final_:
        kicker = 'TEPKİ SÜREN';
        headline = _secs(controller.elapsedMs);
        sub = 'Aşama ${controller.stage} tamam';
        hSize = 30;
        break;
      case GamePhase.announce:
      case GamePhase.idle:
      case GamePhase.intro:
        kicker = 'HAZIR OL';
        headline = 'Bu işaretin 6 tanesini bul';
        sub = 'Izgara 3-2-1 sonrası açılır';
        hSize = 17;
        break;
    }

    // Sure cubugu ve sayac dar kapsamli ValueListenableBuilder icinde
    // hesaplaniyor; burada sadece esik degeri tutuluyor.
    const cap = 9000.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Stack(
        children: [
          Column(
            children: [
              // --- Ust bar: menu / can / en iyi / asama ---
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: controller.askQuit,
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
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            _Bar(),
                            SizedBox(height: 3),
                            _Bar(short: true),
                            SizedBox(height: 3),
                            _Bar(),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    _PillLives(plays: controller.playsLeft),
                    const SizedBox(width: 8),
                    _PillLabelValue(
                      label: 'EN İYİ',
                      value: controller.best == null ? '—' : (controller.best! / 1000).toStringAsFixed(2),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // --- Hedef karti ---
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white.withOpacity(0.38), Colors.white.withOpacity(0.18)],
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 7)),
                  ],
                ),
                child: Container(
                  height: 112,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: Colors.white.withOpacity(0.75)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white.withOpacity(0.34), Colors.white.withOpacity(0.14)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(kicker, style: baloo(9, FontWeight.w600, AppColors.inkFaint, letterSpacing: 1.6)),
                            const SizedBox(height: 3),
                            // Oynanis sirasinda sayac 40ms'de bir degisir;
                            // sadece bu metin yenilensin diye dar kapsamli
                            // dinleyiciye alindi.
                            live
                                ? ValueListenableBuilder<int>(
                                    valueListenable: controller.elapsedNotifier,
                                    builder: (context, ms, _) => Text(
                                      _secs(ms + controller.penaltyMs),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: baloo(hSize, FontWeight.w800, AppColors.inkSoft),
                                    ),
                                  )
                                : Text(
                                    headline,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: baloo(hSize, FontWeight.w800, AppColors.inkSoft),
                                  ),
                            const SizedBox(height: 3),
                            Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baloo(11, FontWeight.w600, AppColors.inkPale),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 86,
                        height: 86,
                        child: controller.target == null
                            ? const _TargetPlaceholder()
                            : Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Center(child: RepaintBoundary(child: _GlowingTarget(pair: controller.target!))),
                                  Positioned(
                                    right: -4,
                                    bottom: -2,
                                    child: Container(
                                      constraints: const BoxConstraints(minWidth: 30),
                                      height: 24,
                                      padding: const EdgeInsets.symmetric(horizontal: 7),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white, width: 2),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Color(0xFFFFE08A), Color(0xFFFFB92E)],
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text('×${6 - controller.found}', style: baloo(13, FontWeight.w800, AppColors.goldInk)),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // --- Sure cubugu ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white.withOpacity(0.38), Colors.white.withOpacity(0.16)],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.75), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 5)),
                  ],
                ),
                // Oynanis sirasinda yalnizca cubuk ve sag sayac degisir.
                child: ValueListenableBuilder<int>(
                  valueListenable: controller.elapsedNotifier,
                  builder: (context, ms, _) {
                    final double livePct;
                    if (live) {
                      livePct = ((ms + controller.penaltyMs) / cap * 100).clamp(0, 100).toDouble();
                    } else if (reveal) {
                      livePct = (ms / cap * 100).clamp(0, 100).toDouble();
                    } else {
                      livePct = 0;
                    }
                    final liveClock = reveal ? ms + (live ? controller.penaltyMs : 0) : 0;

                    return Row(
                      children: [
                        SizedBox(width: 34, child: Text('SÜRE', style: baloo(11, FontWeight.w700, AppColors.inkMuted))),
                        Expanded(
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(7),
                              color: const Color(0x598C92C8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: (livePct / 100).clamp(0.0, 1.0).toDouble(),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: livePct > 70
                                            ? const [Color(0xFFFFC98A), Color(0xFFF07A1F)]
                                            : const [Color(0xFFC3F08A), Color(0xFF74C22A)],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            _secs(liveClock),
                            textAlign: TextAlign.right,
                            style: baloo(12, FontWeight.w700, AppColors.inkMuted),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // --- Izgara ---
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const cols = kGridCols;
                      const rows = kGridRows;
                      const spacing = 5.0;
                      const pad = 8.0;
                      // Hucreler kare kalacak sekilde, hem genislige hem
                      // yukseklige sigan en buyuk kare izgara boyutunu bul.
                      final maxW = constraints.maxWidth;
                      final maxH = constraints.maxHeight;
                      final cellFromW = (maxW - pad * 2 - spacing * (cols - 1)) / cols;
                      final cellFromH = (maxH - pad * 2 - spacing * (rows - 1)) / rows;
                      final cell = cellFromW < cellFromH ? cellFromW : cellFromH;
                      final gridW = cell * cols + spacing * (cols - 1) + pad * 2;
                      final gridH = cell * rows + spacing * (rows - 1) + pad * 2;

                      return SizedBox(
                        width: gridW,
                        height: gridH,
                        child: Container(
                          padding: const EdgeInsets.all(pad),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.75), width: 2),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white.withOpacity(0.32), Colors.white.withOpacity(0.14)],
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 7)),
                            ],
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: controller.tiles.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              mainAxisSpacing: spacing,
                              crossAxisSpacing: spacing,
                              childAspectRatio: 1,
                            ),
                            itemBuilder: (context, i) {
                              final tile = controller.tiles[i];
                              return RepaintBoundary(
                                child: _ShapeTile(
                                  tile: tile,
                                  reveal: reveal,
                                  interactive: live,
                                  wrong: controller.wrongId == tile.id,
                                  onTap: () => controller.tap(tile),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // --- Asama cipleri ---
              Row(
                children: [
                  for (var i = 0; i < kStages; i++) ...[
                    Expanded(
                      child: _StageChip(
                        label: 'AŞAMA ${i + 1}',
                        value: i < controller.times.length ? (controller.times[i] / 1000).toStringAsFixed(2) : '—',
                        active: i + 1 == controller.stage && controller.phase != GamePhase.final_,
                        filled: i < controller.times.length,
                        pulsing: i + 1 == controller.stage && controller.phase == GamePhase.play,
                      ),
                    ),
                    if (i != kStages - 1) const SizedBox(width: 10),
                  ],
                ],
              ),
            ],
          ),

          // --- Katmanli overlay'ler ---
          _CountdownOverlay(count: controller.phase == GamePhase.count ? controller.count : null),
          _BannerToast(banner: controller.phase == GamePhase.done ? controller.banner : null),
          if (controller.phase == GamePhase.intro) _ShapeHuntIntro(controller: controller),
          if (controller.phase == GamePhase.final_) ResultDialog(controller: controller),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Kucuk yardimci widget'lar
// ------------------------------------------------------------------

class _Bar extends StatelessWidget {
  final bool short;
  const _Bar({this.short = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: short ? 12 : 18,
      height: 3,
      decoration: BoxDecoration(color: const Color(0xFF8E93C4), borderRadius: BorderRadius.circular(2)),
    );
  }
}

/// Kalan gunluk oynama hakkini gosteren sari pil.
class _PillLives extends StatelessWidget {
  final int plays;
  const _PillLives({required this.plays});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 10, right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withOpacity(0.95), width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF6D8), Color(0xFFFFD464)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('⚡', style: baloo(15, FontWeight.w800, AppColors.goldInkAlt)),
          const SizedBox(width: 5),
          Text('$plays', style: baloo(16, FontWeight.w800, AppColors.goldInk)),
        ],
      ),
    );
  }
}

class _PillLabelValue extends StatelessWidget {
  final String label;
  final String value;
  const _PillLabelValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.18)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: baloo(8, FontWeight.w600, AppColors.inkFaint, letterSpacing: 1.2)),
          Text(value, style: baloo(16, FontWeight.w800, AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class _TargetPlaceholder extends StatelessWidget {
  const _TargetPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x9996A0D7), width: 2),
          color: Colors.white.withOpacity(0.45),
        ),
        alignment: Alignment.center,
        child: Text('?', style: baloo(30, FontWeight.w800, const Color(0xFFB3B8DD))),
      ),
    );
  }
}

/// Hedef sekli hafifce parlayan (glow) bir animasyonla gosterir.
class _GlowingTarget extends StatefulWidget {
  final ShapePair pair;
  const _GlowingTarget({required this.pair});

  @override
  State<_GlowingTarget> createState() => _GlowingTargetState();
}

class _GlowingTargetState extends State<_GlowingTarget> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final glow = 10 + 12 * _ctrl.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: const Color(0x73FF9628), blurRadius: glow, spreadRadius: 1)],
          ),
          child: child,
        );
      },
      child: ShapeView(pair: widget.pair, size: 70),
    );
  }
}

/// Tek bir izgara hucresi: kapali/acik/yanlis/temizlendi durumlarini animasyonlu gosterir.
class _ShapeTile extends StatefulWidget {
  final GameTile tile;
  final bool reveal;
  final bool interactive;
  final bool wrong;
  final VoidCallback onTap;

  const _ShapeTile({
    required this.tile,
    required this.reveal,
    required this.interactive,
    required this.wrong,
    required this.onTap,
  });

  @override
  State<_ShapeTile> createState() => _ShapeTileState();
}

class _ShapeTileState extends State<_ShapeTile> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void didUpdateWidget(covariant _ShapeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wrong && !oldWidget.wrong) {
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  double _shakeOffset(double t) {
    if (t <= 0 || t >= 1) return 0;
    const stops = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
    const vals = [0.0, -5.0, 5.0, -3.0, 3.0, 0.0];
    for (var i = 0; i < stops.length - 1; i++) {
      if (t >= stops[i] && t <= stops[i + 1]) {
        final localT = (t - stops[i]) / (stops[i + 1] - stops[i]);
        return vals[i] + (vals[i + 1] - vals[i]) * localT;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final cleared = widget.tile.cleared;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(cleared ? 0.5 : 0.9)),
        gradient: cleared
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xD8D6F2B4), Color(0xB3B4E282)],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF2FFFFFF), Color(0x9EFFFFFF)],
              ),
        boxShadow: [
          if (cleared)
            const BoxShadow(color: Color(0xE5A4DD34), spreadRadius: 2)
          else if (widget.wrong)
            const BoxShadow(color: Color(0xE5FF5A5A), spreadRadius: 3)
          else
            const BoxShadow(color: Color(0x1E505796), blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.7,
          heightFactor: 0.7,
          child: AnimatedScale(
            scale: cleared ? 0.16 : (widget.reveal ? 1 : 0.5),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: cleared ? 0 : (widget.reveal ? 1 : 0),
              duration: const Duration(milliseconds: 180),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final s = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
                  return ShapeView(pair: widget.tile.pair, size: s);
                },
              ),
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (context, child) {
        final dx = _shakeOffset(_shakeCtrl.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: GestureDetector(
        onTap: widget.interactive && !cleared ? widget.onTap : null,
        child: content,
      ),
    );
  }
}

/// Faz [GamePhase.count] iken ortada beliren 3-2-1 geri sayim balonu.
class _CountdownOverlay extends StatelessWidget {
  final int? count;
  const _CountdownOverlay({required this.count});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween<double>(begin: 1.5, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
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
                    border: Border.all(color: Colors.white.withOpacity(0.95), width: 5),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Color(0xFFE0E5FF)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text('$count', style: baloo(76, FontWeight.w800, AppColors.inkSoft)),
                ),
        ),
      ),
    );
  }
}

/// Bir asama bittiginde ortada 1.2sn boyunca beliren "X.XX sn" bildirimi.
class _BannerToast extends StatefulWidget {
  final String? banner;
  const _BannerToast({required this.banner});

  @override
  State<_BannerToast> createState() => _BannerToastState();
}

class _BannerToastState extends State<_BannerToast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  String? _shown;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.banner != null) _play(widget.banner!);
  }

  void _play(String text) {
    _shown = text;
    _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _BannerToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.banner != null && widget.banner != oldWidget.banner) {
      _play(widget.banner!);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          if (t <= 0 || t >= 1 || _shown == null) return const SizedBox.shrink();

          double opacity;
          double scale;
          double dy;
          if (t < 0.18) {
            final k = t / 0.18;
            opacity = k;
            scale = 0.9 + 0.1 * k;
            dy = 10 * (1 - k);
          } else if (t < 0.72) {
            opacity = 1;
            scale = 1;
            dy = 0;
          } else {
            final k = (t - 0.72) / 0.28;
            opacity = 1 - k;
            scale = 1 - 0.04 * k;
            dy = -8 * k;
          }

          return Center(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0).toDouble(),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.95), width: 3),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFF9E6), Color(0xFFFFD873)],
                      ),
                    ),
                    child: Text(_shown!, style: baloo(26, FontWeight.w800, const Color(0xFF8A5300))),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Alt kisimda 3 asamanin durumunu gosteren kucuk kartlar (aktifken nabiz gibi buyur-kuculur).
class _StageChip extends StatefulWidget {
  final String label;
  final String value;
  final bool active;
  final bool filled;
  final bool pulsing;

  const _StageChip({
    required this.label,
    required this.value,
    required this.active,
    required this.filled,
    required this.pulsing,
  });

  @override
  State<_StageChip> createState() => _StageChipState();
}

class _StageChipState extends State<_StageChip> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(widget.active ? 0.98 : 0.6), width: 2),
        gradient: widget.filled
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE4FFD9), Color(0xFFBDF094)],
              )
            : (widget.active
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Color(0xFFE6E9FF)],
                  )
                : null),
        color: (!widget.filled && !widget.active) ? Colors.white.withOpacity(0.42) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.label,
            style: baloo(8, FontWeight.w600, widget.filled ? const Color(0xFF5B8F24) : AppColors.inkFaint, letterSpacing: 1.1),
          ),
          const SizedBox(height: 2),
          Text(widget.value, style: baloo(17, FontWeight.w800, widget.filled ? AppColors.greenInkAlt : AppColors.inkMuted)),
        ],
      ),
    );

    if (!widget.pulsing) return chip;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.scale(scale: 1 + _ctrl.value * 0.06, child: child),
      child: chip,
    );
  }
}

/// Sekil Avi bolumunun basindaki "nasil oynanir" tanitim karti.
/// Diger bolumlerdeki MiniIntroCard ile ayni dili tasir.
class _ShapeHuntIntro extends StatefulWidget {
  final GameController controller;
  const _ShapeHuntIntro({required this.controller});

  @override
  State<_ShapeHuntIntro> createState() => _ShapeHuntIntroState();
}

class _ShapeHuntIntroState extends State<_ShapeHuntIntro> {
  @override
  Widget build(BuildContext context) {
    final def = kGameModes[GameMode.shapeHunt]!;
    final dontShow = widget.controller.shouldSkipIntro(GameMode.shapeHunt);

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
              colors: [Colors.white.withOpacity(0.94), Colors.white.withOpacity(0.8)],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ModeGlyph(mode: GameMode.shapeHunt, size: 54),
              const SizedBox(height: 12),
              Text(def.title, style: baloo(22, FontWeight.w800, AppColors.ink)),
              const SizedBox(height: 10),
              Text(
                def.howTo,
                textAlign: TextAlign.center,
                style: baloo(15, FontWeight.w700, AppColors.inkSoft, height: 1.35),
              ),
              const SizedBox(height: 12),
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
                    Text('KURAL', style: baloo(9, FontWeight.w700, AppColors.inkFaint, letterSpacing: 1.6)),
                    const SizedBox(height: 5),
                    Text(
                      '• 3 aşama, her aşamada 6 hedef\n'
                      '• Yanlış dokunuş 0,5 sn ceza\n'
                      '• 3 aşama ortalaması 2,20 sn altında olursa diğer bölümler açılır',
                      style: baloo(12, FontWeight.w600, AppColors.inkMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CandyButton(
                onTap: widget.controller.confirmShapeHuntIntro,
                height: 52,
                borderRadius: 18,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: def.accent,
                ),
                depthColor: def.depth,
                child: Text('Anladım', style: baloo(19, FontWeight.w800, def.ink)),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.controller.setSkipIntro(GameMode.shapeHunt, !dontShow);
                },
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
                          border: Border.all(color: dontShow ? def.depth : AppColors.inkFaint, width: 2),
                          color: dontShow ? def.depth : Colors.white.withOpacity(0.7),
                        ),
                        alignment: Alignment.center,
                        child: dontShow ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 8),
                      Text('Bunu bir daha gösterme', style: baloo(13, FontWeight.w700, AppColors.inkMuted)),
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