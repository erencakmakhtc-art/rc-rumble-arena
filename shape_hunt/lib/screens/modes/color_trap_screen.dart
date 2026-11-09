import 'package:flutter/material.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/trial_base.dart';
import '../../models/game_mode.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_kit.dart';

/// Gecme sarti: 20 saniyede (3 hata yapmadan) ulasilmasi gereken puan.
const int _kColorTrapTarget = 3000;

/// Kullanilan renkler. Sira onemli: indeksler hem anlam hem boya icin kullanilir.
const List<String> _kColorNames = ['KIRMIZI', 'MAVİ', 'YEŞİL', 'SARI', 'MOR'];
const List<Color> _kColorValues = [
  Color(0xFFE53935),
  Color(0xFF1E6FE0),
  Color(0xFF1FA34A),
  Color(0xFFE9A800),
  Color(0xFF8E3FD1),
];

/// Hangi kurala gore cevap verilecek.
///  - ink: kelimenin BOYA rengini sec ("RENGİNE BAS")
///  - meaning: kelimenin NE YAZDIGINI sec ("ANLAMINA BAS")
enum ColorRule { ink, meaning }

/// Bir cevap butonu: [meaning] butonda yazan renk adi, [ink] o yazinin boyasi.
/// Dogru cevap her zaman butondaki YAZIYA (anlama) gore belirlenir.
class ColorOption {
  final int meaning;
  final int ink;
  const ColorOption(this.meaning, this.ink);
}

class ColorTrapController extends TrialGameController {
  ColorRule rule = ColorRule.ink;

  /// Hedef kelimenin anlami ve boyasi (renk indeksleri).
  int word = 0;
  int wordInk = 1;

  List<ColorOption> options = const [];
  int? pickedIndex;

  @override
  int get targetPoints => _kColorTrapTarget;

  @override
  int get fastMs => 800;

  /// Cevap penceresi 1,7 sn'den 1,15 sn'ye daralir.
  @override
  int trialWindowMs(double progress) => (1700 - 550 * progress).round();

  /// Su anki kurala gore dogru renk indeksi.
  int get answerColor => rule == ColorRule.ink ? wordInk : word;

  @override
  void resetTrialState() {
    rule = ColorRule.ink;
    options = const [];
    pickedIndex = null;
  }

  @override
  void buildTrial() {
    pickedIndex = null;
    final n = _kColorNames.length;

    // Ilk 3 saniye hep RENK kurali; sonra %40 ihtimalle ANLAM kurali.
    rule = (elapsedMs > 3000 && rng.nextDouble() < 0.4) ? ColorRule.meaning : ColorRule.ink;

    // %90 uyumsuz: kelime ile boyasi farkli renk.
    word = rng.nextInt(n);
    wordInk = rng.nextDouble() < 0.9 ? (word + 1 + rng.nextInt(n - 1)) % n : word;

    final ans = answerColor;
    // Tuzak: diger kurala gore dogru olan secenek her zaman butonlarda olur.
    final trap = rule == ColorRule.ink ? word : wordInk;
    final picks = <int>{ans, trap};
    while (picks.length < 4) {
      picks.add(rng.nextInt(n));
    }
    final list = picks.toList()..shuffle(rng);
    options = [for (final m in list) ColorOption(m, _inkFor(m, ans))];
  }

  /// Butondaki yazinin boyasi: asla kendi anlami degildir. Yanlis butonlar
  /// sik sik dogru cevabin rengiyle boyanir (gorsel tuzak).
  int _inkFor(int meaning, int ans) {
    if (meaning != ans && rng.nextDouble() < 0.45) return ans;
    final n = _kColorNames.length;
    var ink = rng.nextInt(n);
    while (ink == meaning) {
      ink = rng.nextInt(n);
    }
    return ink;
  }

  void pick(int i) {
    if (!acceptingInput || i >= options.length) return;
    pickedIndex = i;
    answer(options[i].meaning == answerColor);
  }

  @override
  String get verdict {
    if (errors == 0 && avgReactionMs < 700) return 'Beynin renklere hiç kanmadı. Kusursuz!';
    if (errors == 0) return 'Hatasız! Biraz daha hızlanırsan zirvedesin.';
    return 'Tuzakları aştın. Kural değişimlerine dikkat etmeye devam!';
  }
}

class ColorTrapScreen extends StatefulWidget {
  final GameController app;
  const ColorTrapScreen({super.key, required this.app});

  @override
  State<ColorTrapScreen> createState() => _ColorTrapScreenState();
}

class _ColorTrapScreenState extends State<ColorTrapScreen> {
  late final ColorTrapController _c;

  @override
  void initState() {
    super.initState();
    _c = ColorTrapController();
    _c.onFinished = () => widget.app.reportModeResult(GameMode.colorTrap, _c.points, _c.passed);
    _c.begin(skipIntro: widget.app.shouldSkipIntro(GameMode.colorTrap));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final hasTrial = _c.options.isNotEmpty;
        return MiniStage(
          mode: GameMode.colorTrap,
          controller: _c,
          onQuit: widget.app.backToModes,
          dontShowIntro: widget.app.shouldSkipIntro(GameMode.colorTrap),
          onDontShowIntroChanged: (v) => widget.app.setSkipIntro(GameMode.colorTrap, v),
          onRetry: () {
            if (widget.app.tryConsumePlayForRetry()) _c.begin(skipIntro: true);
          },
          hud: [
            HudPill(
              label: 'SÜRE',
              value: (_c.remainingMs / 1000).toStringAsFixed(1),
              highlight: _c.remainingMs < 5000,
            ),
            HudPill(label: 'HATA', value: '${_c.errors}/${_c.maxErrors}', highlight: _c.errors >= 2),
            HudPill(label: 'PUAN', value: '${_c.points}', highlight: true),
          ],
          child: Column(
            children: [
              const Spacer(flex: 2),
              _RuleBanner(rule: _c.rule, visible: hasTrial),
              const SizedBox(height: 14),
              _WordCard(controller: _c),
              const SizedBox(height: 10),
              _WindowBar(value: hasTrial ? _c.windowLeft : 1.0),
              const Spacer(flex: 3),
              _OptionGrid(controller: _c),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

class _RuleBanner extends StatelessWidget {
  final ColorRule rule;
  final bool visible;
  const _RuleBanner({required this.rule, required this.visible});

  @override
  Widget build(BuildContext context) {
    final isInk = rule == ColorRule.ink;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: visible ? 1 : 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 140),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: Container(
          key: ValueKey(rule),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isInk
                  ? const [Color(0xFF6A71C2), Color(0xFF3F4478)]
                  : const [Color(0xFFFFC27A), Color(0xFFFF8A1F)],
            ),
          ),
          child: Text(
            isInk ? 'RENGİNE BAS' : 'ANLAMINA BAS',
            style: baloo(16, FontWeight.w800, isInk ? Colors.white : const Color(0xFF5A2800), letterSpacing: 0.6),
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final ColorTrapController controller;
  const _WordCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final hasTrial = c.options.isNotEmpty;
    final Color border = switch (c.feedback) {
      TrialFeedback.correct => const Color(0xFF3FBF6A),
      TrialFeedback.wrong || TrialFeedback.timeout => AppColors.red,
      TrialFeedback.none => Colors.white.withOpacity(0.92),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: double.infinity,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border, width: c.feedback == TrialFeedback.none ? 2 : 4),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFEFF1FF)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 7)),
        ],
      ),
      child: hasTrial
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _kColorNames[c.word],
                  style: baloo(54, FontWeight.w800, _kColorValues[c.wordInk], letterSpacing: 1.0),
                ),
              ),
            )
          : Text('HAZIR', style: baloo(30, FontWeight.w800, AppColors.inkFaint)),
    );
  }
}

class _WindowBar extends StatelessWidget {
  final double value;
  const _WindowBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 9,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Colors.white.withOpacity(0.45),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0).toDouble(),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: value < 0.3 ? AppColors.red : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _OptionGrid extends StatelessWidget {
  final ColorTrapController controller;
  const _OptionGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget tile(int i) {
      if (i >= c.options.length) return const Expanded(child: SizedBox(height: 86));
      final o = c.options[i];
      final picked = c.pickedIndex == i;
      final isAnswer = o.meaning == c.answerColor;
      // Hata ya da gec kalmada dogru cevap yesil cerceveyle gosterilir (ogretici).
      final revealAnswer =
          (c.feedback == TrialFeedback.wrong || c.feedback == TrialFeedback.timeout) && isAnswer;
      final _TileState state;
      if (picked && c.feedback == TrialFeedback.correct) {
        state = _TileState.good;
      } else if (picked && c.feedback == TrialFeedback.wrong) {
        state = _TileState.bad;
      } else if (revealAnswer) {
        state = _TileState.reveal;
      } else {
        state = _TileState.idle;
      }
      return Expanded(
        child: _OptionTile(
          label: _kColorNames[o.meaning],
          ink: _kColorValues[o.ink],
          state: state,
          onDown: () => c.pick(i),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [tile(0), const SizedBox(width: 10), tile(1)]),
        const SizedBox(height: 10),
        Row(children: [tile(2), const SizedBox(width: 10), tile(3)]),
      ],
    );
  }
}

enum _TileState { idle, good, bad, reveal }

class _OptionTile extends StatelessWidget {
  final String label;
  final Color ink;
  final _TileState state;
  final VoidCallback onDown;

  const _OptionTile({
    required this.label,
    required this.ink,
    required this.state,
    required this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    final (List<Color> bg, Color border) = switch (state) {
      _TileState.good => (const [Color(0xFFE4FFD9), Color(0xFFB9EE90)], const Color(0xFF3FBF6A)),
      _TileState.bad => (const [Color(0xFFFFE3E3), Color(0xFFFFC2C2)], AppColors.red),
      _TileState.reveal => (const [Colors.white, Color(0xFFEFF1FF)], const Color(0xFF3FBF6A)),
      _TileState.idle => (const [Colors.white, Color(0xFFEFF1FF)], Colors.white),
    };
    return Listener(
      // Aninda tepki: parmak degdigi an cevap sayilir.
      onPointerDown: (_) => onDown(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        height: 86,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: state == _TileState.idle ? 2 : 4),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bg),
          boxShadow: [
            BoxShadow(color: const Color(0x55969CCD), blurRadius: 0, offset: const Offset(0, 4)),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label, style: baloo(26, FontWeight.w800, ink, letterSpacing: 0.4)),
          ),
        ),
      ),
    );
  }
}
