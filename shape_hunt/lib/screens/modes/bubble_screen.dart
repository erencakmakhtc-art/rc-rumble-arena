import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';

/// Bolum suresi (ms).
const int _kBubbleDurationMs = 20000;

/// Gecme sarti: sure bitene kadar ulasilmasi gereken puan.
const int _kBubbleTargetPoints = 3600;

/// Dikenli baloncuklar bu andan sonra cikmaya baslar (ms).
const int _kSpikeStartMs = 2000;

/// Altin baloncuklar bu andan sonra cikmaya baslar (ms).
const int _kGoldStartMs = 2000;

/// Patlama halkasinin suresi ve "+puan" yazisinin ekranda kalma suresi (ms).
const double _kPopRingMs = 320;
const double _kPopTextMs = 650;

/// Erken patlatma bonusu bu sure icinde verilir (ms).
const double _kEarlyBonusMs = 900;

enum BubbleKind { normal, small, gold, spike }

/// Ekranda yukselen tek bir baloncuk. Konumlar piksel cinsindendir.
class Bubble {
  final BubbleKind kind;
  final double radius;

  /// Ulasacagi sabit yukselme hizi (px/sn).
  final double riseSpeed;
  final double wobbleAmp;
  final double wobbleFreq;
  final double wobblePhase;

  double baseX;
  double y;
  double vx;
  double vy;
  double ageMs = 0;

  Bubble({
    required this.kind,
    required this.radius,
    required this.riseSpeed,
    required this.wobbleAmp,
    required this.wobbleFreq,
    required this.wobblePhase,
    required this.baseX,
    required this.y,
    required this.vx,
    required this.vy,
  });

  /// Ekrandaki gercek x: taban konum + yalpalanma. Yalpalanma ilk 400ms'de
  /// yavasca devreye girer ki baloncuk agizdan "sicramadan" ciksin.
  double get x {
    final ramp = min(1.0, ageMs / 400.0);
    return baseX + sin(ageMs / 1000.0 * wobbleFreq + wobblePhase) * wobbleAmp * ramp;
  }

  Offset get center => Offset(x, y);
}

/// Patlayan baloncugun kisa efekti (halka + damlacik + "+puan" yazisi).
class BubblePop {
  final Offset center;
  final double radius;
  final BubbleKind kind;
  final int gained;
  double ageMs = 0;

  BubblePop(this.center, this.radius, this.kind, this.gained);
}

class BubbleController extends MiniGameController {
  final Random _rng = Random();

  /// Sahneyi her karede yeniden cizdirmek icin. Butun ekrani (HUD dahil)
  /// yeniden kurmak yerine sadece CustomPaint bu sayaci dinler.
  final ValueNotifier<int> frame = ValueNotifier<int>(0);

  final List<Bubble> bubbles = [];
  final List<BubblePop> pops = [];

  /// Oyun alaninin piksel boyutu. Ekran, LayoutBuilder ile her kurulumda bildirir.
  Size field = Size.zero;

  /// Oyun saati: sadece oynanis sirasinda ilerler, menu acikken durur.
  double _playMs = 0;
  double _spawnInMs = 0;
  double _lastSpoutMs = -9999;
  Duration? _lastTick;
  int _shownSec = -1;

  int popped = 0;
  int escaped = 0;
  int spikeHits = 0;
  int goldPopped = 0;
  int emptyTaps = 0;

  int? _best;
  bool _newRecord = false;

  @override
  void resetState() {
    bubbles.clear();
    pops.clear();
    _playMs = 0;
    _spawnInMs = 250;
    _lastSpoutMs = -9999;
    _lastTick = null;
    _shownSec = -1;
    popped = 0;
    escaped = 0;
    spikeHits = 0;
    goldPopped = 0;
    emptyTaps = 0;
    frame.value++;
  }

  @override
  void onPlayStart() {
    _lastTick = null;
  }

  @override
  void onPause() {
    _lastTick = null;
  }

  /// Oyun saati yalnizca oynanis sirasinda ilerledigi icin duraklama suresini
  /// ayrica kaydirmaya gerek yok; menude beklemek avantaj saglamaz.
  @override
  void onResume(int pausedMs) {
    _lastTick = null;
  }

  // ------------------------------------------------------------------
  // Olculer
  // ------------------------------------------------------------------

  double get playMs => _playMs;

  /// 0..1 arasi ilerleme (zorluk bununla artar).
  double get progress => (_playMs / _kBubbleDurationMs).clamp(0.0, 1.0).toDouble();

  int get remainingSec => max(0, ((_kBubbleDurationMs - _playMs) / 1000).ceil());

  // ------------------------------------------------------------------
  // Balina geometrisi (ressam da ayni degerleri kullanir)
  // ------------------------------------------------------------------

  double get whaleWidth => (field.width * 0.30).clamp(84.0, 132.0).toDouble();
  double get whaleHeight => whaleWidth * 0.62;
  double get sandHeight => max(18.0, field.height * 0.055);

  double get _swimPhase => _playMs / 1000.0 * 0.85;

  /// Balina alt kisimda saga sola yuzer.
  double get whaleX {
    final w = field.width;
    final span = max(0.0, w / 2 - whaleWidth * 0.75);
    return w / 2 + sin(_swimPhase) * span;
  }

  bool get whaleFacingRight => cos(_swimPhase) >= 0;

  Offset get whaleCenter {
    final bob = sin(_playMs / 1000.0 * 3.2) * 3.0;
    return Offset(whaleX, field.height - sandHeight * 0.4 - whaleHeight / 2 + bob);
  }

  /// Baloncuklarin ciktigi nokta (balinanin puskurtme deligi).
  Offset get spoutPoint {
    final c = whaleCenter;
    final dir = whaleFacingRight ? 1.0 : -1.0;
    return Offset(c.dx + dir * whaleWidth * 0.12, c.dy - whaleHeight * 0.46);
  }

  /// Son puskurtmeden bu yana gecen oran (0..1 animasyon; >1 = bitti).
  double get spoutT => (_playMs - _lastSpoutMs) / 220.0;

  // ------------------------------------------------------------------
  // Kare dongusu
  // ------------------------------------------------------------------

  /// Ekrandaki Ticker her karede cagirir.
  void tick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (phase != MiniPhase.play || menuOpen || field.isEmpty) return;
    if (last == null || elapsed <= last) return;

    // Takilma sonrasi buyuk sicramalari engelle.
    final dtMs = min(50.0, (elapsed - last).inMicroseconds / 1000.0);
    _playMs += dtMs;

    _updateSpawns(dtMs);
    _updateBubbles(dtMs);
    _updatePops(dtMs);

    if (_playMs >= _kBubbleDurationMs) {
      _finishRun();
      return;
    }

    frame.value++;
    final sec = remainingSec;
    if (sec != _shownSec) {
      _shownSec = sec;
      safeNotify();
    }
  }

  void _updateSpawns(double dtMs) {
    _spawnInMs -= dtMs;
    if (_spawnInMs > 0) return;

    final p = progress;
    _spawnOne();
    // Oyun ilerledikce sik sik ikili puskurtme.
    if (p > 0.3 && _rng.nextDouble() < 0.22 + 0.25 * p) _spawnOne();

    // Puskurtme araligi 520ms -> 230ms'e iner.
    _spawnInMs = 520 - 290 * p + _rng.nextInt(120);
    _lastSpoutMs = _playMs;
  }

  void _spawnOne() {
    final p = progress;
    final unit = field.width;

    final spikeChance = _playMs < _kSpikeStartMs ? 0.0 : 0.14 + 0.10 * p;
    final goldChance = _playMs < _kGoldStartMs ? 0.0 : 0.06;
    final roll = _rng.nextDouble();

    final BubbleKind kind;
    if (roll < spikeChance) {
      kind = BubbleKind.spike;
    } else if (roll < spikeChance + goldChance) {
      kind = BubbleKind.gold;
    } else if (roll < spikeChance + goldChance + 0.24) {
      kind = BubbleKind.small;
    } else {
      kind = BubbleKind.normal;
    }

    final jitter = 0.9 + _rng.nextDouble() * 0.2;
    final (radius, speedMul) = switch (kind) {
      BubbleKind.small => (max(16.0, unit * 0.05) * jitter, 1.3),
      BubbleKind.gold => (unit * 0.068 * jitter, 1.15),
      BubbleKind.spike => (unit * 0.072 * jitter, 0.9),
      BubbleKind.normal => (unit * 0.075 * jitter, 1.0),
    };

    // Yukselme hizi alan yuksekligine gore; oyun ilerledikce hizlanir.
    final rise = field.height * (0.30 + 0.20 * p) * speedMul;
    final sp = spoutPoint;
    final dir = whaleFacingRight ? 1.0 : -1.0;

    bubbles.add(Bubble(
      kind: kind,
      radius: radius,
      riseSpeed: rise,
      wobbleAmp: unit * (0.02 + _rng.nextDouble() * 0.025),
      wobbleFreq: 2.5 + _rng.nextDouble() * 2.0,
      wobblePhase: _rng.nextDouble() * pi * 2,
      baseX: sp.dx,
      y: sp.dy - radius * 0.6,
      // Yelpaze gibi acilan yatay hiz + balinanin yuzdugu yone hafif egilim.
      vx: (_rng.nextDouble() * 2 - 1) * unit * 0.38 + dir * unit * 0.1,
      // Once hizli bir "fiskirma", sonra sabit yukselme hizina oturur.
      vy: -rise * 2.2,
    ));
  }

  void _updateBubbles(double dtMs) {
    final dt = dtMs / 1000.0;
    final w = field.width;
    final drag = exp(-2.1 * dt);
    final ease = min(1.0, dt * 4.5);

    for (var i = bubbles.length - 1; i >= 0; i--) {
      final b = bubbles[i];
      b.ageMs += dtMs;
      b.vx *= drag;
      b.vy += (-b.riseSpeed - b.vy) * ease;
      b.baseX += b.vx * dt;
      b.y += b.vy * dt;

      // Kenarlardan sek.
      final minX = b.radius;
      final maxX = w - b.radius;
      if (b.baseX < minX) {
        b.baseX = minX;
        b.vx = b.vx.abs();
      } else if (b.baseX > maxX) {
        b.baseX = maxX;
        b.vx = -b.vx.abs();
      }

      // Yukaridan cikip kacti.
      if (b.y + b.radius < 0) {
        bubbles.removeAt(i);
        if (b.kind != BubbleKind.spike) {
          escaped += 1;
          breakStreak();
        }
      }
    }
  }

  void _updatePops(double dtMs) {
    for (final fx in pops) {
      fx.ageMs += dtMs;
    }
    pops.removeWhere((fx) => fx.ageMs >= _kPopTextMs);
  }

  // ------------------------------------------------------------------
  // Dokunus
  // ------------------------------------------------------------------

  /// Oyun alanina dokunuldu. [pos] alanin sol ust kosesine gore piksel.
  void tapAt(Offset pos) {
    if (phase != MiniPhase.play || menuOpen) return;

    // Adil secim: dokunus hem iyi hem dikenli bir baloncuga denk geliyorsa
    // iyi olan patlar. Iyi baloncuklarda parmak toleransi genis; dikenlilerde
    // dar tutulur ki yanlislikla ceza yenmesin.
    Bubble? good;
    var goodScore = double.infinity;
    Bubble? spike;
    var spikeScore = double.infinity;

    for (final b in bubbles) {
      final isSpike = b.kind == BubbleKind.spike;
      final tolerance = isSpike ? b.radius : b.radius * 1.2 + 6;
      final d = (b.center - pos).distance;
      if (d > tolerance) continue;
      final score = d / tolerance;
      if (isSpike) {
        if (score < spikeScore) {
          spikeScore = score;
          spike = b;
        }
      } else if (score < goodScore) {
        goodScore = score;
        good = b;
      }
    }

    final target = good ?? spike;
    if (target == null) {
      // Bos dokunus: rastgele ekrana vurmayi caydirmak icin kucuk ceza.
      emptyTaps += 1;
      breakStreak();
      addPoints(-10);
      safeNotify();
      return;
    }
    _pop(target);
  }

  void _pop(Bubble b) {
    bubbles.remove(b);

    if (b.kind == BubbleKind.spike) {
      spikeHits += 1;
      breakStreak();
      pops.add(BubblePop(b.center, b.radius, b.kind, -150));
      addPoints(-150, label: 'Dikenli! −150', good: false);
      AudioManager.instance.playWrong();
      safeNotify();
      return;
    }

    popped += 1;
    bumpStreak();

    var gained = switch (b.kind) {
      BubbleKind.small => 80,
      BubbleKind.gold => 150,
      _ => 50,
    };
    if (b.kind == BubbleKind.gold) goldPopped += 1;

    // Erken patlatma bonusu: puskurtmeden sonraki ilk 900ms'de +30'a kadar.
    if (b.ageMs < _kEarlyBonusMs) {
      gained += ((_kEarlyBonusMs - b.ageMs) / _kEarlyBonusMs * 30).round();
    }

    String? label;
    if (streak >= 10 && streak % 10 == 0) {
      gained += streak == 10 ? 100 : 150;
      label = 'Seri x$streak! +$gained';
    } else if (b.kind == BubbleKind.gold) {
      label = 'Altın baloncuk! +$gained';
    }

    pops.add(BubblePop(b.center, b.radius, b.kind, gained));
    addPoints(gained, label: label);
    AudioManager.instance.playCorrect();
    safeNotify();
  }

  void _finishRun() {
    if (phase != MiniPhase.play) return;
    _playMs = _kBubbleDurationMs.toDouble();
    if (passed) {
      AudioManager.instance.playWin();
      final prev = _best;
      if (prev == null || points > prev) _best = points;
      _newRecord = prev != null && points > prev;
    } else {
      AudioManager.instance.playLose();
      _newRecord = false;
    }
    finish();
    frame.value++;
  }

  // ------------------------------------------------------------------
  // Sonuc
  // ------------------------------------------------------------------

  @override
  bool get passed => points >= _kBubbleTargetPoints;

  int get accuracy {
    final total = popped + escaped + spikeHits + emptyTaps;
    if (total == 0) return 0;
    return (popped / total * 100).round();
  }

  @override
  bool get isRecord => _newRecord;

  @override
  String get headlineLabel => passed ? 'Toplam puanın' : '$_kBubbleTargetPoints puana ulaşamadın';

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('PATLAYAN', '$popped'),
        MiniStat('İSABET', '%$accuracy'),
        MiniStat('EN UZUN SERİ', '$bestStreak'),
      ];

  @override
  String get verdict {
    if (points >= 4300) return 'Baloncuk ustası! Balina sana yetişemiyor.';
    if (spikeHits == 0 && accuracy >= 85) return 'Tertemiz oyun. Tek bir dikene bile dokunmadın.';
    if (bestStreak >= 20) return 'Müthiş seri! Ritmi hiç kaçırmadın.';
    return 'Hedefi geçtin! Baloncukları erken patlatırsan puanın katlanır.';
  }

  @override
  void dispose() {
    frame.dispose();
    super.dispose();
  }
}

// =============================================================================
// Ekran
// =============================================================================

class BubbleScreen extends StatefulWidget {
  final GameController app;
  const BubbleScreen({super.key, required this.app});

  @override
  State<BubbleScreen> createState() => _BubbleScreenState();
}

class _BubbleScreenState extends State<BubbleScreen> with SingleTickerProviderStateMixin {
  late final BubbleController _c;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _c = BubbleController();
    _c.onFinished = () => widget.app.reportModeResult(GameMode.bubble, _c.points, _c.passed);
    _ticker = createTicker(_c.tick);
    _c.addListener(_sync);
    _c.begin(skipIntro: widget.app.shouldSkipIntro(GameMode.bubble));
  }

  /// Ticker sadece oynanis sirasinda (ve menu kapaliyken) calisir; boylece
  /// tanitim/sonuc ekraninda bosuna kare uretilip pil harcanmaz.
  void _sync() {
    if (!mounted) return;
    final shouldRun = _c.phase == MiniPhase.play && !_c.menuOpen;
    if (shouldRun && !_ticker.isActive) {
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _c.removeListener(_sync);
    _ticker.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return MiniStage(
          mode: GameMode.bubble,
          controller: _c,
          onQuit: widget.app.backToModes,
          dontShowIntro: widget.app.shouldSkipIntro(GameMode.bubble),
          onDontShowIntroChanged: (v) => widget.app.setSkipIntro(GameMode.bubble, v),
          onRetry: () {
            if (widget.app.tryConsumePlayForRetry()) _c.begin(skipIntro: true);
          },
          hud: [
            HudPill(label: 'SÜRE', value: '${_c.remainingSec} sn', highlight: _c.remainingSec <= 5),
            HudPill(label: 'PUAN', value: '${_c.points}/$_kBubbleTargetPoints', highlight: true),
          ],
          child: _Tank(controller: _c),
        );
      },
    );
  }
}

class _Tank extends StatelessWidget {
  final BubbleController controller;
  const _Tank({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 22, offset: const Offset(0, 9)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, cons) {
            controller.field = Size(cons.maxWidth, cons.maxHeight);
            // Listener: jest arenasini beklemeden aninda tepki verir ve
            // ayni anda birden fazla parmagi destekler (refleks oyunu icin sart).
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => controller.tapAt(e.localPosition),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(cons.maxWidth, cons.maxHeight),
                  painter: _TankPainter(controller),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Cizim
// =============================================================================

class _TankPainter extends CustomPainter {
  final BubbleController c;
  _TankPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final t = c.playMs / 1000.0;
    _water(canvas, size, t);
    _seabed(canvas, size, t);
    _whale(canvas);
    for (final b in c.bubbles) {
      _bubble(canvas, b);
    }
    for (final fx in c.pops) {
      _pop(canvas, fx);
    }
  }

  @override
  bool shouldRepaint(covariant _TankPainter old) => old.c != c;

  // ---- arka plan -----------------------------------------------------------

  void _water(Canvas canvas, Size size, double t) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCFF3FF), Color(0xFF8ED6F5), Color(0xFF4AA8DA)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Yuzeyden inen yumusak isik huzmeleri.
    final rayRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.75);
    final ray = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.0)],
      ).createShader(rayRect);
    for (var i = 0; i < 3; i++) {
      final cx = size.width * (0.18 + i * 0.32) + sin(t * 0.6 + i) * size.width * 0.03;
      final topW = size.width * 0.07;
      final botW = size.width * 0.16;
      final shift = size.width * 0.06;
      final path = Path()
        ..moveTo(cx - topW / 2, 0)
        ..lineTo(cx + topW / 2, 0)
        ..lineTo(cx + botW / 2 + shift, rayRect.bottom)
        ..lineTo(cx - botW / 2 + shift, rayRect.bottom)
        ..close();
      canvas.drawPath(path, ray);
    }
  }

  void _seabed(Canvas canvas, Size size, double t) {
    final h = c.sandHeight;
    final top = size.height - h;

    // Deniz yosunlari (hafifce salinir).
    final weed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(5.0, size.width * 0.016)
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3FAE84);
    const spots = [0.07, 0.12, 0.88, 0.93];
    const heights = [0.16, 0.11, 0.13, 0.18];
    for (var i = 0; i < spots.length; i++) {
      final x = size.width * spots[i];
      final len = size.height * heights[i];
      final sway = sin(t * 1.6 + i * 1.3) * size.width * 0.018;
      final path = Path()
        ..moveTo(x, top + h * 0.3)
        ..quadraticBezierTo(x - sway * 1.5, top - len * 0.5, x + sway, top - len);
      canvas.drawPath(path, weed);
    }

    // Dalgali kum.
    final sand = Path()..moveTo(0, top + h * 0.2);
    const waves = 4;
    for (var i = 0; i < waves; i++) {
      final x0 = size.width * i / waves;
      final x1 = size.width * (i + 1) / waves;
      sand.quadraticBezierTo((x0 + x1) / 2, top - h * 0.25, x1, top + h * 0.2);
    }
    sand
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final rect = Rect.fromLTWH(0, top - h * 0.3, size.width, h * 1.3);
    canvas.drawPath(
      sand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE8B8), Color(0xFFE9C17E)],
        ).createShader(rect),
    );
  }

  // ---- balina --------------------------------------------------------------

  void _rotatedOval(Canvas canvas, Offset center, double w, double h, double angle, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: h), paint);
    canvas.restore();
  }

  /// Oyunun kendi karakteri: su puskurten minik balina. Yerel koordinatlarda
  /// kafa +x yonundedir; sola yuzerken ayna ile cevrilir.
  void _whale(Canvas canvas) {
    final w = c.whaleWidth;
    final h = c.whaleHeight;
    final center = c.whaleCenter;

    // Puskurturken hafifce basilip esner.
    final st = c.spoutT;
    final squash = (st >= 0 && st <= 1) ? sin(st * pi) : 0.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (!c.whaleFacingRight) canvas.scale(-1, 1);
    canvas.scale(1 + 0.05 * squash, 1 - 0.08 * squash);

    // Kuyruk sapi + yuzgecleri (govdenin arkasinda).
    const tailColor = Color(0xFF4AA6E3);
    final stem = Path()
      ..moveTo(-w * 0.28, h * 0.08)
      ..quadraticBezierTo(-w * 0.44, h * 0.02, -w * 0.46, -h * 0.34);
    canvas.drawPath(
      stem,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.3
        ..strokeCap = StrokeCap.round
        ..color = tailColor,
    );
    final fluke = Paint()..color = tailColor;
    _rotatedOval(canvas, Offset(-w * 0.54, -h * 0.5), w * 0.2, h * 0.17, 0.55, fluke);
    _rotatedOval(canvas, Offset(-w * 0.38, -h * 0.53), w * 0.2, h * 0.17, -0.55, fluke);

    // Govde
    final bodyRect = Rect.fromCenter(center: Offset(w * 0.05, 0), width: w * 0.86, height: h);
    canvas.drawOval(
      bodyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF86D4FF), Color(0xFF2F8FD6)],
        ).createShader(bodyRect),
    );

    // Karin + cizgiler + parlaklik (govdeye kirpilmis)
    canvas.save();
    canvas.clipPath(Path()..addOval(bodyRect));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.12, h * 0.34), width: w * 0.7, height: h * 0.55),
      Paint()..color = const Color(0xFFDDF4FF),
    );
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.035
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB5E2F8);
    for (var i = 0; i < 3; i++) {
      final y = h * (0.2 + i * 0.1);
      canvas.drawLine(Offset(-w * 0.05, y), Offset(w * 0.28, y), groove);
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-w * 0.02, -h * 0.28), width: w * 0.5, height: h * 0.22),
      Paint()..color = Colors.white.withOpacity(0.35),
    );
    canvas.restore();

    // Yan yuzgec
    _rotatedOval(canvas, Offset(0, h * 0.28), w * 0.2, h * 0.14, 0.6, Paint()..color = const Color(0xFF2F8FD6));

    // Goz
    final eye = Offset(w * 0.27, -h * 0.08);
    canvas.drawCircle(eye, h * 0.12, Paint()..color = Colors.white);
    canvas.drawCircle(eye + Offset(h * 0.02, h * 0.01), h * 0.075, Paint()..color = const Color(0xFF0B3550));
    canvas.drawCircle(eye + Offset(h * 0.045, -h * 0.03), h * 0.025, Paint()..color = Colors.white);

    // Yanak
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.3, h * 0.13), width: h * 0.2, height: h * 0.11),
      Paint()..color = const Color(0xFFFF9FC0).withOpacity(0.6),
    );

    // Gulumseme
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.4, h * 0.04), width: h * 0.2, height: h * 0.16),
      0.2,
      pi * 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.04
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF0B3550),
    );

    // Puskurtme deligi
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.12, -h * 0.44), width: w * 0.08, height: h * 0.05),
      Paint()..color = const Color(0xFF1F6FAE),
    );
    canvas.restore();

    // Su fiskirmasi (aynalama disinda cizilir ki damlalar dik yukselsin).
    if (st >= 0 && st <= 1) {
      final sp = c.spoutPoint;
      final fade = 1 - st;
      final drop = Paint()..color = Colors.white.withOpacity(0.75 * fade);
      for (var i = -1; i <= 1; i++) {
        final dx = i * h * 0.16 * st;
        final dy = -h * (0.15 + 0.35 * st) - (i == 0 ? h * 0.1 : 0.0);
        canvas.drawCircle(sp + Offset(dx, dy), h * 0.06 * (0.6 + 0.4 * fade), drop);
      }
    }
  }

  // ---- baloncuklar ---------------------------------------------------------

  void _bubble(Canvas canvas, Bubble b) {
    final c0 = b.center;
    // Cikarken kucukten buyuyerek belirsin.
    final rr = b.radius * min(1.0, 0.45 + b.ageMs / 220.0);
    final rect = Rect.fromCircle(center: c0, radius: rr);

    switch (b.kind) {
      case BubbleKind.spike:
        _spikeBubble(canvas, c0, rr, b.ageMs);
        return;
      case BubbleKind.gold:
        canvas.drawCircle(
          c0,
          rr,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.35),
              colors: [
                const Color(0xFFFFFCE6),
                const Color(0xFFFFDC6A).withOpacity(0.95),
                const Color(0xFFF2A900).withOpacity(0.95),
              ],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(rect),
        );
        canvas.drawCircle(
          c0,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = rr * 0.08
            ..color = const Color(0xFFFFF1B8),
        );
        _sparkle(canvas, c0 + Offset(rr * 0.55, -rr * 0.55), rr * 0.32, b.ageMs);
        break;
      case BubbleKind.normal:
      case BubbleKind.small:
        canvas.drawCircle(
          c0,
          rr,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.35),
              colors: [
                Colors.white.withOpacity(0.55),
                const Color(0xFFCDEFFF).withOpacity(0.25),
                const Color(0xFF6CC7EE).withOpacity(0.45),
              ],
              stops: const [0.0, 0.62, 1.0],
            ).createShader(rect),
        );
        // Gokkusagi yansimasi
        canvas.drawArc(
          Rect.fromCircle(center: c0, radius: rr * 0.82),
          0.2,
          1.3,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = rr * 0.1
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFFFB8E8).withOpacity(0.45),
        );
        canvas.drawCircle(
          c0,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.5, rr * 0.07)
            ..color = Colors.white.withOpacity(0.9),
        );
        break;
    }

    // Parlaklik
    canvas.drawOval(
      Rect.fromCenter(center: c0 + Offset(-rr * 0.36, -rr * 0.42), width: rr * 0.46, height: rr * 0.28),
      Paint()..color = Colors.white.withOpacity(0.9),
    );
    canvas.drawCircle(c0 + Offset(-rr * 0.05, -rr * 0.62), rr * 0.07, Paint()..color = Colors.white.withOpacity(0.85));
  }

  /// Altin baloncuktaki parildayan dort koseli yildiz.
  void _sparkle(Canvas canvas, Offset c0, double s, double ageMs) {
    final a = s * (0.75 + 0.25 * sin(ageMs / 1000.0 * 8));
    final path = Path()
      ..moveTo(c0.dx, c0.dy - a)
      ..quadraticBezierTo(c0.dx, c0.dy, c0.dx + a, c0.dy)
      ..quadraticBezierTo(c0.dx, c0.dy, c0.dx, c0.dy + a)
      ..quadraticBezierTo(c0.dx, c0.dy, c0.dx - a, c0.dy)
      ..quadraticBezierTo(c0.dx, c0.dy, c0.dx, c0.dy - a)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  /// Dokunulmamasi gereken dikenli, kizgin baloncuk.
  void _spikeBubble(Canvas canvas, Offset c0, double r, double ageMs) {
    const spikes = 10;
    final rot = ageMs / 1000.0 * 1.2;
    final half = pi / spikes * 0.55;
    final path = Path();
    for (var i = 0; i < spikes; i++) {
      final a = rot + i * 2 * pi / spikes;
      path
        ..moveTo(c0.dx + cos(a - half) * r * 0.9, c0.dy + sin(a - half) * r * 0.9)
        ..lineTo(c0.dx + cos(a) * r * 1.32, c0.dy + sin(a) * r * 1.32)
        ..lineTo(c0.dx + cos(a + half) * r * 0.9, c0.dy + sin(a + half) * r * 0.9)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFF3A2C7A));

    final rect = Rect.fromCircle(center: c0, radius: r);
    canvas.drawCircle(
      c0,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          colors: [Color(0xFFB3A4EC), Color(0xFF5B4AA8), Color(0xFF32256F)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c0 + Offset(-r * 0.3, -r * 0.5), width: r * 0.5, height: r * 0.24),
      Paint()..color = Colors.white.withOpacity(0.35),
    );

    // Kizgin gozler
    final eyeWhite = Paint()..color = Colors.white;
    final pupil = Paint()..color = const Color(0xFF1A1240);
    final brow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1A1240);
    for (final s in const [-1.0, 1.0]) {
      final e = c0 + Offset(s * r * 0.3, r * 0.04);
      canvas.drawCircle(e, r * 0.17, eyeWhite);
      canvas.drawCircle(e + Offset(0, r * 0.03), r * 0.085, pupil);
      canvas.drawLine(
        e + Offset(s * r * 0.2, -r * 0.3),
        e + Offset(-s * r * 0.14, -r * 0.16),
        brow,
      );
    }
  }

  // ---- patlama efekti ------------------------------------------------------

  void _pop(Canvas canvas, BubblePop fx) {
    final r = fx.radius;
    final Color tint = switch (fx.kind) {
      BubbleKind.spike => const Color(0xFF6B58C0),
      BubbleKind.gold => const Color(0xFFFFC832),
      _ => Colors.white,
    };

    // Halka + damlaciklar (kisa)
    final tr = fx.ageMs / _kPopRingMs;
    if (tr <= 1) {
      final fade = 1 - tr;
      canvas.drawCircle(
        fx.center,
        r * (1 + 0.55 * tr),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.5, r * 0.14 * fade)
          ..color = tint.withOpacity(0.9 * fade),
      );
      final drop = Paint()..color = tint.withOpacity(0.85 * fade);
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3 + 0.3;
        final d = r * (0.7 + 0.9 * tr);
        canvas.drawCircle(fx.center + Offset(cos(a) * d, sin(a) * d), max(0.5, r * 0.11 * fade), drop);
      }
    }

    // Kazanilan / kaybedilen puan yukari suzulur.
    final tt = (fx.ageMs / _kPopTextMs).clamp(0.0, 1.0).toDouble();
    final good = fx.gained > 0;
    final Color ink = !good
        ? AppColors.red
        : (fx.kind == BubbleKind.gold ? const Color(0xFF8A5A00) : const Color(0xFF0B4F6E));
    final tp = TextPainter(
      text: TextSpan(
        text: good ? '+${fx.gained}' : '${fx.gained}',
        style: baloo(max(14.0, r * 0.62), FontWeight.w800, ink.withOpacity(1 - tt)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, fx.center + Offset(-tp.width / 2, -r * 0.4 - 28 * tt - tp.height / 2));
    tp.dispose();
  }
}
