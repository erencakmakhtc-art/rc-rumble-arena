import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../controllers/arena_base.dart';
import '../controllers/mini_base.dart';
import '../theme/app_theme.dart';

/// Arena bolumlerinin oyun alani: yuvarlatilmis cerceve + tuval + dokunus.
///
/// Ticker'i yonetir: sadece oynanis sirasinda (menu kapaliyken) kare uretir.
/// Dokunuslar [Listener] ile aninda (jest arenasini beklemeden) ve her parmak
/// ayri olarak iletilir. Konumlar alanin sol ust kosesine gore pikseldir.
class ArenaView extends StatefulWidget {
  final ArenaGameController controller;
  final CustomPainter painter;
  final void Function(int pointer, Offset pos)? onDown;
  final void Function(int pointer, Offset pos)? onMove;
  final void Function(int pointer)? onUp;

  /// Cerceve rengi (geri bildirim icin degistirilebilir).
  final Color? borderColor;

  const ArenaView({
    super.key,
    required this.controller,
    required this.painter,
    this.onDown,
    this.onMove,
    this.onUp,
    this.borderColor,
  });

  @override
  State<ArenaView> createState() => _ArenaViewState();
}

class _ArenaViewState extends State<ArenaView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(widget.controller.tick);
    widget.controller.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final c = widget.controller;
    final run = c.phase == MiniPhase.play && !c.menuOpen;
    if (run && !_ticker.isActive) {
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: widget.borderColor ?? Colors.white.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 22, offset: const Offset(0, 9)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, cons) {
            widget.controller.field = Size(cons.maxWidth, cons.maxHeight);
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => widget.onDown?.call(e.pointer, e.localPosition),
              onPointerMove: (e) => widget.onMove?.call(e.pointer, e.localPosition),
              onPointerUp: (e) => widget.onUp?.call(e.pointer),
              onPointerCancel: (e) => widget.onUp?.call(e.pointer),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(cons.maxWidth, cons.maxHeight),
                  painter: widget.painter,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Ortak cizim yardimcilari
// =============================================================================

/// Dikey degrade zemin.
void paintPlayfield(Canvas canvas, Size size, List<Color> colors) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect),
  );
}

/// Parlak (glossy) top: radyal degrade + ust parlama.
void paintGlossBall(Canvas canvas, Offset c, double r, Color light, Color dark) {
  final rect = Rect.fromCircle(center: c, radius: r);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        colors: [light, dark],
      ).createShader(rect),
  );
  canvas.drawOval(
    Rect.fromCenter(center: c + Offset(-r * 0.3, -r * 0.42), width: r * 0.8, height: r * 0.42),
    Paint()..color = Colors.white.withOpacity(0.45),
  );
}

/// Ortalanmis Baloo yazisi.
void paintLabel(Canvas canvas, String text, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: baloo(size, FontWeight.w800, color, height: 1.0)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  tp.dispose();
}

/// Alanin ortasinda yari saydam bir kutuda yonerge ("Parmağını koy" gibi).
void paintPrompt(Canvas canvas, Size size, String text) {
  final rect = Rect.fromCenter(
    center: Offset(size.width / 2, size.height * 0.42),
    width: min(size.width * 0.86, 320),
    height: 64,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(20)),
    Paint()..color = Colors.white.withOpacity(0.82),
  );
  paintLabel(canvas, text, rect.center, 18, AppColors.inkSoft);
}

/// Yukari suzulup solan yazilar.
void paintFloats(Canvas canvas, List<FloatText> floats) {
  for (final f in floats) {
    final t = (f.ageMs / 750).clamp(0.0, 1.0).toDouble();
    paintLabel(canvas, f.text, f.pos + Offset(0, -34 * t), f.size, f.color.withOpacity(1 - t * t));
  }
}

// =============================================================================
// Meyveler (Meyve Kesici + Kova Yakala ortak)
// =============================================================================

enum FruitKind { apple, orange, watermelon, lemon, kiwi, star, rotten, rock, bomb }

/// Meyvenin kesildiginde gorunen ic rengi.
Color fruitFlesh(FruitKind k) => switch (k) {
      FruitKind.apple => const Color(0xFFFFF1CF),
      FruitKind.orange => const Color(0xFFFFB347),
      FruitKind.watermelon => const Color(0xFFFF4D6D),
      FruitKind.lemon => const Color(0xFFFFF59D),
      FruitKind.kiwi => const Color(0xFF9BD34A),
      FruitKind.star => const Color(0xFFFFE680),
      FruitKind.rotten => const Color(0xFFB9A36A),
      FruitKind.rock || FruitKind.bomb => const Color(0xFF8C8FA8),
    };

/// Bir meyveyi (ya da tasi/bombayi) [c] merkezli, [r] yaricapli, [rot] acili cizer.
void paintFruit(Canvas canvas, FruitKind kind, Offset c, double r, double rot, {double t = 0}) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(rot);
  final o = Offset.zero;
  switch (kind) {
    case FruitKind.apple: {
        paintGlossBall(canvas, o, r, const Color(0xFFFF8A80), const Color(0xFFD32F2F));
        canvas.drawLine(o + Offset(0, -r * 0.8), o + Offset(r * 0.08, -r * 1.2),
            Paint()..color = const Color(0xFF6D4C41)..strokeWidth = r * 0.12..strokeCap = StrokeCap.round);
        _leaf(canvas, o + Offset(r * 0.32, -r * 1.02), r * 0.42, 0.5);
        break;
      }
    case FruitKind.orange: {
        paintGlossBall(canvas, o, r, const Color(0xFFFFCC80), const Color(0xFFF57C00));
        final dot = Paint()..color = const Color(0xFFE06A00).withOpacity(0.55);
        for (var i = 0; i < 5; i++) {
          final a = i * 1.3 + 0.4;
          canvas.drawCircle(o + Offset(cos(a) * r * 0.55, sin(a) * r * 0.55), r * 0.05, dot);
        }
        canvas.drawCircle(o + Offset(0, -r * 0.86), r * 0.1, Paint()..color = const Color(0xFF558B2F));
        break;
      }
    case FruitKind.watermelon: {
        paintGlossBall(canvas, o, r, const Color(0xFF8BD66A), const Color(0xFF2E7D32));
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: r)));
        final stripe = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.16
          ..color = const Color(0xFF1B5E20).withOpacity(0.7);
        for (var i = -2; i <= 2; i++) {
          final x = i * r * 0.45;
          canvas.drawPath(
            Path()
              ..moveTo(x, -r)
              ..quadraticBezierTo(x + r * 0.25, 0, x, r),
            stripe,
          );
        }
        canvas.restore();
        break;
      }
    case FruitKind.lemon: {
        final rect = Rect.fromCenter(center: o, width: r * 2.3, height: r * 1.75);
        canvas.drawOval(
          rect,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.3, -0.35),
              colors: [Color(0xFFFFF59D), Color(0xFFF9C80E)],
            ).createShader(rect),
        );
        final nub = Paint()..color = const Color(0xFFF9C80E);
        canvas.drawCircle(o + Offset(r * 1.12, 0), r * 0.16, nub);
        canvas.drawCircle(o + Offset(-r * 1.12, 0), r * 0.16, nub);
        canvas.drawOval(
          Rect.fromCenter(center: o + Offset(-r * 0.3, -r * 0.4), width: r * 0.9, height: r * 0.3),
          Paint()..color = Colors.white.withOpacity(0.45),
        );
        break;
      }
    case FruitKind.kiwi: {
        paintGlossBall(canvas, o, r, const Color(0xFFBCA27A), const Color(0xFF6D5436));
        final fuzz = Paint()..color = const Color(0xFF4E3B24).withOpacity(0.45);
        for (var i = 0; i < 7; i++) {
          final a = i * 0.9;
          canvas.drawCircle(o + Offset(cos(a) * r * 0.6, sin(a) * r * 0.6), r * 0.05, fuzz);
        }
        break;
      }
    case FruitKind.star: {
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final a = -pi / 2 + i * pi / 5;
          final rr = i.isEven ? r * 1.1 : r * 0.5;
          final p = o + Offset(cos(a) * rr, sin(a) * rr);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        final rect = Rect.fromCircle(center: o, radius: r * 1.1);
        canvas.drawPath(
          path,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF3B0), Color(0xFFFFB300)],
            ).createShader(rect),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.1
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white.withOpacity(0.8),
        );
        break;
      }
    case FruitKind.rotten: {
        // Elmaya benzer ama kahverengi-yesil ve lekeli: dikkatli bakmak gerekir.
        paintGlossBall(canvas, o, r, const Color(0xFFB7A26A), const Color(0xFF6B5A2A));
        final spot = Paint()..color = const Color(0xFF3E3418).withOpacity(0.75);
        canvas.drawCircle(o + Offset(-r * 0.3, r * 0.2), r * 0.2, spot);
        canvas.drawCircle(o + Offset(r * 0.35, -r * 0.1), r * 0.14, spot);
        canvas.drawCircle(o + Offset(r * 0.05, r * 0.5), r * 0.1, spot);
        canvas.drawLine(o + Offset(0, -r * 0.8), o + Offset(r * 0.08, -r * 1.2),
            Paint()..color = const Color(0xFF4E342E)..strokeWidth = r * 0.12..strokeCap = StrokeCap.round);
        break;
      }
    case FruitKind.rock: {
        final path = Path()
          ..moveTo(-r * 0.95, r * 0.2)
          ..lineTo(-r * 0.6, -r * 0.75)
          ..lineTo(r * 0.2, -r * 0.95)
          ..lineTo(r * 0.95, -r * 0.3)
          ..lineTo(r * 0.8, r * 0.7)
          ..lineTo(-r * 0.2, r * 0.95)
          ..close();
        final rect = Rect.fromCircle(center: o, radius: r);
        canvas.drawPath(
          path,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFB0B3C6), Color(0xFF5E6178)],
            ).createShader(rect),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.08
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF45475A),
        );
        break;
      }
    case FruitKind.bomb: {
        paintGlossBall(canvas, o, r, const Color(0xFF6E7391), const Color(0xFF1C1E2E));
        canvas.drawPath(
          Path()
            ..moveTo(0, -r * 0.9)
            ..quadraticBezierTo(r * 0.2, -r * 1.35, r * 0.55, -r * 1.3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.12
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF8D6E63),
        );
        // Titreyen kivilcim
        final k = 0.7 + 0.3 * sin(t * 30);
        canvas.drawCircle(o + Offset(r * 0.58, -r * 1.3), r * 0.22 * k, Paint()..color = const Color(0xFFFFD54F));
        canvas.drawCircle(o + Offset(r * 0.58, -r * 1.3), r * 0.11 * k, Paint()..color = Colors.white);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: o + Offset(0, -r * 0.82), width: r * 0.5, height: r * 0.22),
            Radius.circular(r * 0.05),
          ),
          Paint()..color = const Color(0xFF45475A),
        );
        break;
      }
  }
  canvas.restore();
}

void _leaf(Canvas canvas, Offset c, double s, double angle) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(angle);
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: s, height: s * 0.5),
    Paint()..color = const Color(0xFF66BB6A),
  );
  canvas.restore();
}
