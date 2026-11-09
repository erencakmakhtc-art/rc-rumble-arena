import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/arena_base.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/arena_view.dart';
import '../../widgets/mini_kit.dart';
import '../../widgets/mode_host.dart';

/// Gecme sarti: 20 saniyede (3 hata yapmadan) ulasilmasi gereken puan.
const int _kBeltTarget = 3500;

/// Bu kadar hatada oyun biter.
const int _kBeltMaxErrors = 3;

/// Kaydirmanin algilanmasi icin gereken dikey hareket (px).
const double _kBeltSwipePx = 22;

const List<String> _kBeltColorNames = ['KIRMIZI', 'MAVİ'];
const List<Color> _kBeltColors = [Color(0xFFE53935), Color(0xFF1E6FE0)];
const List<(Color, Color)> _kBeltShades = [
  (Color(0xFFFF8A80), Color(0xFFC62828)),
  (Color(0xFF90C2FF), Color(0xFF1250B8)),
];
const List<String> _kBeltShapeNames = ['DAİRE', 'KARE'];

class BeltItem {
  final int colorIdx;
  final int shapeIdx;
  double x;
  bool sorted = false;
  int dir = 0;
  double flyT = 0;
  bool correct = false;
  BeltItem(this.colorIdx, this.shapeIdx, this.x);
}

class SortBeltController extends ArenaGameController {
  final List<BeltItem> items = [];
  int errors = 0;
  int correctCount = 0;

  /// true: kural RENK, false: kural SEKIL.
  bool ruleIsColor = true;

  /// Ust kutuya giden renk ve sekil indeksleri.
  int topColor = 0;
  int topShape = 0;
  int _untilSwitch = 5;
  double ruleFlashMs = -9999;
  double _nextSpawn = 400;
  int switches = 0;

  final Map<int, Offset> _starts = {};
  final Set<int> _fired = {};

  double get itemR => field.width * 0.065;
  double get beltY => field.height * 0.5;

  /// Bir urunun bandi bastan sona gecme suresi 2,6 sn -> 1,7 sn.
  double get travelMs => 2600 - 900 * progress;
  double get speed => (field.width + itemR * 2) / travelMs * 1000;

  @override
  void resetArena() {
    items.clear();
    errors = 0;
    correctCount = 0;
    ruleIsColor = true;
    topColor = 0;
    topShape = 0;
    _untilSwitch = 5;
    ruleFlashMs = -9999;
    _nextSpawn = 400;
    switches = 0;
    _starts.clear();
    _fired.clear();
  }

  /// Siradaki (en onde, siniflanmamis) urun.
  BeltItem? get front {
    BeltItem? best;
    for (final it in items) {
      if (it.sorted) continue;
      if (best == null || it.x > best.x) best = it;
    }
    return best;
  }

  bool goesTop(BeltItem it) => ruleIsColor ? it.colorIdx == topColor : it.shapeIdx == topShape;

  @override
  void update(double dtMs) {
    final dt = dtMs / 1000;
    final p = progress;
    if (playMs >= _nextSpawn) {
      items.add(BeltItem(rng.nextInt(2), rng.nextInt(2), -itemR));
      // Urun araligi 0,95 sn -> 0,5 sn.
      _nextSpawn = playMs + 950 - 450 * p + rng.nextInt(80);
    }

    final v = speed;
    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i];
      if (it.sorted) {
        it.flyT += dt / 0.28;
        if (it.flyT >= 1) items.removeAt(i);
        continue;
      }
      it.x += v * dt;
      if (it.x - itemR * 0.5 > field.width) {
        items.removeAt(i);
        _error(Offset(field.width - 30, beltY - 40), 'Kaçtı!');
        if (phase != MiniPhase.play) return;
      }
    }
  }

  void _error(Offset at, String text) {
    errors += 1;
    breakStreak();
    addPoints(-150, label: '$text −150', good: false);
    addFloat(text, at, AppColors.red, size: 16);
    AudioManager.instance.playWrong();
    if (errors >= _kBeltMaxErrors) {
      endRun();
      return;
    }
    safeNotify();
  }

  void _sort(int dir) {
    if (phase != MiniPhase.play || menuOpen) return;
    final it = front;
    if (it == null) return;
    final wantDir = goesTop(it) ? -1 : 1;
    it.sorted = true;
    it.dir = dir;
    it.correct = dir == wantDir;
    if (it.correct) {
      correctCount += 1;
      bumpStreak();
      var gained = 100;
      // Erken karar bonusu: bandin ortasindan once siniflandir.
      if (it.x < field.width * 0.55) gained += 40;
      String? label;
      if (streak % 5 == 0) {
        gained += 50 + 50 * (streak ~/ 5);
        label = 'Seri x$streak! +$gained';
      }
      addPoints(gained, label: label);
      addFloat('+$gained', Offset(it.x, beltY - itemR * 1.8), AppColors.ink, size: 15);
      AudioManager.instance.playCorrect();
    } else {
      _error(Offset(it.x, beltY - itemR * 1.8), 'Yanlış kutu!');
      if (phase != MiniPhase.play) return;
    }

    _untilSwitch -= 1;
    if (_untilSwitch <= 0) _switchRule();
    safeNotify();
  }

  /// Kural degisir: bazen kategori (renk <-> sekil), her zaman kutu eslesmesi karisir.
  void _switchRule() {
    final oldColor = ruleIsColor;
    final oldTop = ruleIsColor ? topColor : topShape;
    if (rng.nextDouble() < 0.6) ruleIsColor = !ruleIsColor;
    topColor = rng.nextInt(2);
    topShape = rng.nextInt(2);
    // Hicbir sey degismemis olmasin.
    if (ruleIsColor == oldColor && (ruleIsColor ? topColor : topShape) == oldTop) {
      if (ruleIsColor) {
        topColor = 1 - topColor;
      } else {
        topShape = 1 - topShape;
      }
    }
    _untilSwitch = 3 + rng.nextInt(4);
    switches += 1;
    ruleFlashMs = playMs;
    showToast('KURAL DEĞİŞTİ!', ms: 700);
  }

  // ---- kaydirma algilama ----
  void down(int pointer, Offset pos) {
    _starts[pointer] = pos;
    _fired.remove(pointer);
  }

  void move(int pointer, Offset pos) {
    final s = _starts[pointer];
    if (s == null || _fired.contains(pointer)) return;
    final d = pos - s;
    if (d.dy.abs() < _kBeltSwipePx || d.dy.abs() < d.dx.abs()) return;
    _fired.add(pointer);
    _sort(d.dy < 0 ? -1 : 1);
  }

  void up(int pointer) {
    _starts.remove(pointer);
    _fired.remove(pointer);
  }

  @override
  bool get passed => errors < _kBeltMaxErrors && points >= _kBeltTarget;

  @override
  String get headlineLabel {
    if (passed) return 'Toplam puanın';
    if (errors >= _kBeltMaxErrors) return '$_kBeltMaxErrors hata yaptın';
    return '$_kBeltTarget puana ulaşamadın';
  }

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('DOĞRU', '$correctCount'),
        MiniStat('KURAL DEĞİŞİMİ', '$switches'),
        MiniStat('HATA', '$errors/$_kBeltMaxErrors'),
      ];

  @override
  String get verdict {
    if (errors == 0) return '$switches kural değişimine rağmen tek hata yok. Fabrika müdürü!';
    return 'Bant hiç durmadı ama sen yetiştin. Kural değişimlerine dikkat!';
  }
}

class SortBeltScreen extends StatelessWidget {
  final GameController app;
  const SortBeltScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<SortBeltController>(
      app: app,
      mode: GameMode.sortBelt,
      create: SortBeltController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SÜRE', value: '${c.remainingSec} sn', highlight: c.remainingSec <= 5),
        HudPill(label: 'HATA', value: '${c.errors}/$_kBeltMaxErrors', highlight: c.errors >= 2),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(
        controller: c,
        painter: _BeltPainter(c),
        onDown: c.down,
        onMove: c.move,
        onUp: c.up,
      ),
    );
  }
}

class _BeltPainter extends CustomPainter {
  final SortBeltController c;
  _BeltPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    paintPlayfield(canvas, size, const [Color(0xFFE8ECF7), Color(0xFFCBD2E8)]);
    if (size.isEmpty) return;
    final r = c.itemR;
    final by = c.beltY;
    final flash = (c.playMs - c.ruleFlashMs) < 700;

    // Kutular
    final topRect = Rect.fromLTRB(w * 0.18, h * 0.04, w * 0.82, h * 0.26);
    final botRect = Rect.fromLTRB(w * 0.18, h * 0.74, w * 0.82, h * 0.96);
    _bin(canvas, topRect, c.ruleIsColor, c.ruleIsColor ? c.topColor : c.topShape, true, flash);
    _bin(canvas, botRect, c.ruleIsColor, c.ruleIsColor ? 1 - c.topColor : 1 - c.topShape, false, flash);

    // Bant
    final belt = Rect.fromLTRB(0, by - r * 1.45, w, by + r * 1.45);
    canvas.drawRect(belt, Paint()..color = const Color(0xFF4A4F6B));
    canvas.save();
    canvas.clipRect(belt);
    final stripe = Paint()..color = Colors.white.withOpacity(0.08);
    final off = (c.playMs / 1000 * c.speed) % 28;
    for (var x = -28.0 + off; x < w + 28; x += 28) {
      canvas.drawPath(
        Path()
          ..moveTo(x, belt.bottom)
          ..lineTo(x + 12, belt.bottom)
          ..lineTo(x + 26, belt.top)
          ..lineTo(x + 14, belt.top)
          ..close(),
        stripe,
      );
    }
    canvas.restore();
    final rail = Paint()..color = const Color(0xFF2E3250);
    canvas.drawRect(Rect.fromLTWH(0, belt.top - 4, w, 4), rail);
    canvas.drawRect(Rect.fromLTWH(0, belt.bottom, w, 4), rail);

    // Kural rozeti
    final badge = Rect.fromLTWH(10, belt.top - 34, 128, 26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(13)),
      Paint()..color = flash ? const Color(0xFFFFD24D) : Colors.white,
    );
    paintLabel(canvas, c.ruleIsColor ? 'KURAL: RENK' : 'KURAL: ŞEKİL', badge.center, 13, AppColors.ink);

    // Yon oklari
    paintLabel(canvas, '▲', Offset(w - 22, belt.top - 18), 16, AppColors.inkMuted);
    paintLabel(canvas, '▼', Offset(w - 22, belt.bottom + 18), 16, AppColors.inkMuted);

    // Urunler
    final fr = c.front;
    final pulse = 0.5 + 0.5 * sin(c.playMs / 1000 * 10);
    for (final it in c.items) {
      if (it.sorted) {
        final target = it.dir < 0 ? topRect.center : botRect.center;
        final k = it.flyT.clamp(0.0, 1.0).toDouble();
        final pos = Offset.lerp(Offset(it.x, by), target, k)!;
        _item(canvas, pos, r * (1 - 0.5 * k), it);
        if (!it.correct) {
          paintLabel(canvas, '✗', pos, r * 1.2, AppColors.red);
        }
      } else {
        if (identical(it, fr)) {
          canvas.drawCircle(
            Offset(it.x, by),
            r * 1.3 + 3 * pulse,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFFFFD24D),
          );
        }
        _item(canvas, Offset(it.x, by), r, it);
      }
    }

    // Silindirler
    final roller = Paint()..color = const Color(0xFF8C92CD);
    canvas.drawCircle(Offset(0, by), r * 1.45, roller);
    canvas.drawCircle(Offset(w, by), r * 1.45, roller);

    if (c.playMs < 2500 && c.phase == MiniPhase.play) {
      paintLabel(canvas, 'Sarı halkalı ürünü yukarı/aşağı kaydır', Offset(w / 2, belt.bottom + 44), 14, AppColors.inkSoft);
    }
    paintFloats(canvas, c.floats);
  }

  void _item(Canvas canvas, Offset c0, double r, BeltItem it) {
    final (light, dark) = _kBeltShades[it.colorIdx];
    if (it.shapeIdx == 0) {
      paintGlossBall(canvas, c0, r, light, dark);
    } else {
      final rect = Rect.fromCenter(center: c0, width: r * 1.8, height: r * 1.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(r * 0.3)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [light, dark],
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + r * 0.25, rect.top + r * 0.2, r * 1.3, r * 0.35),
          Radius.circular(r * 0.15),
        ),
        Paint()..color = Colors.white.withOpacity(0.4),
      );
    }
  }

  void _bin(Canvas canvas, Rect rect, bool byColor, int idx, bool isTop, bool flash) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      Paint()..color = Colors.white.withOpacity(0.85),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = flash ? 4 : 2
        ..color = flash ? const Color(0xFFFFB300) : const Color(0xFF8C92CD),
    );
    final iconC = Offset(rect.left + rect.height * 0.5, rect.center.dy);
    final ir = rect.height * 0.24;
    final String name;
    if (byColor) {
      final (light, dark) = _kBeltShades[idx];
      paintGlossBall(canvas, iconC, ir, light, dark);
      name = _kBeltColorNames[idx];
    } else {
      final gray = const Color(0xFF6E739E);
      if (idx == 0) {
        canvas.drawCircle(iconC, ir, Paint()..color = gray);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: iconC, width: ir * 1.8, height: ir * 1.8), Radius.circular(ir * 0.3)),
          Paint()..color = gray,
        );
      }
      name = _kBeltShapeNames[idx];
    }
    paintLabel(
      canvas,
      '${isTop ? '▲ ' : '▼ '}$name',
      Offset(rect.left + rect.height + (rect.width - rect.height) / 2, rect.center.dy),
      18,
      byColor ? _kBeltColors[idx] : AppColors.ink,
    );
  }

  @override
  bool shouldRepaint(covariant _BeltPainter old) => old.c != c;
}
