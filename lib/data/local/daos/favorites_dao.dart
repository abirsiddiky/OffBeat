import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/favorites_table.dart';

part 'favorites_dao.g.dart';

@DriftAccessor(tables: [Favorites])
class FavoritesDao extends DatabaseAccessor<OffBeatDatabase> with _$FavoritesDaoMixin {
  FavoritesDao(super.db);

  /// Watch all favorites ordered by recently added (descending)
  Stream<List<Favorite>> watchFavorites() {
    return (select(favorites)
          ..orderBy([(t) => OrderingTerm(expression: t.addedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Watch favorite song IDs as a Set for O(1) lookups
  Stream<Set<int>> watchFavoriteSongIds() {
    return watchFavorites().map((favs) => favs.map((f) => f.songId).toSet());
  }

  /// Check whether a specific song is favorited
  Future<bool> isFavorite(int songId) async {
    final entry = await (select(favorites)..where((t) => t.songId.equals(songId))).getSingleOrNull();
    return entry != null;
  }

  /// Watch favorite status for a single song
  Stream<bool> watchIsFavorite(int songId) {
    return (select(favorites)..where((t) => t.songId.equals(songId)))
        .watchSingleOrNull()
        .map((entry) => entry != null);
  }

  /// Toggle favorite status for a song. Returns true if favorited, false if unfavorited.
  Future<bool> toggleFavorite(int songId) async {
    final exists = await isFavorite(songId);
    if (exists) {
      await (delete(favorites)..where((t) => t.songId.equals(songId))).go();
      return false;
    } else {
      await into(favorites).insert(
        FavoritesCompanion.insert(
          songId: Value(songId),
          addedAt: Value(DateTime.now()),
        ),
      );
      return true;
    }
  }
}
