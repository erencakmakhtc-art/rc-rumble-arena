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

/// Tus basina puan.
const int _kTilePoints = 20;

class TileRow {
  final List<int> cols;
  final Set<int> tapped = {};
  final Map<int, double> tapAt = {};
  double y;
  TileRow(this.y, this.cols);
  bool get done => tapped.length >= cols.length;
}

class TileRushController extends ArenaGameController {
  final List<TileRow> rows = [];
  int tiles = 0;
  bool failed = false;
  double endFx = 0;
  TileRow? failRow;
  int? failCol;
  bool failWasWrong = false;
  bool _needInit = true;
  int _lastCol = -1;

  double get rowH => field.height / 4.5;
  double get colW => field.width / 4;

  /// Saniyedeki satir sayisi 2,0 -> 3,8.
  double get rowsPerSec => 2.0 + 1.8 * progress;
  double get speed => rowH * rowsPerSec;

  @override
  void resetArena() {
    rows.clear();
    tiles = 0;
    failed = false;
    endFx = 0;
    failRow = null;
    failCol = null;
    failWasWrong = false;
    _needInit = true;
    _lastCol = -1;
  }

  List<int> _newCols() {
    // Ayni kolonu arka arkaya vermemeye calis (parmak ritmi bozulsun).
    var col = rng.nextInt(4);
    if (col == _lastCol) col = (col + 1 + rng.nextInt(3)) % 4;
    _lastCol = col;
    // 8. saniyeden sonra bazen ayni satirda iki tus.
    if (playMs > 8000 && rng.nextDouble() < 0.15) {
      var second = rng.nextInt(4);
      while (second == col) {
        second = rng.nextInt(4);
      }
      return [col, second];
    }
    return [col];
  }

  void _init() {
    final h = field.height;
    for (var k = 0; k < 6; k++) {
      rows.add(TileRow(h - rowH * (3 + k), _newCols()));
    }
  }

  @override
  void update(double dtMs) {
    if (_needInit) {
      _init();
      _needInit = false;
    }
    if (failed) {
      endFx += dtMs;
      if (endFx > 800) endRun();
      return;
    }
    final dy = speed * dtMs / 1000;
    for (final r in rows) {
      r.y += dy;
    }
    while (rows.isEmpty || rows.last.y > -rowH * 0.02) {
      final y = rows.isEmpty ? -rowH : rows.last.y - rowH;
      rows.add(TileRow(y, _newCols()));
    }
    for (final r in rows) {
      if (!r.done && r.y > field.height - rowH * 0.25) {
        failed = true;
        failRow = r;
        failCol = r.cols.firstWhere((c) => !r.tapped.contains(c));
        failWasWrong = false;
        breakStreak();
        AudioManager.instance.playWrong();
        showToast('Tuşu kaçırdın!', good: false);
        safeNotify();
        return;
      }
    }
    rows.removeWhere((r) => r.y > field.height);
  }

  void tap(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen || failed || rows.isEmpty) return;
    final col = (pos.dx / colW).floor().clamp(0, 3);
    TileRow? row;
    for (final r in rows) {
      if (pos.dy >= r.y && pos.dy < r.y + rowH) {
        row = r;
        break;
      }
    }
    if (row == null) return;
    if (row.cols.contains(col)) {
      if (row.tapped.contains(col)) return;
      row.tapped.add(col);
      row.tapAt[col] = playMs;
      tiles += 1;
      bumpStreak();
      var gained = _kTilePoints;
      String? label;
      if (streak % 25 == 0) {
        gained += 100;
        label = 'Seri x$streak! +$gained';
      }
      addPoints(gained, label: label);
      AudioManager.instance.playClick();
      safeNotify();
    } else {
      failed = true;
      failRow = row;
      failCol = col;
      failWasWrong = true;
      breakStreak();
      AudioManager.instance.playWrong();
      showToast('Yanlış tuş!', good: false);
      safeNotify();
    }
  }

  @override
  bool get passed => !failed && playMs >= durationMs;

  @override
  String get headlineLabel {
    if (passed) return 'Toplam puanın';
    return failWasWrong ? 'Yanlış tuşa bastın' : 'Bir tuşu kaçırdın';
  }

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('TUŞ', '$tiles'),
        MiniStat('SON HIZ', '${rowsPerSec.toStringAsFixed(1)}/sn'),
        MiniStat('SÜRE', '${(playMs / 1000).toStringAsFixed(1)} sn'),
      ];

  @override
  String get verdict {
    if (tiles >= 65) return '$tiles tuş, tek hata yok. Parmakların uçuyor!';
    return 'Tek hata yapmadan 20 saniye! Ritmi hiç kaçırmadın.';
  }
}

class TileRushScreen extends StatelessWidget {
  final GameController app;
  const TileRushScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<TileRushController>(
      app: app,
      mode: GameMode.tileRush,
      create: TileRushController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SÜRE', value: '${c.remainingSec} sn', highlight: c.remainingSec <= 5),
        HudPill(label: 'TUŞ', value: '${c.tiles}'),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(controller: c, painter: _TilePainter(c), onDown: c.tap),
    );
  }
}

class _TilePainter extends CustomPainter {
  final TileRushController c;
  _TilePainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    paintPlayfield(canvas, size, const [Color(0xFFFFFFFF), Color(0xFFEEF0FB)]);
    final cw = size.width / 4;
    final rh = c.rowH;

    final sep = Paint()
      ..color = const Color(0xFFD5D9EE)
      ..strokeWidth = 1.5;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(cw * i, 0), Offset(cw * i, size.height), sep);
    }

    final blink = (sin(c.playMs / 1000 * 22) > 0);
    for (final r in c.rows) {
      if (r.y > size.height || r.y + rh < 0) continue;
      for (final col in r.cols) {
        final rect = Rect.fromLTWH(col * cw + 2, r.y + 2, cw - 4, rh - 4);
        final isFail = c.failed && identical(r, c.failRow) && c.failCol == col && !c.failWasWrong;
        if (r.tapped.contains(col)) {
          // Basilmis tus: acik renk + dalga
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..color = const Color(0xFFDCE0F4));
          final age = c.playMs - (r.tapAt[col] ?? c.playMs);
          if (age < 260) {
            final k = age / 260;
            canvas.drawCircle(
              rect.center,
              cw * 0.2 + cw * 0.45 * k,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4 * (1 - k)
                ..color = AppColors.ink.withOpacity(1 - k),
            );
          }
        } else {
          final colors = isFail && blink
              ? const [Color(0xFFFF8A8A), Color(0xFFD9303A)]
              : const [Color(0xFF4D5288), Color(0xFF1C1F3F)];
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(8)),
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ).createShader(rect),
          );
          canvas.drawLine(
            Offset(rect.left + 8, rect.top + 6),
            Offset(rect.right - 8, rect.top + 6),
            Paint()
              ..color = Colors.white.withOpacity(0.25)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // Yanlis basilan beyaz kare kirmizi yanar.
    final fr = c.failRow;
    final fc = c.failCol;
    if (c.failed && c.failWasWrong && fr != null && fc != null && blink) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(fc * cw + 2, fr.y + 2, cw - 4, rh - 4), const Radius.circular(8)),
        Paint()..color = AppColors.red.withOpacity(0.75),
      );
    }

    // Ilk saniyelerde ipucu
    if (c.playMs < 1800 && c.phase == MiniPhase.play) {
      paintLabel(canvas, 'Koyu tuşlara dokun, beyaza değil!', Offset(size.width / 2, size.height * 0.08), 15, AppColors.inkSoft);
    }
    paintFloats(canvas, c.floats);
  }

  @override
  bool shouldRepaint(covariant _TilePainter old) => old.c != c;
}
