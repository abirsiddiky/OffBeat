import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../scanner/music_scanner.dart';

class MusicRepository {
  final AppDatabase db;
  final MusicScanner scanner;
  final VoidCallback? onRescanTriggered;

  final _songsController = StreamController<List<SongModel>>.broadcast();
  final _albumsController = StreamController<List<AlbumModel>>.broadcast();
  final _artistsController = StreamController<List<ArtistModel>>.broadcast();

  List<SongModel> _cachedSongs = [];
  List<AlbumModel> _cachedAlbums = [];
  List<ArtistModel> _cachedArtists = [];

  MusicRepository({
    required this.db,
    required this.scanner,
    this.onRescanTriggered,
  }) {
    // DO NOT trigger an unverified scan on constructor startup.
    // Scan is triggered exactly once after storage permission is confirmed granted.
    if (scanner.cachedResult != null) {
      updateFromScan(scanner.cachedResult!);
    }
  }

  List<SongModel> get currentSongs => _cachedSongs;
  List<AlbumModel> get currentAlbums => _cachedAlbums;
  List<ArtistModel> get currentArtists => _cachedArtists;

  Stream<List<SongModel>> watchSongs() async* {
    if (_cachedSongs.isNotEmpty) {
      yield _cachedSongs;
    }
    yield* _songsController.stream;
  }

  Stream<List<AlbumModel>> watchAlbums() async* {
    if (_cachedAlbums.isNotEmpty) {
      yield _cachedAlbums;
    }
    yield* _albumsController.stream;
  }

  Stream<List<ArtistModel>> watchArtists() async* {
    if (_cachedArtists.isNotEmpty) {
      yield _cachedArtists;
    }
    yield* _artistsController.stream;
  }

  /// Single-flight library rescan.
  Future<ScanResult> rescan({bool force = true}) async {
    final result = await scanner.scan(force: force);
    updateFromScan(result);
    onRescanTriggered?.call();
    return result;
  }

  void updateFromScan(ScanResult result) {
    _cachedSongs = result.songs;
    _cachedAlbums = result.albums;
    _cachedArtists = result.artists;

    _songsController.add(result.songs);
    _albumsController.add(result.albums);
    _artistsController.add(result.artists);
  }

  // Favorites
  Stream<List<SongModel>> watchFavorites() {
    return db.watchFavoriteSongIds().map((ids) {
      final idSet = ids.toSet();
      return _cachedSongs.where((s) => idSet.contains(s.id)).toList();
    });
  }

  Future<bool> isFavorite(String songId) => db.isFavorite(songId);

  Future<void> toggleFavorite(String songId) => db.toggleFavorite(songId);

  // Recently Played (ordered by playedAt desc, distinct songId, max 20)
  Stream<List<SongModel>> watchRecentlyPlayed({List<SongModel>? songsSource}) {
    return db.watchRecentlyPlayedSongIds().map((ids) {
      final songs = (songsSource != null && songsSource.isNotEmpty) ? songsSource : _cachedSongs;
      final map = {for (final s in songs) s.id: s};
      final seen = <String>{};
      final result = <SongModel>[];

      for (final id in ids) {
        if (!seen.add(id)) continue;
        final song = map[id];
        // Skip entries whose song no longer exists on the device
        if (song != null) {
          result.add(song);
          if (result.length >= 20) break;
        }
      }
      return result;
    });
  }

  Future<void> logRecentlyPlayed(String songId) => db.addRecentlyPlayed(songId);

  // Playlists
  Stream<List<PlaylistModel>> watchPlaylists() {
    return db.watchPlaylists().asyncMap((playlists) async {
      final list = <PlaylistModel>[];
      for (final p in playlists) {
        final songIds = await (db.select(db.playlistSongs)..where((t) => t.playlistId.equals(p.id))).get();
        list.add(PlaylistModel(
          id: p.id,
          name: p.name,
          songCount: songIds.length,
          createdAt: p.createdAt,
        ));
      }
      return list;
    });
  }

  Stream<List<SongModel>> watchPlaylistSongs(int playlistId) {
    return db.watchPlaylistSongIds(playlistId).map((ids) {
      final map = {for (final s in _cachedSongs) s.id: s};
      return ids.map((id) => map[id]).whereType<SongModel>().toList();
    });
  }

  Future<int> createPlaylist(String name) => db.createPlaylist(name);
  Future<void> renamePlaylist(int id, String newName) => db.renamePlaylist(id, newName);
  Future<void> deletePlaylist(int id) => db.deletePlaylist(id);
  Future<void> addSongToPlaylist(int playlistId, String songId) => db.addSongToPlaylist(playlistId, songId);
  Future<void> removeSongFromPlaylist(int playlistId, String songId) => db.removeSongFromPlaylist(playlistId, songId);
  Future<void> reorderPlaylistSongs(int playlistId, List<String> orderedSongIds) =>
      db.reorderPlaylistSongs(playlistId, orderedSongIds);

  void dispose() {
    _songsController.close();
    _albumsController.close();
    _artistsController.close();
  }
}

// Providers
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final musicScannerProvider = Provider<MusicScanner>((ref) {
  return MusicScanner();
});

final Provider<MusicRepository> musicRepositoryProvider = Provider<MusicRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final scanner = ref.watch(musicScannerProvider);
  final repo = MusicRepository(
    db: db,
    scanner: scanner,
    onRescanTriggered: () {
      ref.invalidate(cachedScanProvider);
    },
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// In-memory keep-alive provider holding the single-flight library scan result.
/// Home, Library, Search, Hotlist, Album Detail all read data derived from this cached provider.
final FutureProvider<ScanResult> cachedScanProvider = FutureProvider<ScanResult>((ref) async {
  ref.keepAlive();
  final scanner = ref.watch(musicScannerProvider);
  final result = await scanner.scan(force: true);
  ref.read(musicRepositoryProvider).updateFromScan(result);
  return result;
});

/// Alias for cachedScanProvider representing the library state
final libraryProvider = cachedScanProvider;

final allSongsProvider = Provider<AsyncValue<List<SongModel>>>((ref) {
  ref.keepAlive();
  return ref.watch(cachedScanProvider).whenData((scan) => scan.songs);
});

final allAlbumsProvider = Provider<AsyncValue<List<AlbumModel>>>((ref) {
  ref.keepAlive();
  return ref.watch(cachedScanProvider).whenData((scan) => scan.albums);
});

final allArtistsProvider = Provider<AsyncValue<List<ArtistModel>>>((ref) {
  ref.keepAlive();
  return ref.watch(cachedScanProvider).whenData((scan) => scan.artists);
});

final favoritesProvider = StreamProvider<List<SongModel>>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.watchFavorites();
});

final recentlyPlayedProvider = StreamProvider<List<SongModel>>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  final allSongsAsync = ref.watch(allSongsProvider);
  final songsSource = allSongsAsync.value ?? repo.currentSongs;
  return repo.watchRecentlyPlayed(songsSource: songsSource);
});

final playlistsProvider = StreamProvider<List<PlaylistModel>>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.watchPlaylists();
});

final playlistSongsProvider = StreamProvider.family<List<SongModel>, int>((ref, playlistId) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.watchPlaylistSongs(playlistId);
});

final albumSongsProvider = Provider.family<List<SongModel>, int>((ref, albumId) {
  final songs = ref.watch(allSongsProvider).value ?? [];
  return songs.where((s) => s.albumId == albumId).toList();
});
