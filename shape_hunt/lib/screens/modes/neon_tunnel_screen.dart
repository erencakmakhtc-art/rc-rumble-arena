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

/// Parmak kaldirildiktan sonra geri koymak icin taninan sure (ms).
const double _kTunnelLiftGraceMs = 200;

/// Parmagin duvardan uzak durmasi gereken pay (px).
const double _kTunnelFingerPad = 6;

const Color _kNeonCyan = Color(0xFF3DF2FF);
const Color _kNeonPink = Color(0xFFFF4FD8);

class NeonTunnelController extends ArenaGameController {
  /// Kayan toplam mesafe (px). Ekranin alt kenari bu dunya noktasina denk gelir.
  double dist = 0;
  Offset? finger;
  int? _pointer;
  bool needFinger = true;
  bool started = false;
  double? _liftedAt;
  bool hit = false;
  bool lifted = false;
  double endFx = 0;
  String prompt = 'Parmağını tünelin içine koy';
  final Set<int> taken = {};
  int orbs = 0;
  double _pointAcc = 0;

  @override
  bool get waiting => needFinger;

  /// Kayma hizi (px/sn): 0,35H -> 0,8H.
  double get speed => field.height * (0.35 + 0.45 * progress);
  double get orbGap => field.height * 0.55;

  double _k(double d) => (d / (field.height * 9)).clamp(0.0, 1.0).toDouble();

  /// Tunel merkezinin x konumu (dunya mesafesine gore). Ilerledikce daha cok kivrilir.
  double centerAt(double d) {
    final w = field.width;
    final k = _k(d);
    return w / 2 + w * (0.10 + 0.20 * k) * sin(d * 0.0042 + 0.7) + w * 0.08 * k * sin(d * 0.011);
  }

  /// Tunelin yari genisligi: 0,17W -> 0,07W.
  double halfAt(double d) => field.width * (0.17 - 0.10 * _k(d));

  double worldAtY(double y) => dist + (field.height - y);
  double screenYOf(double d) => field.height - (d - dist);

  bool _inside(Offset p) {
    final d = worldAtY(p.dy);
    return (p.dx - centerAt(d)).abs() < halfAt(d) - _kTunnelFingerPad;
  }

  @override
  void resetArena() {
    dist = 0;
    finger = null;
    _pointer = null;
    needFinger = true;
    started = false;
    _liftedAt = null;
    hit = false;
    lifted = false;
    endFx = 0;
    prompt = 'Parmağını tünelin içine koy';
    taken.clear();
    orbs = 0;
    _pointAcc = 0;
  }

  @override
  void onResume(int pausedMs) {
    super.onResume(pausedMs);
    if (_pointer == null && started && !hit && !lifted) {
      needFinger = true;
      _liftedAt = null;
      prompt = 'Parmağını tünele geri koy';
    }
  }

  @override
  void update(double dtMs) {
    if (hit || lifted) {
      endFx += dtMs;
      if (endFx > 500) endRun();
      return;
    }
    final la = _liftedAt;
    if (la != null && playMs - la > _kTunnelLiftGraceMs) {
      lifted = true;
      AudioManager.instance.playWrong();
      showToast('Parmağını kaldırdın!', good: false);
      safeNotify();
      return;
    }

    dist += speed * dtMs / 1000;
    _pointAcc += dtMs;
    while (_pointAcc >= 100) {
      _pointAcc -= 100;
      addPoints(10);
    }

    final f = finger;
    if (f == null || _pointer == null) return;
    if (!_inside(f)) {
      hit = true;
      breakStreak();
      AudioManager.instance.playWrong();
      showToast('Duvara değdin!', good: false);
      safeNotify();
      return;
    }

    // Enerji kureleri: tunelin ortasinda duzenli araliklarla.
    final first = (dist / orbGap).floor();
    for (var i = first; i < first + 4; i++) {
      if (taken.contains(i)) continue;
      final od = (i + 1) * orbGap;
      final o = Offset(centerAt(od), screenYOf(od));
      if ((o - f).distance < 28) {
        taken.add(i);
        orbs += 1;
        bumpStreak();
        addPoints(50);
        addFloat('+50', o, _kNeonCyan, size: 16);
        AudioManager.instance.playClick();
      }
    }
  }

  void down(int pointer, Offset pos) {
    if (phase != MiniPhase.play || menuOpen || hit || lifted || _pointer != null) return;
    if (!_inside(pos)) {
      if (needFinger) {
        prompt = 'Tünelin İÇİNE koy!';
        safeNotify();
      }
      return;
    }
    _pointer = pointer;
    finger = pos;
    _liftedAt = null;
    if (needFinger) {
      needFinger = false;
      started = true;
      safeNotify();
    }
  }

  void move(int pointer, Offset pos) {
    if (pointer != _pointer) return;
    finger = pos;
  }

  void up(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    if (started && !needFinger && !hit && !lifted && phase == MiniPhase.play) _liftedAt = playMs;
  }

  @override
  bool get passed => started && !hit && !lifted && playMs >= durationMs;

  @override
  String get headlineLabel {
    if (passed) return 'Toplam puanın';
    if (lifted) return 'Parmağını kaldırdın';
    return 'Duvara değdin';
  }

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('SÜRE', '${(playMs / 1000).toStringAsFixed(1)} sn'),
        MiniStat('KÜRE', '$orbs'),
        MiniStat('MESAFE', '${(dist / 100).round()} m'),
      ];

  @override
  String get verdict {
    if (orbs >= 15) return '$orbs küre topladın, duvarlara hiç değmedin. Işık hızı!';
    return 'Daralan tünelden sağ çıktın. Küreleri toplamak puanı katlar.';
  }
}

class NeonTunnelScreen extends StatelessWidget {
  final GameController app;
  const NeonTunnelScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<NeonTunnelController>(
      app: app,
      mode: GameMode.neonTunnel,
      create: NeonTunnelController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SÜRE', value: '${c.remainingSec} sn', highlight: c.remainingSec <= 5),
        HudPill(label: 'KÜRE', value: '${c.orbs}'),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(
        controller: c,
        painter: _TunnelPainter(c),
        onDown: c.down,
        onMove: c.move,
        onUp: c.up,
      ),
    );
  }
}

class _TunnelPainter extends CustomPainter {
  final NeonTunnelController c;
  _TunnelPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    paintPlayfield(canvas, size, const [Color(0xFF120B2E), Color(0xFF2A1459)]);

    // Kayan izgara (hiz hissi)
    final grid = Paint()
      ..color = const Color(0xFF6B4FD8).withOpacity(0.18)
      ..strokeWidth = 1;
    final off = c.dist % 40;
    for (var y = off - 40; y < h; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // Tunel duvarlarini ornekle
    final left = <Offset>[];
    final right = <Offset>[];
    for (var y = -10.0; y <= h + 10; y += 8) {
      final d = c.worldAtY(y);
      final cx = c.centerAt(d);
      final hw = c.halfAt(d);
      left.add(Offset(cx - hw, y));
      right.add(Offset(cx + hw, y));
    }
    final body = Path()..addPolygon([...left, ...right.reversed], true);
    canvas.drawPath(body, Paint()..color = const Color(0xFF1B0F3F).withOpacity(0.85));

    final lp = Path()..addPolygon(left, false);
    final rp = Path()..addPolygon(right, false);
    for (final (path, color) in [(lp, _kNeonCyan), (rp, _kNeonPink)]) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = color.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color,
      );
    }

    // Enerji kureleri
    final first = (c.dist / c.orbGap).floor();
    final pulse = 0.75 + 0.25 * sin(c.playMs / 1000 * 8);
    for (var i = first; i < first + 4; i++) {
      if (c.taken.contains(i)) continue;
      final od = (i + 1) * c.orbGap;
      final y = c.screenYOf(od);
      if (y < -20 || y > h + 20) continue;
      final o = Offset(c.centerAt(od), y);
      canvas.drawCircle(
        o,
        14 * pulse,
        Paint()
          ..color = const Color(0xFFFFF27A).withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(o, 6, Paint()..color = const Color(0xFFFFF9C4));
    }

    // Parmak
    final f = c.finger;
    if (f != null && !c.needFinger) {
      canvas.drawCircle(
        f,
        18,
        Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        f,
        10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = c.hit ? const Color(0xFFFF6B6B) : Colors.white,
      );
    }

    if (c.needFinger && c.phase == MiniPhase.play) {
      // Baslangic noktasi isareti
      final y = h * 0.82;
      final p = Offset(c.centerAt(c.worldAtY(y)), y);
      canvas.drawCircle(
        p,
        16 + 6 * pulse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withOpacity(0.8),
      );
      paintPrompt(canvas, size, c.prompt);
    }
    if (c.hit || c.lifted) {
      final k = (c.endFx / 500).clamp(0.0, 1.0).toDouble();
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF4FD8).withOpacity(0.35 * (1 - k)));
    }
    paintFloats(canvas, c.floats);
  }

  @override
  bool shouldRepaint(covariant _TunnelPainter old) => old.c != c;
}
