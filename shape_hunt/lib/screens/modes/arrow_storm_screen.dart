import 'dart:math';

import 'package:flutter/material.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/trial_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';

/// Gecme sarti: 20 saniyede (3 hata yapmadan) ulasilmasi gereken puan.
const int _kArrowTarget = 3800;

/// Kaydirmanin algilanmasi icin gereken en kisa parmak hareketi (px).
const double _kSwipeThreshold = 22;

/// Ok yonleri. Sira onemli: indeks * 90 derece = yukari bakan oku dondurme acisi.
enum ArrowDir { up, right, down, left }

ArrowDir _opposite(ArrowDir d) => ArrowDir.values[(d.index + 2) % 4];

class ArrowStormController extends TrialGameController {
  /// Ortadaki (hedef) okun yonu.
  ArrowDir target = ArrowDir.right;

  /// Yandaki (yaniltici) oklarin yonu.
  ArrowDir flank = ArrowDir.left;

  /// Ortadaki ok kirmizi: TERS yone kaydirilmali.
  bool reverse = false;

  /// Yan oklar kirmizi (sadece yem; kurali etkilemez).
  bool redFlankers = false;

  /// Oklar dikey sutun halinde mi dizili.
  bool vertical = false;

  /// Oklarin alandaki konumu ve boyutu (her denemede degisir).
  Alignment spot = Alignment.center;
  double scale = 1.0;

  ArrowDir? swiped;

  @override
  int get targetPoints => _kArrowTarget;

  @override
  int get fastMs => 650;

  /// Cevap penceresi 1,35 sn'den 0,85 sn'ye daralir.
  @override
  int trialWindowMs(double progress) => (1350 - 500 * progress).round();

  /// Oyuncunun kaydirmasi gereken yon.
  ArrowDir get expected => reverse ? _opposite(target) : target;

  @override
  void resetTrialState() {
    reverse = false;
    redFlankers = false;
    vertical = false;
    spot = Alignment.center;
    scale = 1.0;
    swiped = null;
  }

  @override
  void buildTrial() {
    swiped = null;
    final p = progress;

    target = ArrowDir.values[rng.nextInt(4)];
    // %80 uyumsuz: yan oklar ortadakinden farkli bir yone bakar.
    flank = rng.nextDouble() < 0.8 ? ArrowDir.values[(target.index + 1 + rng.nextInt(3)) % 4] : target;

    // 3. saniyeden sonra %35 ters kural; ters degilse %25 kirmizi yan ok (yem).
    reverse = elapsedMs > 3000 && rng.nextDouble() < 0.35;
    redFlankers = !reverse && elapsedMs > 3000 && rng.nextDouble() < 0.25;

    // 5. saniyeden sonra bazen dikey dizilim.
    vertical = elapsedMs > 5000 && rng.nextDouble() < 0.35;

    // Oklar her seferinde farkli bir yerde belirir; zamanla kuculur.
    final spread = 0.25 + 0.45 * p;
    spot = Alignment((rng.nextDouble() * 2 - 1) * spread, (rng.nextDouble() * 2 - 1) * spread);
    scale = 1.0 - 0.28 * p;
  }

  void swipe(ArrowDir d) {
    if (!acceptingInput) return;
    swiped = d;
    answer(d == expected);
  }

  @override
  String get verdict {
    if (errors == 0 && avgReactionMs < 600) return 'Yan oklar seni bir kez bile kandıramadı. Efsane!';
    if (errors == 0) return 'Hatasız! Biraz daha hızlı kaydırırsan zirve senin.';
    return 'Fırtınayı atlattın. Kırmızı orta oka dikkat!';
  }
}

class ArrowStormScreen extends StatefulWidget {
  final GameController app;
  const ArrowStormScreen({super.key, required this.app});

  @override
  State<ArrowStormScreen> createState() => _ArrowStormScreenState();
}

class _ArrowStormScreenState extends State<ArrowStormScreen> {
  late final ArrowStormController _c;

  @override
  void initState() {
    super.initState();
    _c = ArrowStormController();
    _c.onFinished = () => widget.app.reportModeResult(GameMode.arrowStorm, _c.points, _c.passed);
    _c.begin(skipIntro: widget.app.shouldSkipIntro(GameMode.arrowStorm));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final hasTrial = _c.trials > 0;
        final Color border = switch (_c.feedback) {
          TrialFeedback.correct => const Color(0xFF3FBF6A),
          TrialFeedback.wrong || TrialFeedback.timeout => AppColors.red,
          TrialFeedback.none => Colors.white.withOpacity(0.75),
        };
        return MiniStage(
          mode: GameMode.arrowStorm,
          controller: _c,
          onQuit: widget.app.backToModes,
          dontShowIntro: widget.app.shouldSkipIntro(GameMode.arrowStorm),
          onDontShowIntroChanged: (v) => widget.app.setSkipIntro(GameMode.arrowStorm, v),
          onRetry: () {
            if (widget.app.tryConsumePlayForRetry()) _c.begin(skipIntro: true);
          },
          hud: [
            HudPill(
              label: 'SÜRE',
              value: (_c.remainingMs / 1000).toStringAsFixed(1),
              highlight: _c.remainingMs < 5000,
            ),
            HudPill(label: 'HATA', value: '${_c.errors}/${_c.maxErrors}', highlight: _c.errors >= 2),
            HudPill(label: 'PUAN', value: '${_c.points}', highlight: true),
          ],
          child: _SwipeArea(
            onSwipe: _c.swipe,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: border, width: _c.feedback == TrialFeedback.none ? 2 : 4),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.55), const Color(0xFFDCE6FF).withOpacity(0.7)],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 7)),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _WindowBar(value: hasTrial ? _c.windowLeft : 1.0),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: hasTrial
                          ? Align(
                              alignment: _c.spot,
                              child: _ArrowRow(controller: _c),
                            )
                          : Center(
                              child: Text(
                                'Ortadaki oka göre kaydır',
                                textAlign: TextAlign.center,
                                style: baloo(18, FontWeight.w800, AppColors.inkMuted),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Parmak hareketini dogrudan izleyip 22px'i gecer gecmez yonu bildirir.
/// Jest arenasini (pan gecikmesi) beklemez; her parmak ayri izlenir.
class _SwipeArea extends StatefulWidget {
  final ValueChanged<ArrowDir> onSwipe;
  final Widget child;
  const _SwipeArea({required this.onSwipe, required this.child});

  @override
  State<_SwipeArea> createState() => _SwipeAreaState();
}

class _SwipeAreaState extends State<_SwipeArea> {
  final Map<int, Offset> _starts = {};
  final Set<int> _fired = {};

  void _end(int pointer) {
    _starts.remove(pointer);
    _fired.remove(pointer);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _starts[e.pointer] = e.position;
        _fired.remove(e.pointer);
      },
      onPointerMove: (e) {
        final s = _starts[e.pointer];
        if (s == null || _fired.contains(e.pointer)) return;
        final d = e.position - s;
        if (d.distance < _kSwipeThreshold) return;
        _fired.add(e.pointer);
        final ArrowDir dir;
        if (d.dx.abs() > d.dy.abs()) {
          dir = d.dx > 0 ? ArrowDir.right : ArrowDir.left;
        } else {
          dir = d.dy > 0 ? ArrowDir.down : ArrowDir.up;
        }
        widget.onSwipe(dir);
      },
      onPointerUp: (e) => _end(e.pointer),
      onPointerCancel: (e) => _end(e.pointer),
      child: widget.child,
    );
  }
}

class _ArrowRow extends StatelessWidget {
  final ArrowStormController controller;
  const _ArrowRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final size = 54.0 * c.scale;
    final gap = 8.0 * c.scale;
    final children = <Widget>[];
    for (var i = 0; i < 5; i++) {
      if (i > 0) children.add(SizedBox(width: gap, height: gap));
      final isMid = i == 2;
      children.add(SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ArrowPainter(
            dir: isMid ? c.target : c.flank,
            red: isMid ? c.reverse : c.redFlankers,
          ),
        ),
      ));
    }
    return Flex(
      direction: c.vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final ArrowDir dir;
  final bool red;
  _ArrowPainter({required this.dir, required this.red});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(dir.index * pi / 2);

    // Yukari bakan kalin ok (merkez etrafinda).
    final path = Path()
      ..moveTo(0, -0.44 * s)
      ..lineTo(0.42 * s, 0)
      ..lineTo(0.16 * s, 0)
      ..lineTo(0.16 * s, 0.42 * s)
      ..lineTo(-0.16 * s, 0.42 * s)
      ..lineTo(-0.16 * s, 0)
      ..lineTo(-0.42 * s, 0)
      ..close();

    final rect = Rect.fromCenter(center: Offset.zero, width: s, height: s);
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: red
          ? const [Color(0xFFFF8A8A), Color(0xFFE02F2F)]
          : const [Color(0xFF7C84D4), Color(0xFF3F4478)],
    ).createShader(rect);

    canvas.drawPath(path, Paint()..shader = shader);
    // Ayni renkte kalin kontur: koseleri yumusatir.
    canvas.drawPath(
      path,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.07
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) => old.dir != dir || old.red != red;
}

class _WindowBar extends StatelessWidget {
  final double value;
  const _WindowBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 9,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Colors.white.withOpacity(0.6),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0).toDouble(),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: value < 0.3 ? AppColors.red : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
