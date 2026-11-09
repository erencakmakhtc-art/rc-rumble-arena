import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../data/color_defs.dart';
import '../../data/pairs.dart';
import '../../data/shape_defs.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';
import '../../widgets/mode_host.dart';
import '../../widgets/shape_view.dart';

const int _kMemCols = 5;
const int _kMemPairs = 10;

/// Gecme sarti: 10 cifti bu surenin altinda bulmak.
const int _kMemPassMs = 21000;

/// Guvenlik ust siniri.
const int _kMemLimitMs = 90000;

/// Yanlis eslesmenin acik kalma suresi (ms).
const int _kMemShowMs = 450;

/// Her bu kadar yanlis eslesmede iki kapali kart yer degistirir.
const int _kMemSwapEvery = 4;

/// Bilerek birbirine benzeyen yuzler: 5 sekil x 2 yakin renk (mavi / mor).
const List<ShapePair> _kMemFaces = [
  ShapePair(ShapeKind.star5, ShapeColorKey.blue),
  ShapePair(ShapeKind.hex, ShapeColorKey.blue),
  ShapePair(ShapeKind.diamond, ShapeColorKey.blue),
  ShapePair(ShapeKind.triangle, ShapeColorKey.blue),
  ShapePair(ShapeKind.circle, ShapeColorKey.blue),
  ShapePair(ShapeKind.star5, ShapeColorKey.violet),
  ShapePair(ShapeKind.hex, ShapeColorKey.violet),
  ShapePair(ShapeKind.diamond, ShapeColorKey.violet),
  ShapePair(ShapeKind.triangle, ShapeColorKey.violet),
  ShapePair(ShapeKind.circle, ShapeColorKey.violet),
];

class MemCard {
  final ShapePair face;
  bool up = false;
  bool matched = false;
  MemCard(this.face);
}

class MemoryCardsController extends MiniGameController {
  final Random _rng = Random();

  List<MemCard> cards = [];
  final List<int> _open = [];

  int matches = 0;
  int mismatches = 0;
  int flips = 0;
  int elapsedMs = 0;
  bool timedOut = false;

  /// Az once yer degistiren iki kartin konumu (kisa sure vurgulanir).
  Set<int> swapped = {};
  bool _pendingSwap = false;

  DateTime? _startedAt;
  Timer? _tick;
  Timer? _hideTimer;
  int? _bestMs;
  bool _newRecord = false;

  bool get finishedAll => matches >= _kMemPairs;

  /// Bitiremeyen oyuncu siralamaya kisa sure yazamasin.
  int get recordMs => finishedAll ? elapsedMs : _kMemLimitMs;

  @override
  int? get resultScore => finishedAll ? elapsedMs : null;

  @override
  void resetState() {
    cards = [
      for (final f in _kMemFaces) MemCard(f),
      for (final f in _kMemFaces) MemCard(f),
    ]..shuffle(_rng);
    _open.clear();
    matches = 0;
    mismatches = 0;
    flips = 0;
    elapsedMs = 0;
    timedOut = false;
    swapped = {};
    _pendingSwap = false;
    _startedAt = null;
    _tick?.cancel();
    _hideTimer?.cancel();
  }

  @override
  void onPlayStart() {
    _startedAt = DateTime.now();
    _startTick();
    safeNotify();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = own(Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (phase != MiniPhase.play || menuOpen || _startedAt == null) return;
      elapsedMs = DateTime.now().difference(_startedAt!).inMilliseconds;
      if (elapsedMs >= _kMemLimitMs) {
        elapsedMs = _kMemLimitMs;
        timedOut = true;
        _finishRun();
        return;
      }
      safeNotify();
    }));
  }

  /// Menude gecen sure sayilmaz; iptal edilen zamanlayicilar toparlanir.
  @override
  void onResume(int pausedMs) {
    if (_startedAt != null) {
      _startedAt = _startedAt!.add(Duration(milliseconds: pausedMs));
    }
    swapped = {};
    if (_open.length == 2) _hide();
    _startTick();
  }

  void tap(int i) {
    if (phase != MiniPhase.play || menuOpen) return;
    if (cards[i].matched || cards[i].up) return;

    // Hizli oyuncu: acik yanlis cift beklemeden kapanir.
    if (_open.length == 2) _hide(keep: i);

    final card = cards[i];
    card.up = true;
    flips += 1;
    _open.add(i);

    if (_open.length == 2) {
      final a = cards[_open[0]];
      final b = cards[_open[1]];
      if (a.face == b.face) {
        a.matched = true;
        b.matched = true;
        matches += 1;
        _open.clear();
        bumpStreak();
        AudioManager.instance.playCorrect();
        if (finishedAll) {
          _finishRun();
          return;
        }
      } else {
        mismatches += 1;
        breakStreak();
        if (mismatches % _kMemSwapEvery == 0) _pendingSwap = true;
        _hideTimer?.cancel();
        _hideTimer = own(Timer(const Duration(milliseconds: _kMemShowMs), _hide));
      }
    } else {
      AudioManager.instance.playClick();
    }
    safeNotify();
  }

  void _hide({int? keep}) {
    _hideTimer?.cancel();
    for (final i in _open) {
      cards[i].up = false;
    }
    _open.clear();
    if (_pendingSwap) {
      _pendingSwap = false;
      _swapTwo(keep);
    }
    safeNotify();
  }

  /// Iki kapali karti yer degistirir ve konumlarini kisa sure vurgular.
  void _swapTwo(int? keep) {
    final idx = [
      for (var i = 0; i < cards.length; i++)
        if (!cards[i].matched && !cards[i].up && i != keep) i,
    ]..shuffle(_rng);
    if (idx.length < 2) return;
    final a = idx[0];
    final b = idx[1];
    final t = cards[a];
    cards[a] = cards[b];
    cards[b] = t;
    swapped = {a, b};
    showToast('2 kart yer değiştirdi!', good: false, ms: 900);
    own(Timer(const Duration(milliseconds: 900), () {
      swapped = {};
      safeNotify();
    }));
  }

  void _finishRun() {
    if (phase != MiniPhase.play) return;
    _tick?.cancel();
    _hideTimer?.cancel();
    if (_startedAt != null && !timedOut) {
      elapsedMs = DateTime.now().difference(_startedAt!).inMilliseconds;
    }
    if (passed) {
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

  @override
  bool get passed => finishedAll && elapsedMs <= _kMemPassMs;

  @override
  bool get isRecord => _newRecord;

  @override
  String get headlineLabel {
    if (passed) return 'Bitirme süren';
    if (finishedAll) return '${_kMemPassMs ~/ 1000} sn sınırını aştın';
    return 'Süre doldu';
  }

  @override
  String get headlineValue =>
      finishedAll ? '${(elapsedMs / 1000).toStringAsFixed(2)} sn' : '$matches/$_kMemPairs';

  @override
  List<MiniStat> get stats => [
        MiniStat('EŞLEŞME', '$matches/$_kMemPairs'),
        MiniStat('YANLIŞ', '$mismatches'),
        MiniStat('ÇEVİRME', '$flips'),
      ];

  @override
  String get verdict {
    if (mismatches <= 6) return 'Fotoğraf gibi hafıza! Neredeyse hiç yanılmadın.';
    if (elapsedMs < 16000) return 'Işık hızında eşleştirdin. Harika!';
    return 'Tüm çiftleri buldun! Daha az yanlışla kartlar yer değiştirmez.';
  }
}

class MemoryCardsScreen extends StatelessWidget {
  final GameController app;
  const MemoryCardsScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ModeHost<MemoryCardsController>(
      app: app,
      mode: GameMode.memoryCards,
      create: MemoryCardsController.new,
      score: (c) => c.recordMs,
      hud: (c) => [
        HudPill(label: 'ÇİFT', value: '${c.matches}/$_kMemPairs', highlight: true),
        HudPill(
          label: 'SÜRE',
          value: (c.elapsedMs / 1000).toStringAsFixed(1),
          highlight: c.elapsedMs > _kMemPassMs,
        ),
        HudPill(label: 'YANLIŞ', value: '${c.mismatches}'),
      ],
      body: (c) => Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.75), width: 2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(0.32), Colors.white.withOpacity(0.14)],
            ),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _kMemCols,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              childAspectRatio: 0.78,
            ),
            itemCount: c.cards.length,
            itemBuilder: (context, i) {
              final card = c.cards[i];
              return RepaintBoundary(
                child: _MemTile(
                  card: card,
                  highlight: c.swapped.contains(i),
                  onDown: () => c.tap(i),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MemTile extends StatelessWidget {
  final MemCard card;
  final bool highlight;
  final VoidCallback onDown;

  const _MemTile({required this.card, required this.highlight, required this.onDown});

  @override
  Widget build(BuildContext context) {
    final showFace = card.up || card.matched;
    return Listener(
      onPointerDown: (_) => onDown(),
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: showFace ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 160),
        builder: (context, v, _) {
          final front = v >= 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(v * pi),
            child: front
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: _face(),
                  )
                : _back(),
          );
        },
      ),
    );
  }

  Widget _face() {
    return Opacity(
      opacity: card.matched ? 0.55 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: card.matched ? const Color(0xFF3FBF6A) : Colors.white,
            width: card.matched ? 3 : 2,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFEFF1FF)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final s = min(box.maxWidth, box.maxHeight) * 0.62;
            return Center(child: ShapeView(pair: card.face, size: s));
          },
        ),
      ),
    );
  }

  Widget _back() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? const Color(0xFFFFB300) : Colors.white.withOpacity(0.9),
          width: highlight ? 4 : 2,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C84D4), Color(0xFF3F4478)],
        ),
        boxShadow: highlight
            ? [BoxShadow(color: const Color(0xFFFFB300).withOpacity(0.6), blurRadius: 12)]
            : null,
      ),
      alignment: Alignment.center,
      child: Text('?', style: baloo(24, FontWeight.w800, Colors.white.withOpacity(0.85))),
    );
  }
}
