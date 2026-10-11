import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/recently_played_table.dart';

part 'recently_played_dao.g.dart';

@DriftAccessor(tables: [RecentlyPlayed])
class RecentlyPlayedDao extends DatabaseAccessor<OffBeatDatabase> with _$RecentlyPlayedDaoMixin {
  RecentlyPlayedDao(super.db);

  /// Watch recently played entries up to 50 items, ordered by playedAt descending
  Stream<List<RecentlyPlayedEntry>> watchRecentlyPlayed() {
    return (select(recentlyPlayed)
          ..orderBy([(t) => OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc)])
          ..limit(50))
        .watch();
  }

  /// Add or update a recently played song timestamp, maintaining a cap of 50 records
  Future<void> addRecentlyPlayed(int songId, [DateTime? timestamp]) async {
    final time = timestamp ?? DateTime.now();
    await into(recentlyPlayed).insertOnConflictUpdate(
      RecentlyPlayedCompanion.insert(
        songId: Value(songId),
        playedAt: Value(time),
      ),
    );

    // Enforce 50 items cap
    final entries = await (select(recentlyPlayed)
          ..orderBy([
            (t) => OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.songId, mode: OrderingMode.desc),
          ]))
        .get();

    if (entries.length > 50) {
      final excess = entries.sublist(50);
      final excessIds = excess.map((e) => e.songId).toList();
      await (delete(recentlyPlayed)..where((t) => t.songId.isIn(excessIds))).go();
    }
  }

  /// Clear recently played history
  Future<int> clearRecentlyPlayed() {
    return delete(recentlyPlayed).go();
  }
}
