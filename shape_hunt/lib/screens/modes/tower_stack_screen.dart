import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/arena_base.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../models/game_mode.dart';
import '../../widgets/arena_view.dart';
import '../../widgets/mini_kit.dart';
import '../../widgets/mode_host.dart';

/// Gecme sarti: bu kadar kat dikmek.
const int _kTowerFloors = 22;

/// Bu kadar yakin birakilan blok "mukemmel" sayilir, hic kirpilmaz (px).
const double _kPerfectPx = 4;

class TowerBlock {
  final double left;
  final double width;
  const TowerBlock(this.left, this.width);
}

class FallingPiece {
  final double width;
  final int level;
  double left;
  double drop = 0;
  double vy = 0;
  double rot = 0;
  final double spin;
  FallingPiece(this.left, this.width, this.level, this.spin);
}

class TowerStackController extends ArenaGameController {
  @override
  bool get timed => false;

  @override
  int get durationMs => 600000;

  final List<TowerBlock> blocks = [];
  final List<FallingPiece> pieces = [];

  /// Kayan blogun sol kenari ve yonu.
  double moveLeft = 0;
  double moveDir = 1;
  bool missed = false;
  bool completed = false;
  double endFx = 0;
  int perfects = 0;
  double perfectFlashMs = -9999;
  double camera = 0;

  double get blockH => field.height * 0.055;
  double get baseY => field.height * 0.86;
  int get floors => blocks.length - 1;

  /// Kayma hizi (px/sn): her katta artar.
  double get speed => field.width * (0.7 + 0.06 * floors);

  TowerBlock get top => blocks.last;

  @override
  void resetArena() {
    blocks.clear();
    pieces.clear();
    missed = false;
    completed = false;
    endFx = 0;
    perfects = 0;
    perfectFlashMs = -9999;
    camera = 0;
    moveLeft = 0;
    moveDir = 1;
  }

  void _ensureBase() {
    if (blocks.isNotEmpty) return;
    final w = field.width * 0.62;
    blocks.add(TowerBlock((field.width - w) / 2, w));
    _spawnMover();
  }

  void _spawnMover() {
    final w = top.width;
    // Bloklar sirayla soldan ve sagdan gelir.
    if (blocks.length.isEven) {
      moveLeft = -w * 0.35;
      moveDir = 1;
    } else {
      moveLeft = field.width - w * 0.65;
      moveDir = -1;
    }
  }

  @override
  void update(double dtMs) {
    _ensureBase();
    final dt = dtMs / 1000;

    for (final p in pieces) {
      p.vy += field.height * 2.4 * dt;
      p.drop += p.vy * dt;
      p.rot += p.spin * dt;
    }
    pieces.removeWhere((p) => p.drop > field.height * 1.2);

    final targetCam = max(0.0, (blocks.length - 7) * blockH);
    camera += (targetCam - camera) * min(1.0, dt * 6);

    if (missed || completed) {
      endFx += dtMs;
      if (endFx > (completed ? 500 : 800)) endRun();
      return;
    }

    _advance(dt);
  }

  void _advance(double dt) {
    final w = top.width;
    moveLeft += moveDir * speed * dt;
    final minL = -w * 0.35;
    final maxL = field.width - w * 0.65;
    if (moveLeft < minL) {
      moveLeft = minL;
      moveDir = 1;
    } else if (moveLeft > maxL) {
      moveLeft = maxL;
      moveDir = -1;
    }
  }

  void tap(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen || missed || completed || blocks.isEmpty) return;

    // Dokunus anina kadar (son kareden beri) gecen kaymayi da hesaba kat.
    final w = top.width;
    final extra = (nowMs - playMs) / 1000 * speed * moveDir;
    final left = (moveLeft + extra).clamp(-w * 0.35, field.width - w * 0.65).toDouble();

    final prev = top;
    final offset = left - prev.left;
    final level = blocks.length;

    if (offset.abs() < _kPerfectPx) {
      blocks.add(TowerBlock(prev.left, w));
      perfects += 1;
      perfectFlashMs = playMs;
      bumpStreak();
      final gained = 250;
      String? label;
      if (streak >= 3) label = 'Mükemmel x$streak!';
      addPoints(gained, label: label);
      addFloat('Mükemmel!', Offset(field.width / 2, _screenY(level) - blockH), const Color(0xFFFFF1C2), size: 18);
      AudioManager.instance.playCorrect();
    } else {
      final l = max(left, prev.left);
      final r = min(left + w, prev.left + prev.width);
      final overlap = r - l;
      if (overlap <= 0) {
        missed = true;
        pieces.add(FallingPiece(left, w, level, moveDir * 2));
        breakStreak();
        AudioManager.instance.playWrong();
        showToast('Kule yıkıldı!', good: false);
        safeNotify();
        return;
      }
      // Tasan kismi kes ve dusur.
      if (left < prev.left) {
        pieces.add(FallingPiece(left, prev.left - left, level, -2.5));
      } else {
        pieces.add(FallingPiece(prev.left + prev.width, left + w - (prev.left + prev.width), level, 2.5));
      }
      blocks.add(TowerBlock(l, overlap));
      breakStreak();
      addPoints(100);
      AudioManager.instance.playClick();
    }

    if (floors >= _kTowerFloors) {
      completed = true;
      showToast('Kule tamam!');
    } else {
      _spawnMover();
    }
    safeNotify();
  }

  /// Bir katin ekrandaki ust kenari.
  double _screenY(int level) => baseY - (level + 1) * blockH + camera;
  double screenY(int level) => _screenY(level);

  @override
  bool get passed => completed;

  @override
  String get headlineLabel => passed ? 'Toplam puanın' : 'Kule yıkıldı';

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('KAT', '$floors/$_kTowerFloors'),
        MiniStat('MÜKEMMEL', '$perfects'),
        MiniStat('SON GENİŞLİK', blocks.isEmpty ? '—' : '%${(top.width / (field.width * 0.62) * 100).round()}'),
      ];

  @override
  String get verdict {
    if (perfects >= 10) return '$perfects mükemmel bırakış! Mimar gibisin.';
    return 'Kuleyi zirveye taşıdın. Mükemmel bırakışlar kuleyi geniş tutar.';
  }
}

class TowerStackScreen extends StatelessWidget {
  final GameController app;
  const TowerStackScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<TowerStackController>(
      app: app,
      mode: GameMode.towerStack,
      create: TowerStackController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'KAT', value: '${max(0, c.floors)}/$_kTowerFloors', highlight: true),
        HudPill(label: 'MÜKEMMEL', value: '${c.perfects}'),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(controller: c, painter: _TowerPainter(c), onDown: c.tap),
    );
  }
}

class _TowerPainter extends CustomPainter {
  final TowerStackController c;
  _TowerPainter(this.c) : super(repaint: c.frame);

  /// Kat numarasina gore pastel renk (her katta ton kayar).
  Color _hue(int level, double v) =>
      HSVColor.fromAHSV(1, ((200 + level * 14) % 360).toDouble(), 0.45, v).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    // Gokyuzu yukseldikce gunduzden gun batimina gecer.
    final k = (max(0, c.floors) / _kTowerFloors).clamp(0.0, 1.0).toDouble();
    final top = Color.lerp(const Color(0xFFBFE6FF), const Color(0xFF6A5ACD), k)!;
    final bottom = Color.lerp(const Color(0xFFEAF6FF), const Color(0xFFFFB38A), k)!;
    paintPlayfield(canvas, size, [top, bottom]);

    final bh = c.blockH;
    // Zemin
    final groundTop = c.baseY + c.camera;
    if (groundTop < size.height) {
      canvas.drawRect(
        Rect.fromLTWH(0, groundTop, size.width, size.height - groundTop),
        Paint()..color = const Color(0xFF6FBF8E),
      );
    }

    for (var i = 0; i < c.blocks.length; i++) {
      final b = c.blocks[i];
      final y = c.screenY(i);
      if (y > size.height || y + bh < 0) continue;
      _block(canvas, Rect.fromLTWH(b.left, y, b.width, bh), i);
    }

    if (!c.missed && !c.completed && c.blocks.isNotEmpty) {
      final lvl = c.blocks.length;
      _block(canvas, Rect.fromLTWH(c.moveLeft, c.screenY(lvl), c.top.width, bh), lvl);
    }

    for (final p in c.pieces) {
      final y = c.screenY(p.level) + p.drop;
      canvas.save();
      canvas.translate(p.left + p.width / 2, y + bh / 2);
      canvas.rotate(p.rot);
      _block(canvas, Rect.fromCenter(center: Offset.zero, width: p.width, height: bh), p.level);
      canvas.restore();
    }

    final since = c.playMs - c.perfectFlashMs;
    if (since >= 0 && since < 300 && c.blocks.isNotEmpty) {
      final b = c.top;
      final y = c.screenY(c.blocks.length - 1);
      final kk = since / 300;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(b.left - 8 * kk, y - 8 * kk, b.width + 16 * kk, bh + 16 * kk),
          const Radius.circular(6),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withOpacity(1 - kk),
      );
    }
    paintFloats(canvas, c.floats);
  }

  void _block(Canvas canvas, Rect r, int level) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_hue(level, 0.98), _hue(level, 0.78)],
        ).createShader(r),
    );
    // Ust parlaklik seridi
    canvas.drawRect(
      Rect.fromLTWH(r.left + 3, r.top + 2, max(0.0, r.width - 6), r.height * 0.22),
      Paint()..color = Colors.white.withOpacity(0.4),
    );
  }

  @override
  bool shouldRepaint(covariant _TowerPainter old) => old.c != c;
}
