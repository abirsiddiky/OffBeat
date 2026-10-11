import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/favorites_table.dart';
import 'tables/playlists_table.dart';
import 'tables/recently_played_table.dart';

import 'daos/favorites_dao.dart';
import 'daos/playlists_dao.dart';
import 'daos/recently_played_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Favorites, Playlists, PlaylistSongs, RecentlyPlayed],
  daos: [FavoritesDao, PlaylistsDao, RecentlyPlayedDao],
)
class OffBeatDatabase extends _$OffBeatDatabase {
  OffBeatDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'offbeat_database');
  }

  // Convenience query delegates to DAOs
  Stream<List<Favorite>> watchFavorites() => favoritesDao.watchFavorites();
  Future<bool> toggleFavorite(int songId) => favoritesDao.toggleFavorite(songId);
  Future<bool> isFavorite(int songId) => favoritesDao.isFavorite(songId);

  Stream<List<Playlist>> watchPlaylists() => playlistsDao.watchPlaylists();
  Future<int> createPlaylist(String name) => playlistsDao.createPlaylist(name);
  Future<void> addSongToPlaylist(int playlistId, int songId) =>
      playlistsDao.addSongToPlaylist(playlistId, songId);
  Future<int> removeSongFromPlaylist(int playlistId, int songId) =>
      playlistsDao.removeSongFromPlaylist(playlistId, songId);

  Stream<List<RecentlyPlayedEntry>> watchRecentlyPlayed() =>
      recentlyPlayedDao.watchRecentlyPlayed();
  Future<void> addRecentlyPlayed(int songId, [DateTime? timestamp]) =>
      recentlyPlayedDao.addRecentlyPlayed(songId, timestamp);
}
