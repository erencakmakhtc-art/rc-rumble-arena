import '../data/pairs.dart';

/// Oyun izgarasindaki tek bir hucre.
class GameTile {
  final String id;
  final ShapePair pair;
  bool cleared;

  GameTile({required this.id, required this.pair, this.cleared = false});
}
