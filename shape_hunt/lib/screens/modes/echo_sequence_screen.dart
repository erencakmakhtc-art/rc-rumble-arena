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

/// Gecme sarti: bu seviyeyi tamamlamak (seviye n'de dizi uzunlugu n+2).
const int _kEchoLevels = 6;

/// Disk bu seviyeden itibaren gosterimden sonra doner.
const int _kEchoRotateFrom = 3;

/// Bu seviyeden itibaren bazen dizi TERS sirayla istenir.
const int _kEchoReverseFrom = 5;

/// Her basis icin taninan sure (ms).
const double _kEchoPressMs = 2500;

const List<Color> _kPadColors = [
  Color(0xFFFF5A5A),
  Color(0xFF4DA3FF),
  Color(0xFF5BD68A),
  Color(0xFFFFD24D),
];

enum EchoStage { banner, show, rotate, input, success, fail }

class EchoSequenceController extends ArenaGameController {
  @override
  bool get timed => false;

  @override
  int get durationMs => 600000;

  int level = 0;
  List<int> seq = [];
  bool reverse = false;
  EchoStage stage = EchoStage.banner;
  double stageMs = 0;
  int? lit;
  double litUntil = 0;

  /// Diskin ceyrek tur cinsinden donuklugu (pad konumlari buna gore kayar).
  int quarter = 0;
  int _fromQ = 0;
  int _toQ = 0;

  int inputIdx = 0;
  double _pressDeadline = 0;
  bool completed = false;
  int? failPad;
  int presses = 0;

  double get onMs => 480 - 35.0 * (level - 1);
  static const double gapMs = 120;

  /// Diskin anlik donus acisi (radyan).
  double get angle {
    if (stage == EchoStage.rotate) {
      final k = (stageMs / 550).clamp(0.0, 1.0).toDouble();
      final e = k < 0.5 ? 2 * k * k : 1 - (-2 * k + 2) * (-2 * k + 2) / 2;
      return (_fromQ + (_toQ - _fromQ) * e) * pi / 2;
    }
    return quarter * pi / 2;
  }

  int expectedAt(int i) => reverse ? seq[seq.length - 1 - i] : seq[i];

  @override
  void resetArena() {
    level = 0;
    quarter = 0;
    completed = false;
    presses = 0;
    failPad = null;
    _nextLevel();
  }

  void _go(EchoStage s) {
    stage = s;
    stageMs = 0;
    safeNotify();
  }

  void _nextLevel() {
    level += 1;
    // Her seviyede tamamen yeni bir dizi (ezber birikmez).
    seq = List<int>.generate(level + 2, (_) => rng.nextInt(4));
    reverse = level >= _kEchoReverseFrom && rng.nextDouble() < 0.4;
    lit = null;
    inputIdx = 0;
    _go(EchoStage.banner);
  }

  @override
  void update(double dtMs) {
    stageMs += dtMs;
    switch (stage) {
      case EchoStage.banner:
        if (stageMs >= 950) _go(EchoStage.show);
      case EchoStage.show:
        final slot = onMs + gapMs;
        final idx = (stageMs / slot).floor();
        if (idx >= seq.length) {
          lit = null;
          if (level >= _kEchoRotateFrom) {
            _fromQ = quarter;
            _toQ = quarter + const [1, 2, -1][rng.nextInt(3)];
            _go(EchoStage.rotate);
          } else {
            _beginInput();
          }
        } else {
          final on = stageMs - idx * slot < onMs;
          final next = on ? seq[idx] : null;
          if (next != lit) {
            lit = next;
            if (next != null) AudioManager.instance.playClick();
          }
        }
      case EchoStage.rotate:
        if (stageMs >= 550) {
          quarter = _toQ;
          _beginInput();
        }
      case EchoStage.input:
        if (lit != null && playMs > litUntil) lit = null;
        if (playMs > _pressDeadline) _fail(expectedAt(inputIdx));
      case EchoStage.success:
        if (lit != null && playMs > litUntil) lit = null;
        if (stageMs >= 750) {
          if (level >= _kEchoLevels) {
            completed = true;
            endRun();
          } else {
            _nextLevel();
          }
        }
      case EchoStage.fail:
        if (stageMs >= 1000) endRun();
    }
  }

  void _beginInput() {
    inputIdx = 0;
    _pressDeadline = playMs + _kEchoPressMs;
    _go(EchoStage.input);
  }

  void _fail(int pad) {
    failPad = pad;
    breakStreak();
    AudioManager.instance.playWrong();
    _go(EchoStage.fail);
  }

  Offset get center => Offset(field.width / 2, field.height * 0.5);
  double get outerR => min(field.width, field.height) * 0.42;
  double get innerR => outerR * 0.46;

  void tap(int pointer, Offset pos) {
    if (stage != EchoStage.input || phase != MiniPhase.play || menuOpen) return;
    final v = pos - center;
    final r = v.distance;
    if (r < innerR * 0.7 || r > outerR * 1.15) return;
    // Saat yonunde, yukaridan olculen aci; diskin donuklugu cikarilir.
    var a = atan2(v.dx, -v.dy);
    a -= quarter * pi / 2;
    a %= 2 * pi;
    if (a < 0) a += 2 * pi;
    final pad = (a / (pi / 2)).floor().clamp(0, 3);

    lit = pad;
    litUntil = playMs + 180;
    if (pad == expectedAt(inputIdx)) {
      inputIdx += 1;
      presses += 1;
      bumpStreak();
      addPoints(20 * level);
      AudioManager.instance.playClick();
      _pressDeadline = playMs + _kEchoPressMs;
      if (inputIdx >= seq.length) {
        addPoints(100 * level, label: 'Seviye $level tamam! +${100 * level}');
        AudioManager.instance.playCorrect();
        _go(EchoStage.success);
      } else {
        safeNotify();
      }
    } else {
      _fail(expectedAt(inputIdx));
    }
  }

  @override
  bool get passed => completed;

  @override
  String get headlineLabel => passed ? 'Toplam puanın' : 'Diziyi kaçırdın';

  @override
  String get headlineValue => '$points';

  @override
  List<MiniStat> get stats => [
        MiniStat('SEVİYE', '${completed ? level : level - 1}/$_kEchoLevels'),
        MiniStat('EN UZUN', '${completed ? seq.length : max(0, seq.length - 1)}'),
        MiniStat('DOĞRU BASIŞ', '$presses'),
      ];

  @override
  String get verdict => 'Dönen diske ve ters sıralara rağmen hatasız! Hafızan çelik gibi.';
}

class EchoSequenceScreen extends StatelessWidget {
  final GameController app;
  const EchoSequenceScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<EchoSequenceController>(
      app: app,
      mode: GameMode.echoSequence,
      create: EchoSequenceController.new,
      score: (c) => c.points,
      hud: (c) => [
        HudPill(label: 'SEVİYE', value: '${max(1, c.level)}/$_kEchoLevels', highlight: true),
        HudPill(label: 'DİZİ', value: '${c.seq.length}'),
        HudPill(label: 'PUAN', value: '${c.points}', highlight: true),
      ],
      body: (c) => ArenaView(controller: c, painter: _EchoPainter(c), onDown: c.tap),
    );
  }
}

class _EchoPainter extends CustomPainter {
  final EchoSequenceController c;
  _EchoPainter(this.c) : super(repaint: c.frame);

  @override
  void paint(Canvas canvas, Size size) {
    paintPlayfield(canvas, size, const [Color(0xFF1E1B4B), Color(0xFF0F0D2B)]);
    if (size.isEmpty) return;
    final ctr = c.center;
    final ro = c.outerR;
    final ri = c.innerR;
    canvas.drawCircle(
      ctr,
      ro * 1.3,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF6B5BFF).withOpacity(0.25), Colors.transparent],
        ).createShader(Rect.fromCircle(center: ctr, radius: ro * 1.3)),
    );

    // Dort pad (disk aciyla doner)
    final mid = (ro + ri) / 2;
    final thick = ro - ri;
    const gap = 0.08;
    for (var i = 0; i < 4; i++) {
      final start = -pi / 2 + i * pi / 2 + c.angle + gap / 2;
      final rect = Rect.fromCircle(center: ctr, radius: mid);
      final on = c.lit == i;
      final failHint = c.stage == EchoStage.fail && c.failPad == i && (c.stageMs % 300) < 150;
      final col = _kPadColors[i];
      if (on || failHint) {
        canvas.drawArc(
          rect,
          start,
          pi / 2 - gap,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = thick + 14
            ..color = col.withOpacity(0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }
      canvas.drawArc(
        rect,
        start,
        pi / 2 - gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thick
          ..color = (on || failHint) ? col : col.withOpacity(0.28),
      );
    }

    // Merkez
    canvas.drawCircle(ctr, ri * 0.82, Paint()..color = const Color(0xFF15123A));
    canvas.drawCircle(
      ctr,
      ri * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.2),
    );
    final label = switch (c.stage) {
      EchoStage.banner => 'SEVİYE ${c.level}',
      EchoStage.show => 'İZLE',
      EchoStage.rotate => 'DÖNÜYOR',
      EchoStage.input => '${c.inputIdx}/${c.seq.length}',
      EchoStage.success => 'TAMAM!',
      EchoStage.fail => 'HATA',
    };
    paintLabel(canvas, label, ctr + const Offset(0, -6), ri * 0.3, Colors.white);
    if (c.reverse && c.stage != EchoStage.fail) {
      paintLabel(canvas, 'TERS SIRA', ctr + Offset(0, ri * 0.32), ri * 0.19, const Color(0xFFFFD24D));
    }

    // Donme oklari
    if (c.stage == EchoStage.rotate) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.6);
      canvas.drawArc(Rect.fromCircle(center: ctr, radius: ro + 16), c.angle - 0.6, 1.2, false, p);
      canvas.drawArc(Rect.fromCircle(center: ctr, radius: ro + 16), c.angle + pi - 0.6, 1.2, false, p);
    }

    if (c.stage == EchoStage.banner && c.reverse) {
      paintLabel(canvas, 'Bu sefer TERSTEN gir!', Offset(size.width / 2, size.height * 0.08), 18, const Color(0xFFFFD24D));
    } else if (c.stage == EchoStage.banner && c.level == _kEchoRotateFrom) {
      paintLabel(canvas, 'Disk dönecek: renkleri takip et!', Offset(size.width / 2, size.height * 0.08), 16, Colors.white);
    }
    paintFloats(canvas, c.floats);
  }

  @override
  bool shouldRepaint(covariant _EchoPainter old) => old.c != c;
}
