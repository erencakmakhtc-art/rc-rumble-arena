import 'color_defs.dart';
import 'shape_defs.dart';

/// Bir ızgara hucresinde gosterilen "sekil + renk" kombinasyonu.
/// Orijinal tasarimdaki PAIRS listesindeki her ogeye karsilik gelir.
class ShapePair {
  final ShapeKind shape;
  final ShapeColorKey color;

  const ShapePair(this.shape, this.color);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ShapePair && other.shape == shape && other.color == color);

  @override
  int get hashCode => Object.hash(shape, color);
}

/// Orijinal tasarimdaki PAIRS dizisiyle birebir ayni sira ve icerik.
const List<ShapePair> kPairs = [
  ShapePair(ShapeKind.triangle, ShapeColorKey.orange),
  ShapePair(ShapeKind.star5, ShapeColorKey.yellow),
  ShapePair(ShapeKind.hex, ShapeColorKey.pink),
  ShapePair(ShapeKind.arrowD, ShapeColorKey.blue),
  ShapePair(ShapeKind.diamond, ShapeColorKey.orange),
  ShapePair(ShapeKind.sparkle, ShapeColorKey.green),
  ShapePair(ShapeKind.arrowR, ShapeColorKey.blue),
  ShapePair(ShapeKind.circle, ShapeColorKey.red),
  ShapePair(ShapeKind.hex, ShapeColorKey.violet),
  ShapePair(ShapeKind.pill, ShapeColorKey.blue),
  ShapePair(ShapeKind.star5, ShapeColorKey.green),
];

/// Orijinal tasarimdaki diffPool() ile ayni mantik: easy=6, normal=8, hard=11 cift.
enum Difficulty { easy, normal, hard }

List<ShapePair> pairsForDifficulty(Difficulty d) {
  switch (d) {
    case Difficulty.easy:
      return kPairs.sublist(0, 6);
    case Difficulty.hard:
      return kPairs.sublist(0, 11);
    case Difficulty.normal:
      return kPairs.sublist(0, 8);
  }
}
