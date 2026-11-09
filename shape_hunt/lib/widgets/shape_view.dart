import 'package:flutter/material.dart';

import '../data/color_defs.dart';
import '../data/pairs.dart';
import '../data/shape_defs.dart';

/// Bir [ShapePair]'i (sekil + renk) camsi degradeli olarak cizen widget.
/// [pair] null ise bos bir kutu birakir (yer tutucu).
class ShapeView extends StatelessWidget {
  final ShapePair? pair;
  final double size;
  final bool glossy;

  /// Verilirse [pair]'in kendi renk paleti yerine bu 3 renkli degrade kullanilir.
  /// "Farkli olani bul" bolumu, aralarinda cok ince ton farki olan sekiller
  /// uretebilmek icin bunu kullanir.
  final List<Color>? colorsOverride;

  const ShapeView({
    super.key,
    required this.pair,
    required this.size,
    this.glossy = true,
    this.colorsOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (pair == null || size <= 0) {
      return SizedBox(width: size > 0 ? size : 0, height: size > 0 ? size : 0);
    }
    final def = kShapeDefs[pair!.shape]!;
    final boxH = size * def.heightFraction;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SizedBox(
          width: size,
          height: boxH,
          child: CustomPaint(
            painter: ShapePainter(
              kind: pair!.shape,
              colors: colorsOverride ?? kColorGradients[pair!.color]!,
              glossy: glossy,
            ),
          ),
        ),
      ),
    );
  }
}

class ShapePainter extends CustomPainter {
  final ShapeKind kind;
  final List<Color> colors;
  final bool glossy;

  ShapePainter({required this.kind, required this.colors, required this.glossy});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final path = _pathFor(kind, size);

    canvas.save();
    canvas.clipPath(path);

    // Ana degrade dolgu (168deg CSS degradesine yakin: hafif capraz).
    final fillPaint = Paint()
      ..shader = (glossy
              ? LinearGradient(
                  begin: const Alignment(-0.25, -1),
                  end: const Alignment(0.25, 1),
                  colors: colors,
                  stops: const [0.0, 0.46, 1.0],
                )
              : LinearGradient(colors: [colors[1], colors[1]]))
          .createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fillPaint);

    if (glossy) {
      // Alt kisimda hafif golgeleme (ic golge hissi).
      final shadePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors[2].withOpacity(0.0), colors[2].withOpacity(0.35)],
          stops: const [0.55, 1.0],
        ).createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, shadePaint);

      // Ust kisimda parlaklik (highlight) elipsi.
      final hl = Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.07,
        size.width * 0.72,
        size.height * 0.30,
      );
      final hlPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.0)],
        ).createShader(hl);
      canvas.drawOval(hl, hlPaint);
    }

    canvas.restore();
  }

  Path _pathFor(ShapeKind k, Size size) {
    switch (k) {
      case ShapeKind.pill:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(
            Offset.zero & size,
            Radius.circular(size.height / 2),
          ));
      case ShapeKind.circle:
        return Path()..addOval(Offset.zero & size);
      default:
        final def = kShapeDefs[k]!;
        final path = Path();
        for (var i = 0; i < def.points.length; i++) {
          final p = Offset(def.points[i].dx * size.width, def.points[i].dy * size.height);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        return path;
    }
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.colors != colors || oldDelegate.glossy != glossy;
  }
}
