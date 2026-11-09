import 'dart:math';

import 'package:flutter/material.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/trial_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';
import '../../widgets/mode_host.dart';
import '../../widgets/trial_kit.dart';

/// Gecme sarti: 20 saniyede (3 hata yapmadan) ulasilmasi gereken puan.
const int _kMirrorTarget = 1500;

/// Kiral (aynasi kendisinden farkli) besli bloklar: F, L, N, P, Y, Z.
const List<List<(int, int)>> _kPieces = [
  [(1, 0), (2, 0), (0, 1), (1, 1), (1, 2)], // F
  [(0, 0), (0, 1), (0, 2), (0, 3), (1, 3)], // L
  [(0, 0), (0, 1), (1, 1), (1, 2), (1, 3)], // N
  [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2)], // P
  [(1, 0), (0, 1), (1, 1), (1, 2), (1, 3)], // Y
  [(0, 0), (1, 0), (1, 1), (1, 2), (2, 2)], // Z
];

const List<(Color, Color)> _kPieceColors = [
  (Color(0xFFFFB3D8), Color(0xFFD9437F)),
  (Color(0xFFBFE0FF), Color(0xFF1E6FE0)),
  (Color(0xFFC8F5A8), Color(0xFF3F9A1C)),
  (Color(0xFFFFE0A8), Color(0xFFE08A00)),
  (Color(0xFFDED3FF), Color(0xFF7446C8)),
];

typedef Cells = List<(int, int)>;

Cells _normalize(Cells cells) {
  final minX = cells.map((c) => c.$1).reduce(min);
  final minY = cells.map((c) => c.$2).reduce(min);
  final out = [for (final c in cells) (c.$1 - minX, c.$2 - minY)];
  out.sort((a, b) => a.$2 != b.$2 ? a.$2 - b.$2 : a.$1 - b.$1);
  return out;
}

Cells _rotate(Cells cells, int quarters) {
  var out = cells;
  for (var i = 0; i < quarters % 4; i++) {
    out = [for (final c in out) (c.$2, -c.$1)];
  }
  return _normalize(out);
}

Cells _mirror(Cells cells) => _normalize([for (final c in cells) (-c.$1, c.$2)]);

String _key(Cells cells) => _normalize(cells).map((c) => '${c.$1},${c.$2}').join(';');

class MirrorTrapController extends TrialGameController {
  Cells target = const [];
  List<Cells> options = const [];
  int answerIndex = 0;
  int colorIdx = 0;
  int? pickedIndex;

  @override
  int get targetPoints => _kMirrorTarget;

  @override
  int get fastMs => 1500;

  /// Cevap penceresi 3,2 sn'den 2,2 sn'ye daralir.
  @override
  int trialWindowMs(double progress) => (3200 - 1000 * progress).round();

  @override
  void resetTrialState() {
    target = const [];
    options = const [];
    pickedIndex = null;
  }

  @override
  void buildTrial() {
    pickedIndex = null;
    colorIdx = rng.nextInt(_kPieceColors.length);
    final shapeIdx = rng.nextInt(_kPieces.length);
    var base = _normalize(_kPieces[shapeIdx]);
    if (rng.nextBool()) base = _mirror(base);
    target = _rotate(base, rng.nextInt(4));

    // Dogru cevap: hedefin DONDURULMUS hali (hic dondurulmemis olamaz).
    final correct = _rotate(target, 1 + rng.nextInt(3));
    final used = <String>{_key(correct), _key(target)};
    final opts = <Cells>[correct];

    // Tuzaklar: hedefin AYNASI, farkli acilarda (en az iki tane).
    final mirrored = _mirror(target);
    final rots = [0, 1, 2, 3]..shuffle(rng);
    for (final r in rots) {
      if (opts.length >= 3) break;
      final m = _rotate(mirrored, r);
      if (used.add(_key(m))) opts.add(m);
    }
    // Bir tane de baska bir parca (ya da aynasi).
    var guard = 0;
    while (opts.length < 4 && guard < 40) {
      guard += 1;
      final other = rng.nextInt(_kPieces.length);
      if (other == shapeIdx) continue;
      var o = _normalize(_kPieces[other]);
      if (rng.nextBool()) o = _mirror(o);
      o = _rotate(o, rng.nextInt(4));
      if (used.add(_key(o))) opts.add(o);
    }

    final order = List<int>.generate(opts.length, (i) => i)..shuffle(rng);
    options = [for (final i in order) opts[i]];
    answerIndex = order.indexOf(0);
  }

  void pick(int i) {
    if (!acceptingInput || i >= options.length) return;
    pickedIndex = i;
    answer(i == answerIndex);
  }

  @override
  String get verdict {
    if (errors == 0 && avgReactionMs < 1200) return 'Zihninde şekilleri döndürmek senin için oyun. Muhteşem!';
    if (errors == 0) return 'Aynalara bir kez bile kanmadın!';
    return 'Tuzaklara rağmen geçtin. Ayna görüntüsü ne kadar döndürülse de aynı olmaz!';
  }
}

class MirrorTrapScreen extends StatelessWidget {
  final GameController app;
  const MirrorTrapScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<MirrorTrapController>(
      app: app,
      mode: GameMode.mirrorTrap,
      create: MirrorTrapController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(
          label: 'SÜRE',
          value: (c.remainingMs / 1000).toStringAsFixed(1),
          highlight: c.remainingMs < 5000,
        ),
        HudPill(label: 'HATA', value: '${c.errors}/${c.maxErrors}', highlight: c.errors >= 2),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) {
        final (light, dark) = _kPieceColors[c.colorIdx];
        Widget option(int i) {
          if (i >= c.options.length) return const Expanded(child: SizedBox(height: 104));
          return Expanded(
            child: TrialChoice(
              height: 104,
              state: choiceStateOf(
                picked: c.pickedIndex == i,
                isAnswer: i == c.answerIndex,
                feedback: c.feedback,
              ),
              onDown: () => c.pick(i),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PiecePainter(c.options[i], light, dark),
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            const Spacer(),
            TrialCard(
              feedback: c.feedback,
              height: 150,
              child: c.target.isEmpty
                  ? Text('HAZIR', style: baloo(30, FontWeight.w800, AppColors.inkFaint))
                  : Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: CustomPaint(
                              size: Size.infinite,
                              painter: _PiecePainter(c.target, light, dark),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Text(
                            'Hangisi\naynı şekil?',
                            textAlign: TextAlign.right,
                            style: baloo(15, FontWeight.w800, AppColors.inkMuted, height: 1.2),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            TrialWindowBar(value: c.target.isEmpty ? 1.0 : c.windowLeft),
            const Spacer(),
            Row(children: [option(0), const SizedBox(width: 10), option(1)]),
            const SizedBox(height: 10),
            Row(children: [option(2), const SizedBox(width: 10), option(3)]),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}

class _PiecePainter extends CustomPainter {
  final Cells cells;
  final Color light;
  final Color dark;
  _PiecePainter(this.cells, this.light, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;
    final cols = cells.map((c) => c.$1).reduce(max) + 1;
    final rows = cells.map((c) => c.$2).reduce(max) + 1;
    final cell = min(size.width / cols, size.height / rows);
    final ox = (size.width - cell * cols) / 2;
    final oy = (size.height - cell * rows) / 2;
    for (final c in cells) {
      final r = Rect.fromLTWH(ox + c.$1 * cell + 1.5, oy + c.$2 * cell + 1.5, cell - 3, cell - 3);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.22));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [light, dark],
          ).createShader(r),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left + r.width * 0.15, r.top + r.height * 0.12, r.width * 0.7, r.height * 0.22),
          Radius.circular(cell * 0.1),
        ),
        Paint()..color = Colors.white.withOpacity(0.45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PiecePainter old) => old.cells != cells || old.dark != dark;
}
