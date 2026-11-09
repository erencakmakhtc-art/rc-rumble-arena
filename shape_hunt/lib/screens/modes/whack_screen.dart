import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../models/game_mode.dart';
import '../../widgets/mini_kit.dart';

const int _kWhackGrid = 3;

/// Bolum, bu puana ulasilinca biter. Ne kadar kisa surede ulasilirsa o kadar iyi.
const int _kWhackTargetPoints = 7000;

/// Guvenlik ust siniri: bu kadar surede hedefe ulasilamazsa yine de biter.
const int _kWhackMaxMs = 120000;

/// Bu kadar kostebek kacarsa oyun basarisiz biter.
const int _kWhackMaxMisses = 5;

/// Hizlanma bu saniyede baslar ve [_kWhackMaxSpeedSec]'te en yuksege ulasir.
const int _kWhackSpeedUpSec = 6;
const int _kWhackMaxSpeedSec = 10;

class _Mole {
  /// Kostebegin ciktigi ve kaybolacagi an.
  final DateTime shownAt;
  final DateTime expiresAt;
  bool hit = false;
  _Mole(this.shownAt, this.expiresAt);
}

class WhackController extends MiniGameController {
  final Random _rng = Random();

  /// 9 delik; null ise o delik bos.
  final List<_Mole?> holes = List<_Mole?>.filled(_kWhackGrid * _kWhackGrid, null);

  int hits = 0;
  int misses = 0;
  int wrongTaps = 0;

  /// Gecen sure (yukari sayar). Hedef puana ulasildigi an rekordur.
  int elapsedMs = 0;
  int? lastHitIndex;

  DateTime? _startedAt;
  Timer? _spawnTimer;
  Timer? _tickTimer;
  int? _bestMs; // en kisa bitirme suresi
  bool _newRecord = false;

  @override
  void resetState() {
    for (var i = 0; i < holes.length; i++) {
      holes[i] = null;
    }
    hits = 0;
    misses = 0;
    wrongTaps = 0;
    elapsedMs = 0;
    lastHitIndex = null;
    _startedAt = null;
    _spawnTimer?.cancel();
    _tickTimer?.cancel();
  }

  @override
  void onPlayStart() {
    _startedAt = DateTime.now();
    _startTimers();
  }

  void _startTimers() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (phase != MiniPhase.play) return;
      elapsedMs = DateTime.now().difference(_startedAt!).inMilliseconds;

      // Suresi dolan kostebekleri kaldir.
      final now = DateTime.now();
      for (var i = 0; i < holes.length; i++) {
        final m = holes[i];
        if (m != null && !m.hit && now.isAfter(m.expiresAt)) {
          holes[i] = null;
          misses += 1;
          breakStreak();
        }
      }

      if (misses >= _kWhackMaxMisses) {
        _finishRun();
        return;
      }
      if (points >= _kWhackTargetPoints || elapsedMs >= _kWhackMaxMs) {
        _finishRun();
        return;
      }
      safeNotify();
    });
    own(_tickTimer!);

    _scheduleSpawn(initial: true);
  }

  /// Duraklatildiginda calisan kostebekleri temizler.
  @override
  void onPause() {
    for (var i = 0; i < holes.length; i++) {
      holes[i] = null;
    }
  }

  /// Devam edilince gecen sure kadar baslangici ileri kaydirir.
  @override
  void onResume(int pausedMs) {
    if (_startedAt != null) {
      _startedAt = _startedAt!.add(Duration(milliseconds: pausedMs));
    }
    _startTimers();
  }

  /// Hizlanma orani (0..1): 6. saniyeye kadar 0, 10. saniyede 1.
  /// Yani oyun 6. saniyeden sonra hizlanmaya baslar, 10. saniyede en yuksek
  /// tempoya ulasir ve oyle kalir.
  double get _progress {
    final sec = elapsedMs / 1000.0;
    if (sec <= _kWhackSpeedUpSec) return 0.0;
    if (sec >= _kWhackMaxSpeedSec) return 1.0;
    return (sec - _kWhackSpeedUpSec) / (_kWhackMaxSpeedSec - _kWhackSpeedUpSec);
  }

  void _scheduleSpawn({bool initial = false}) {
    final p = _progress;
    // Cikis araligi 780ms -> 300ms'e iner (sona dogru belirgin hizlanir).
    final gap = (780 - 480 * p).round();
    final jitter = _rng.nextInt(160);
    _spawnTimer = Timer(Duration(milliseconds: initial ? 250 : gap + jitter), () {
      if (phase != MiniPhase.play) return;
      _spawn();
      _scheduleSpawn();
    });
    own(_spawnTimer!);
  }

  void _spawn() {
    final free = <int>[];
    for (var i = 0; i < holes.length; i++) {
      if (holes[i] == null) free.add(i);
    }
    if (free.isEmpty) return;

    final p = _progress;
    // Ekranda kalma suresi 1050ms -> 560ms'e iner.
    final lifeMs = (1050 - 490 * p).round();
    final now = DateTime.now();

    // Ayni anda kac kostebek olabilecegi ilerledikce artar.
    final maxActive = p > 0.55 ? 4 : 3;
    final activeCount = holes.length - free.length;
    if (activeCount >= maxActive) return;

    // Oyun ilerledikce (yari noktadan sonra) bazen ikili cikis: iki parmak
    // gerektiren anlar yaratir.
    final canDouble = p > 0.5 && free.length >= 2 && activeCount < maxActive - 1;
    final doubleSpawn = canDouble && _rng.nextDouble() < 0.28;

    final first = free.removeAt(_rng.nextInt(free.length));
    holes[first] = _Mole(now, now.add(Duration(milliseconds: lifeMs)));
    if (doubleSpawn && free.isNotEmpty) {
      final second = free[_rng.nextInt(free.length)];
      holes[second] = _Mole(now, now.add(Duration(milliseconds: lifeMs)));
    }
    safeNotify();
  }

  void tap(int index) {
    if (phase != MiniPhase.play) return;
    final m = holes[index];
    if (m == null || m.hit) {
      wrongTaps += 1;
      breakStreak();
      addPoints(-20);
      AudioManager.instance.playWrong();
      safeNotify();
      return;
    }
    m.hit = true;
    hits += 1;
    lastHitIndex = index;
    bumpStreak();

    // Ne kadar cabuk vurdugu: cikistan sonraki ilk 600ms'de tam bonus.
    final reactMs = DateTime.now().difference(m.shownAt).inMilliseconds;
    final speedBonus = reactMs >= 600 ? 0 : ((600 - reactMs) / 600 * 40).round();
    var gained = 50 + speedBonus;

    String? label;
    if (streak == 5) {
      gained += 100;
      label = '5’li combo! +$gained';
    } else if (streak == 10) {
      gained += 300;
      label = '10’lu combo! +$gained';
    } else if (streak > 10 && streak % 5 == 0) {
      gained += 150;
      label = '$streak’li seri! +$gained';
    }
    addPoints(gained, label: label);

    AudioManager.instance.playCorrect();
    safeNotify();
    own(Timer(const Duration(milliseconds: 150), () {
      if (holes[index] == m) holes[index] = null;
      safeNotify();
    }));
  }

  void _finishRun() {
    _spawnTimer?.cancel();
    _tickTimer?.cancel();
    // Basari: 5 kostebek kacmadan 7000 puana ulasma.
    final reached = points >= _kWhackTargetPoints && misses < _kWhackMaxMisses;
    if (reached) {
      AudioManager.instance.playWin();
      final prev = _bestMs;
      if (prev == null || elapsedMs < prev) _bestMs = elapsedMs;
      _newRecord = prev != null && elapsedMs < prev;
    } else {
      AudioManager.instance.playLose();
      _newRecord = false;
    }
    finish();
  }

  bool get reachedTarget => points >= _kWhackTargetPoints && misses < _kWhackMaxMisses;

  @override
  bool get passed => reachedTarget;

  @override
  int? get resultScore => passed ? elapsedMs : null;
  bool get failedByMisses => misses >= _kWhackMaxMisses;

  int get accuracy {
    final total = hits + misses + wrongTaps;
    if (total == 0) return 0;
    return ((hits / total) * 100).round();
  }

  @override
  bool get isRecord => _newRecord;

  @override
  String get headlineLabel => reachedTarget ? 'Bitirme süren' : (failedByMisses ? '5 köstebek kaçtı' : 'Süre doldu');

  @override
  String get headlineValue =>
      reachedTarget ? '${(elapsedMs / 1000).toStringAsFixed(1)} sn' : '$points puan';

  @override
  List<MiniStat> get stats => [
        MiniStat('İSABET', '%$accuracy'),
        MiniStat('VURUŞ', '$hits'),
        MiniStat('KAÇAN', '$misses/$_kWhackMaxMisses'),
      ];

  @override
  String get verdict {
    if (failedByMisses) return '5 köstebek kaçtı! Ellerini ızgaranın ortasında tut, yetişmesi kolaylaşır.';
    if (!reachedTarget) return '7000 puana ulaşamadın ama az kaldı, tekrar dene!';
    final s = elapsedMs / 1000;
    if (s < 45) return 'İnanılmaz tempo. Elin gözünden hızlı.';
    if (s < 65) return 'Çok iyi. Hedefe hızlıca ulaştın.';
    if (accuracy >= 85) return 'Çok isabetli. Boşa vuruş neredeyse yok.';
    return 'Hedefi tutturdun. Daha hızlısı için isabeti artır.';
  }
}

class WhackScreen extends StatefulWidget {
  final GameController app;
  const WhackScreen({super.key, required this.app});

  @override
  State<WhackScreen> createState() => _WhackScreenState();
}

class _WhackScreenState extends State<WhackScreen> {
  late final WhackController _c;

  @override
  void initState() {
    super.initState();
    _c = WhackController();
    _c.onFinished = () => widget.app.reportModeResult(GameMode.whack, _c.elapsedMs, _c.passed);
    _c.begin(skipIntro: widget.app.shouldSkipIntro(GameMode.whack));
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
        return MiniStage(
          mode: GameMode.whack,
          controller: _c,
          onQuit: widget.app.backToModes,
          dontShowIntro: widget.app.shouldSkipIntro(GameMode.whack),
          onDontShowIntroChanged: (v) => widget.app.setSkipIntro(GameMode.whack, v),
          onRetry: () {
            if (widget.app.tryConsumePlayForRetry()) _c.begin(skipIntro: true);
          },
          hud: [
            HudPill(label: 'KAÇAN', value: '${_c.misses}/$_kWhackMaxMisses', highlight: _c.misses >= 3),
            HudPill(label: 'PUAN', value: '${_c.points}/$_kWhackTargetPoints', highlight: true),
          ],
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFBFA77E).withOpacity(0.8),
                      const Color(0xFF9A8259).withOpacity(0.85),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 9)),
                  ],
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _kWhackGrid,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _kWhackGrid * _kWhackGrid,
                  itemBuilder: (context, i) {
                    final mole = _c.holes[i];
                    return RepaintBoundary(
                      child: _HoleTile(
                        up: mole != null && !mole.hit,
                        struck: mole != null && mole.hit,
                        onTap: () => _c.tap(i),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HoleTile extends StatelessWidget {
  final bool up;
  final bool struck;
  final VoidCallback onTap;

  const _HoleTile({required this.up, required this.struck, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, c) {
          final size = min(c.maxWidth, c.maxHeight);
          return Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.hardEdge,
            children: [
              // delik cukuru
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.22),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF6B4A22), Color(0xFF3F2A0F)],
                    ),
                  ),
                ),
              ),
              // kostebek
              AnimatedPositioned(
                duration: Duration(milliseconds: struck ? 90 : 150),
                curve: Curves.easeOutBack,
                bottom: up || struck ? size * 0.1 : -size * 0.75,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 90),
                  scale: struck ? 0.82 : 1.0,
                  child: _MoleBody(size: size * 0.66, struck: struck),
                ),
              ),
              // delik agzi (on plan) - kostebek arkasindan cikiyormus hissi
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: size * 0.26,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(size * 0.3),
                      bottom: Radius.circular(size * 0.2),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF8C6631), Color(0xFF5E401A)],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MoleBody extends StatelessWidget {
  final double size;
  final bool struck;
  const _MoleBody({required this.size, required this.struck});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MolePainter(struck: struck)),
    );
  }
}

class _MolePainter extends CustomPainter {
  final bool struck;
  _MolePainter({required this.struck});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyRect = Rect.fromLTWH(0, h * 0.08, w, h * 0.92);

    // govde
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFFFFD79E), Color(0xFFD98A2B)],
      ).createShader(bodyRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.46)),
      body,
    );

    // parlaklik
    final hl = Rect.fromLTWH(w * 0.18, h * 0.14, w * 0.64, h * 0.3);
    final hlPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.0)],
      ).createShader(hl);
    canvas.drawOval(hl, hlPaint);

    final dark = Paint()..color = const Color(0xFF6B3A05);

    if (struck) {
      // vurulunca gozler capraz cizgi olur
      final stroke = Paint()
        ..color = const Color(0xFF6B3A05)
        ..strokeWidth = w * 0.055
        ..strokeCap = StrokeCap.round;
      for (final cx in [w * 0.33, w * 0.67]) {
        canvas.drawLine(
          Offset(cx - w * 0.06, h * 0.42 - w * 0.06),
          Offset(cx + w * 0.06, h * 0.42 + w * 0.06),
          stroke,
        );
        canvas.drawLine(
          Offset(cx - w * 0.06, h * 0.42 + w * 0.06),
          Offset(cx + w * 0.06, h * 0.42 - w * 0.06),
          stroke,
        );
      }
    } else {
      canvas.drawCircle(Offset(w * 0.33, h * 0.42), w * 0.062, dark);
      canvas.drawCircle(Offset(w * 0.67, h * 0.42), w * 0.062, dark);
    }

    // burun
    final nose = Paint()..color = const Color(0xFF8A4A10);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.58), width: w * 0.2, height: h * 0.12),
      nose,
    );
  }

  @override
  bool shouldRepaint(covariant _MolePainter oldDelegate) => oldDelegate.struck != struck;
}
