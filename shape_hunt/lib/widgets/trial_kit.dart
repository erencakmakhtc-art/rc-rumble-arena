import 'package:flutter/material.dart';

import '../controllers/trial_base.dart';
import '../theme/app_theme.dart';

/// Denemenin cevap penceresinden kalan sure cubugu.
class TrialWindowBar extends StatelessWidget {
  final double value;
  const TrialWindowBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 9,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Colors.white.withOpacity(0.5),
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

/// Uyaran karti: cercevesi geri bildirime gore yesil/kirmizi yanar.
class TrialCard extends StatelessWidget {
  final TrialFeedback feedback;
  final double? height;
  final Widget child;

  const TrialCard({super.key, required this.feedback, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    final Color border = switch (feedback) {
      TrialFeedback.correct => const Color(0xFF3FBF6A),
      TrialFeedback.wrong || TrialFeedback.timeout => AppColors.red,
      TrialFeedback.none => Colors.white.withOpacity(0.92),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: double.infinity,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border, width: feedback == TrialFeedback.none ? 2 : 4),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFEFF1FF)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 7)),
        ],
      ),
      child: child,
    );
  }
}

enum ChoiceState { idle, good, bad, reveal }

/// Aninda tepki veren (parmak degdigi an) cevap butonu.
class TrialChoice extends StatelessWidget {
  final Widget child;
  final ChoiceState state;
  final VoidCallback onDown;
  final List<Color> idleColors;
  final double height;

  const TrialChoice({
    super.key,
    required this.child,
    required this.state,
    required this.onDown,
    this.idleColors = const [Colors.white, Color(0xFFEFF1FF)],
    this.height = 86,
  });

  @override
  Widget build(BuildContext context) {
    final (List<Color> bg, Color border) = switch (state) {
      ChoiceState.good => (const [Color(0xFFE4FFD9), Color(0xFFB9EE90)], const Color(0xFF3FBF6A)),
      ChoiceState.bad => (const [Color(0xFFFFE3E3), Color(0xFFFFC2C2)], AppColors.red),
      ChoiceState.reveal => (idleColors, const Color(0xFF3FBF6A)),
      ChoiceState.idle => (idleColors, Colors.white),
    };
    return Listener(
      onPointerDown: (_) => onDown(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: state == ChoiceState.idle ? 2 : 4),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bg),
          boxShadow: const [
            BoxShadow(color: Color(0x55969CCD), blurRadius: 0, offset: Offset(0, 4)),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Bir secenegin gosterim durumunu hesaplar.
ChoiceState choiceStateOf({
  required bool picked,
  required bool isAnswer,
  required TrialFeedback feedback,
}) {
  if (picked && feedback == TrialFeedback.correct) return ChoiceState.good;
  if (picked && feedback == TrialFeedback.wrong) return ChoiceState.bad;
  if (isAnswer && (feedback == TrialFeedback.wrong || feedback == TrialFeedback.timeout)) {
    return ChoiceState.reveal;
  }
  return ChoiceState.idle;
}
