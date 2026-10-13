import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Favorites extends Table {
  TextColumn get songId => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {songId};
}

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class PlaylistSongs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer()();
  TextColumn get songId => text()();
  IntColumn get sortOrder => integer()();
}

class RecentlyPlayed extends Table {
  TextColumn get songId => text()();
  DateTimeColumn get playedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {songId};
}

@DriftDatabase(tables: [Favorites, Playlists, PlaylistSongs, RecentlyPlayed])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Favorites
  Stream<List<String>> watchFavoriteSongIds() {
    return (select(favorites)
          ..orderBy([(t) => OrderingTerm(expression: t.addedAt, mode: OrderingMode.desc)]))
        .map((row) => row.songId)
        .watch();
  }

  Future<bool> isFavorite(String songId) async {
    final query = select(favorites)..where((t) => t.songId.equals(songId));
    final result = await query.getSingleOrNull();
    return result != null;
  }

  Future<void> toggleFavorite(String songId) async {
    final exists = await isFavorite(songId);
    if (exists) {
      await (delete(favorites)..where((t) => t.songId.equals(songId))).go();
    } else {
      await into(favorites).insert(
        FavoritesCompanion.insert(
          songId: songId,
          addedAt: DateTime.now(),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
  }

  // Recently Played (Cap 50)
  Stream<List<String>> watchRecentlyPlayedSongIds() {
    return (select(recentlyPlayed)
          ..orderBy([(t) => OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc)])
          ..limit(50))
        .map((row) => row.songId)
        .watch();
  }

  Future<void> addRecentlyPlayed(String songId) async {
    await into(recentlyPlayed).insert(
      RecentlyPlayedCompanion.insert(
        songId: songId,
        playedAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );

    // Enforce cap of 50
    final allRecent = await (select(recentlyPlayed)
          ..orderBy([(t) => OrderingTerm(expression: t.playedAt, mode: OrderingMode.desc)]))
        .get();

    if (allRecent.length > 50) {
      final excess = allRecent.sublist(50);
      for (final item in excess) {
        await (delete(recentlyPlayed)..where((t) => t.songId.equals(item.songId))).go();
      }
    }
  }

  // Playlists
  Stream<List<Playlist>> watchPlaylists() {
    return (select(playlists)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<int> createPlaylist(String name) async {
    return await into(playlists).insert(
      PlaylistsCompanion.insert(
        name: name,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> renamePlaylist(int id, String newName) async {
    await (update(playlists)..where((t) => t.id.equals(id))).write(
      PlaylistsCompanion(name: Value(newName)),
    );
  }

  Future<void> deletePlaylist(int id) async {
    await transaction(() async {
      await (delete(playlistSongs)..where((t) => t.playlistId.equals(id))).go();
      await (delete(playlists)..where((t) => t.id.equals(id))).go();
    });
  }

  // Playlist Songs
  Stream<List<String>> watchPlaylistSongIds(int playlistId) {
    return (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder, mode: OrderingMode.asc)]))
        .map((row) => row.songId)
        .watch();
  }

  Future<void> addSongToPlaylist(int playlistId, String songId) async {
    final existing = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId)))
        .getSingleOrNull();
    if (existing != null) return;

    final currentSongs = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId)))
        .get();

    await into(playlistSongs).insert(
      PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        sortOrder: currentSongs.length,
      ),
    );
  }

  Future<void> removeSongFromPlaylist(int playlistId, String songId) async {
    await (delete(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId)))
        .go();
  }

  Future<void> reorderPlaylistSongs(int playlistId, List<String> orderedSongIds) async {
    await transaction(() async {
      await (delete(playlistSongs)..where((t) => t.playlistId.equals(playlistId))).go();
      for (int i = 0; i < orderedSongIds.length; i++) {
        await into(playlistSongs).insert(
          PlaylistSongsCompanion.insert(
            playlistId: playlistId,
            songId: orderedSongIds[i],
            sortOrder: i,
          ),
        );
      }
    });
  }

  Future<void> deleteSongData(String songId) async {
    await transaction(() async {
      await (delete(favorites)..where((t) => t.songId.equals(songId))).go();
      await (delete(playlistSongs)..where((t) => t.songId.equals(songId))).go();
      await (delete(recentlyPlayed)..where((t) => t.songId.equals(songId))).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File('${dbFolder.path}/offbeat.sqlite');
    return NativeDatabase.createInBackground(file);
  });
}
