import 'dart:math';

import 'package:flutter/material.dart';

/// Verilen cocugun (child) etrafinda surekli donen, yumusak isiltili bir
/// halka cizer. "Oyuna basla" gibi dikkat cekmesi istenen butonlarin
/// etrafina sarmak icin kullanilir.
class GlowRing extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double spread;
  final List<Color> colors;
  final Duration duration;

  const GlowRing({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.spread = 7,
    this.colors = const [Color(0xFFFFE38A), Color(0xFFFFF6D8), Color(0xFFFFE38A)],
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<GlowRing> createState() => _GlowRingState();
}

class _GlowRingState extends State<GlowRing> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -widget.spread,
          right: -widget.spread,
          top: -widget.spread,
          bottom: -widget.spread,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _GlowRingPainter(
                    angle: _ctrl.value * 2 * pi,
                    radius: widget.borderRadius + widget.spread * 0.6,
                    colors: widget.colors,
                  ),
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _GlowRingPainter extends CustomPainter {
  final double angle;
  final double radius;
  final List<Color> colors;

  _GlowRingPainter({required this.angle, required this.radius, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius)).deflate(2);

    final sweepColors = [Colors.transparent, ...colors, Colors.transparent];
    final gradient = SweepGradient(
      colors: sweepColors,
      stops: List.generate(sweepColors.length, (i) => i / (sweepColors.length - 1)),
      transform: GradientRotation(angle),
    );

    final glowPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawRRect(rrect, glowPaint);

    final corePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, corePaint);
  }

  @override
  bool shouldRepaint(covariant _GlowRingPainter oldDelegate) => oldDelegate.angle != angle;
}
