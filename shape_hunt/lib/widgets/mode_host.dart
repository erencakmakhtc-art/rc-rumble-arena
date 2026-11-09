import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../controllers/mini_base.dart';
import '../models/game_mode.dart';
import 'mini_kit.dart';

/// Bir mini bolum ekraninin ortak iskeleti.
///
/// Controller'i olusturur ve yok eder, bolum bitince skoru uygulamaya
/// bildirir, tanitim / geri sayim / sonuc / menu katmanlarini (MiniStage)
/// kurar. Bolum dosyalari yalnizca HUD'u ve oyun alanini tarif eder.
class ModeHost<T extends MiniGameController> extends StatefulWidget {
  final GameController app;
  final GameMode mode;

  /// Controller ureticisi (orn. `FruitSliceController.new`).
  final T Function() create;

  /// Siralamaya yazilacak deger (sure bazli bolumde ms, puan bazlida puan).
  final int Function(T c) score;

  final List<Widget> Function(T c) hud;
  final Widget Function(T c) body;

  const ModeHost({
    super.key,
    required this.app,
    required this.mode,
    required this.create,
    required this.score,
    required this.hud,
    required this.body,
  });

  @override
  State<ModeHost<T>> createState() => _ModeHostState<T>();
}

class _ModeHostState<T extends MiniGameController> extends State<ModeHost<T>> {
  late final T _c;

  @override
  void initState() {
    super.initState();
    _c = widget.create();
    _c.onFinished = () => widget.app.reportModeResult(widget.mode, widget.score(_c), _c.passed);
    _c.begin(skipIntro: widget.app.shouldSkipIntro(widget.mode));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final mode = widget.mode;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return MiniStage(
          mode: mode,
          controller: _c,
          onQuit: app.backToModes,
          dontShowIntro: app.shouldSkipIntro(mode),
          onDontShowIntroChanged: (v) => app.setSkipIntro(mode, v),
          onRetry: () {
            if (app.tryConsumePlayForRetry()) _c.begin(skipIntro: true);
          },
          hud: widget.hud(_c),
          child: widget.body(_c),
        );
      },
    );
  }
}
