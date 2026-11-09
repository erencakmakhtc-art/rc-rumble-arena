import 'dart:ui';

/// Oyunda kullanilan tum sekil turleri (orijinal tasarimdaki SHAPES nesnesiyle birebir).
enum ShapeKind { triangle, diamond, hex, star5, sparkle, arrowR, arrowD, pill, circle }

class ShapeDef {
  /// Poligon noktalari, 0..1 araliginda (genislik/yukseklige oranli).
  /// pill ve circle icin bos birakilir; bu ikisi ayri ciziliyor.
  final List<Offset> points;

  /// Sekil kutusunun yuksekliginin genisligine orani (pill icin 0.6, digerleri 1.0).
  final double heightFraction;

  final String nameTr;

  const ShapeDef({this.points = const [], this.heightFraction = 1.0, required this.nameTr});
}

final Map<ShapeKind, ShapeDef> kShapeDefs = {
  ShapeKind.triangle: const ShapeDef(
    points: [Offset(0.50, 0.04), Offset(0.97, 0.92), Offset(0.03, 0.92)],
    nameTr: 'üçgen',
  ),
  ShapeKind.diamond: const ShapeDef(
    points: [Offset(0.50, 0.02), Offset(0.97, 0.50), Offset(0.50, 0.98), Offset(0.03, 0.50)],
    nameTr: 'baklava',
  ),
  ShapeKind.hex: const ShapeDef(
    points: [
      Offset(0.25, 0.06),
      Offset(0.75, 0.06),
      Offset(1.00, 0.50),
      Offset(0.75, 0.94),
      Offset(0.25, 0.94),
      Offset(0.00, 0.50),
    ],
    nameTr: 'altıgen',
  ),
  ShapeKind.star5: const ShapeDef(
    points: [
      Offset(0.50, 0.02),
      Offset(0.62, 0.36),
      Offset(0.98, 0.36),
      Offset(0.69, 0.58),
      Offset(0.80, 0.93),
      Offset(0.50, 0.71),
      Offset(0.20, 0.93),
      Offset(0.31, 0.58),
      Offset(0.02, 0.36),
      Offset(0.38, 0.36),
    ],
    nameTr: 'yıldız',
  ),
  ShapeKind.sparkle: const ShapeDef(
    points: [
      Offset(0.50, 0.00),
      Offset(0.61, 0.39),
      Offset(1.00, 0.50),
      Offset(0.61, 0.61),
      Offset(0.50, 1.00),
      Offset(0.39, 0.61),
      Offset(0.00, 0.50),
      Offset(0.39, 0.39),
    ],
    nameTr: 'parıltı',
  ),
  ShapeKind.arrowR: const ShapeDef(
    points: [
      Offset(0.00, 0.32),
      Offset(0.55, 0.32),
      Offset(0.55, 0.08),
      Offset(1.00, 0.50),
      Offset(0.55, 0.92),
      Offset(0.55, 0.68),
      Offset(0.00, 0.68),
    ],
    nameTr: 'sağ ok',
  ),
  ShapeKind.arrowD: const ShapeDef(
    points: [
      Offset(0.32, 0.00),
      Offset(0.68, 0.00),
      Offset(0.68, 0.55),
      Offset(0.92, 0.55),
      Offset(0.50, 1.00),
      Offset(0.08, 0.55),
      Offset(0.32, 0.55),
    ],
    nameTr: 'aşağı ok',
  ),
  ShapeKind.pill: const ShapeDef(heightFraction: 0.6, nameTr: 'kapsül'),
  ShapeKind.circle: const ShapeDef(nameTr: 'boncuk'),
};
