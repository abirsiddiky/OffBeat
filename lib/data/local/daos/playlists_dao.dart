import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/playlists_table.dart';

part 'playlists_dao.g.dart';

@DriftAccessor(tables: [Playlists, PlaylistSongs])
class PlaylistsDao extends DatabaseAccessor<OffBeatDatabase> with _$PlaylistsDaoMixin {
  PlaylistsDao(super.db);

  /// Watch all user playlists ordered by creation date (descending)
  Stream<List<Playlist>> watchPlaylists() {
    return (select(playlists)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Create a new playlist with the given name
  Future<int> createPlaylist(String name) {
    return into(playlists).insert(
      PlaylistsCompanion.insert(
        name: name,
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a playlist and its associated playlist songs
  Future<int> deletePlaylist(int id) async {
    await (delete(playlistSongs)..where((t) => t.playlistId.equals(id))).go();
    return (delete(playlists)..where((t) => t.id.equals(id))).go();
  }

  /// Watch songs in a specific playlist ordered by position
  Stream<List<PlaylistSong>> watchPlaylistSongs(int playlistId) {
    return (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm(expression: t.position, mode: OrderingMode.asc)]))
        .watch();
  }

  /// Add a song to a playlist at the end of the list
  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    final existing = await (select(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId)))
        .get();

    final nextPosition = existing.isEmpty
        ? 0
        : existing.map((s) => s.position).reduce((a, b) => a > b ? a : b) + 1;

    await into(playlistSongs).insertOnConflictUpdate(
      PlaylistSongsCompanion.insert(
        playlistId: playlistId,
        songId: songId,
        position: nextPosition,
      ),
    );
  }

  /// Remove a song from a playlist
  Future<int> removeSongFromPlaylist(int playlistId, int songId) {
    return (delete(playlistSongs)
          ..where((t) => t.playlistId.equals(playlistId) & t.songId.equals(songId)))
        .go();
  }
}
