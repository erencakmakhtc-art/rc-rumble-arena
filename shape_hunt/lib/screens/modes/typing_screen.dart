import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/mini_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';

/// Bolumu bitirmek icin sure siniri.
const int _kTypingLimitMs = 20000;

/// Her biri 8 satirlik 3 farkli Ingilizce hikaye. Her oyunda rastgele biri
/// secilir ve oyuncu satir satir yazar.
const List<List<String>> _kStories = [
  [
    'the old lighthouse stood alone on the cliff',
    'every night its light swept across the dark sea',
    'a young sailor watched it from his small boat',
    'the waves were rough but he was not afraid',
    'he followed the light all the way to the shore',
    'an old keeper welcomed him with a warm smile',
    'they shared bread and stories until the morning',
    'the sailor never forgot that kind and quiet night',
  ],
  [
    'in a busy city there lived a curious little cat',
    'it loved to climb the roofs and watch the people',
    'one day it found a tiny bird with a broken wing',
    'the cat did not chase it but stayed close instead',
    'each morning it brought the bird food and water',
    'slowly the little bird grew strong enough to fly',
    'when it finally rose into the bright blue sky',
    'the cat watched proudly from the old red roof',
  ],
  [
    'deep in the green forest there was a hidden lake',
    'its water was so clear you could see the stones',
    'a group of children found it on a summer day',
    'they built a small raft from branches and ropes',
    'all afternoon they floated under the tall trees',
    'birds sang above them and fish swam far below',
    'as the sun set they promised to return again',
    'that lake became their secret for many happy years',
  ],
];

class TypingController extends MiniGameController {
  final Random _rng = Random();

  late List<String> lines;
  int index = 0;
  String input = '';
  bool lastWrong = false;
  int mistakes = 0;

  DateTime? _startedAt;
  int elapsedMs = 0;
  bool timedOut = false;
  Timer? _tick;
  int _typedChars = 0;
  int? _bestMs;
  bool _newRecord = false;

  @override
  void resetState() {
    lines = List<String>.from(_kStories[_rng.nextInt(_kStories.length)]);
    index = 0;
    input = '';
    lastWrong = false;
    mistakes = 0;
    elapsedMs = 0;
    timedOut = false;
    _typedChars = 0;
    _startedAt = null;
    _tick?.cancel();
  }

  @override
  void onPlayStart() {
    _startedAt = DateTime.now();
    _startTick();
    safeNotify();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (phase != MiniPhase.play) return;
      elapsedMs = DateTime.now().difference(_startedAt!).inMilliseconds;
      if (elapsedMs >= _kTypingLimitMs) {
        elapsedMs = _kTypingLimitMs;
        timedOut = true;
        _finishRun();
        return;
      }
      safeNotify();
    });
    own(_tick!);
  }

  /// Duraklatma suresi yazma suresine eklenmemeli.
  /// Menu acilinca sayac iptal edildigi icin burada yeniden kurulur; aksi
  /// halde sure donar ve 20 sn siniri hic dolmazdi.
  @override
  void onResume(int pausedMs) {
    if (_startedAt != null) {
      _startedAt = _startedAt!.add(Duration(milliseconds: pausedMs));
    }
    _startTick();
  }

  String get currentPhrase => lines[index.clamp(0, lines.length - 1)];
  int get remainingMs => (_kTypingLimitMs - elapsedMs).clamp(0, _kTypingLimitMs);

  /// Butun hikaye bitti mi (sure dolmadan).
  @override
  bool get passed => index >= lines.length && !timedOut;

  @override
  int? get resultScore => passed ? elapsedMs : null;

  /// Yazilan metni normalize eder.
  String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  void setInput(String v) {
    input = v;
    if (lastWrong) lastWrong = false;
    safeNotify();
  }

  /// Enter'a basildiginda cagrilir.
  void submit() {
    if (phase != MiniPhase.play) return;

    if (_norm(input) == _norm(currentPhrase)) {
      _typedChars += currentPhrase.length;
      AudioManager.instance.playCorrect();
      index += 1;
      input = '';
      lastWrong = false;
      if (index >= lines.length) {
        elapsedMs = DateTime.now().difference(_startedAt!).inMilliseconds;
        _finishRun();
        return;
      }
      safeNotify();
    } else {
      mistakes += 1;
      lastWrong = true;
      AudioManager.instance.playWrong();
      safeNotify();
    }
  }

  void _finishRun() {
    _tick?.cancel();
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

  /// Dakikada kelime.
  int get wpm {
    if (elapsedMs <= 0) return 0;
    final minutes = elapsedMs / 60000.0;
    if (minutes <= 0) return 0;
    return ((_typedChars / 5) / minutes).round();
  }

  @override
  bool get isRecord => _newRecord;

  @override
  String get headlineLabel => passed ? 'Bitirme süren' : 'Süre doldu';

  @override
  String get headlineValue =>
      passed ? '${(elapsedMs / 1000).toStringAsFixed(1)} sn' : '$index/${lines.length} satır';

  @override
  List<MiniStat> get stats => [
        MiniStat('SATIR', '$index/${lines.length}'),
        MiniStat('HIZ', '$wpm KDD'),
        MiniStat('HATA', '$mistakes'),
      ];

  @override
  String get verdict {
    if (!passed) return '20 saniyede bitiremedin. Hız için iki elini kullanmayı dene!';
    if (mistakes == 0) return 'Hem hızlı hem hatasız. Etkileyici.';
    if (wpm >= 45) return 'Parmakların uçuyor.';
    if (mistakes > 4) return 'Bitirdin! Daha az hatayla süren düşer.';
    return 'Güzel iş. Pratikle daha da hızlanırsın.';
  }
}

class TypingScreen extends StatefulWidget {
  final GameController app;
  const TypingScreen({super.key, required this.app});

  @override
  State<TypingScreen> createState() => _TypingScreenState();
}

class _TypingScreenState extends State<TypingScreen> {
  late final TypingController _c;
  late final TextEditingController _text;
  late final FocusNode _focus;
  MiniPhase _lastPhase = MiniPhase.intro;
  int _lastIndex = 0;
  bool _lastMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _c = TypingController();
    _c.onFinished = () => widget.app.reportModeResult(GameMode.typing, _c.elapsedMs, _c.passed);
    _text = TextEditingController();
    _focus = FocusNode();
    _c.addListener(_sync);
    _c.begin(skipIntro: widget.app.shouldSkipIntro(GameMode.typing));
  }

  /// Controller durumu degistiginde metin kutusunu ve klavye odagini esitler.
  void _sync() {
    if (!mounted) return;

    // Yeni cumleye gecildiyse kutuyu temizle.
    if (_c.index != _lastIndex) {
      _lastIndex = _c.index;
      if (_text.text.isNotEmpty) _text.clear();
    }

    // Menu (cikis onayi) acikken klavye kapali kalmali.
    if (_c.menuOpen) {
      if (_focus.hasFocus) _focus.unfocus();
      _lastMenuOpen = true;
      return;
    }
    if (_lastMenuOpen) {
      _lastMenuOpen = false;
      if (_c.phase == MiniPhase.play) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _c.phase == MiniPhase.play && !_c.menuOpen) _focus.requestFocus();
        });
      }
    }

    // Oynanis basladiginda klavyeyi ac, bitince kapat.
    if (_c.phase != _lastPhase) {
      _lastPhase = _c.phase;
      if (_c.phase == MiniPhase.play) {
        _text.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _c.phase == MiniPhase.play && !_c.menuOpen) _focus.requestFocus();
        });
      } else {
        _focus.unfocus();
      }
    }
  }

  @override
  void dispose() {
    _c.removeListener(_sync);
    _c.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return MiniStage(
          mode: GameMode.typing,
          controller: _c,
          onQuit: widget.app.backToModes,
          dontShowIntro: widget.app.shouldSkipIntro(GameMode.typing),
          onDontShowIntroChanged: (v) => widget.app.setSkipIntro(GameMode.typing, v),
          onRetry: () {
            if (!widget.app.tryConsumePlayForRetry()) return;
            _text.clear();
            _c.begin(skipIntro: true);
          },
          hud: [
            HudPill(label: 'SATIR', value: '${(_c.index + 1).clamp(1, _c.lines.length)}/${_c.lines.length}'),
            HudPill(
              label: 'SÜRE',
              value: (_c.remainingMs / 1000).toStringAsFixed(1),
              highlight: _c.remainingMs < 6000,
            ),
          ],
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 4),
                // --- Yazilacak cumle karti ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.95), width: 3),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Color(0xFFEDEAFF)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 18, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('BUNU YAZ', style: baloo(10, FontWeight.w600, AppColors.inkFaint, letterSpacing: 2)),
                      const SizedBox(height: 10),
                      _PhraseText(target: _c.currentPhrase, typed: _c.input),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // --- Giris kutusu ---
                _InputBox(
                  controller: _text,
                  focus: _focus,
                  wrong: _c.lastWrong,
                  enabled: _c.phase == MiniPhase.play,
                  onChanged: _c.setInput,
                  onSubmit: _c.submit,
                ),
                const SizedBox(height: 10),
                Text(
                  _c.lastWrong ? 'Cümle tam eşleşmedi, düzeltip tekrar gönder.' : 'Yazdıktan sonra enter’a bas.',
                  textAlign: TextAlign.center,
                  style: baloo(12, FontWeight.w600, _c.lastWrong ? AppColors.red : AppColors.inkFaint),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Hedef cumleyi gosterir; dogru yazilan kisim yesil, ilk sapma kirmizi olur.
class _PhraseText extends StatelessWidget {
  final String target;
  final String typed;

  const _PhraseText({required this.target, required this.typed});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final t = target;
    final u = typed;

    // Kac karakter dogru gidiyor.
    var okLen = 0;
    while (okLen < t.length && okLen < u.length && t[okLen].toLowerCase() == u[okLen].toLowerCase()) {
      okLen++;
    }
    // Ilk hatali karakter (varsa).
    final hasError = okLen < u.length;

    if (okLen > 0) {
      spans.add(TextSpan(
        text: t.substring(0, okLen),
        style: baloo(20, FontWeight.w700, const Color(0xFF3D8B2E), height: 1.45),
      ));
    }
    if (hasError && okLen < t.length) {
      spans.add(TextSpan(
        text: t.substring(okLen, okLen + 1),
        style: baloo(20, FontWeight.w800, Colors.white, height: 1.45).copyWith(
          backgroundColor: AppColors.red.withOpacity(0.85),
        ),
      ));
      if (okLen + 1 < t.length) {
        spans.add(TextSpan(
          text: t.substring(okLen + 1),
          style: baloo(20, FontWeight.w700, AppColors.inkSoft, height: 1.45),
        ));
      }
    } else if (okLen < t.length) {
      spans.add(TextSpan(
        text: t.substring(okLen),
        style: baloo(20, FontWeight.w700, AppColors.inkSoft, height: 1.45),
      ));
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }
}

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool wrong;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  const _InputBox({
    required this.controller,
    required this.focus,
    required this.wrong,
    required this.enabled,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: wrong ? AppColors.red.withOpacity(0.9) : Colors.white.withOpacity(0.95),
          width: 2.5,
        ),
        color: Colors.white.withOpacity(0.92),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focus,
        enabled: enabled,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmit(),
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        // Tek satir olmali: cok satirli alanda enter tusu satir atlar ve
        // onSubmitted hic tetiklenmez.
        maxLines: 1,
        style: baloo(18, FontWeight.w700, AppColors.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintText: 'buraya yaz…',
          hintStyle: baloo(18, FontWeight.w700, AppColors.inkFaint),
        ),
      ),
    );
  }
}
