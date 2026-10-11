import 'dart:async';
import '../local/database.dart';
import '../models/models.dart';
import '../services/music_scanner.dart';

/// Central music repository combining local MediaStore scanning (source of truth
/// for track metadata) with Drift local database (user favorites, playlists, play history).
class MusicRepository {
  final MusicScanner scanner;
  final OffBeatDatabase db;

  final Map<int, Song> _songsMap = {};
  List<Song> _cachedSongs = [];
  List<Album> _cachedAlbums = [];
  List<Artist> _cachedArtists = [];

  final _songsStreamController = StreamController<List<Song>>.broadcast();
  final _albumsStreamController = StreamController<List<Album>>.broadcast();
  final _artistsStreamController = StreamController<List<Artist>>.broadcast();

  MusicRepository({
    required this.scanner,
    required this.db,
  });

  /// In-memory cache of scanned songs
  List<Song> get cachedSongs => List.unmodifiable(_cachedSongs);

  /// In-memory cache of scanned albums
  List<Album> get cachedAlbums => List.unmodifiable(_cachedAlbums);

  /// In-memory cache of scanned artists
  List<Artist> get cachedArtists => List.unmodifiable(_cachedArtists);

  /// Find a song by its unique MediaStore ID from cache
  Song? getSongById(int id) => _songsMap[id];

  /// Scan or retrieve cached songs.
  Future<List<Song>> scanAllSongs({bool forceRefresh = false}) async {
    if (_cachedSongs.isNotEmpty && !forceRefresh) {
      return _cachedSongs;
    }

    final songs = await scanner.scanSongs();
    _cachedSongs = songs;
    _songsMap.clear();
    for (final song in songs) {
      _songsMap[song.id] = song;
    }
    _songsStreamController.add(_cachedSongs);
    return _cachedSongs;
  }

  /// Scan or retrieve cached albums.
  Future<List<Album>> scanAllAlbums({bool forceRefresh = false}) async {
    if (_cachedAlbums.isNotEmpty && !forceRefresh) {
      return _cachedAlbums;
    }

    final albums = await scanner.scanAlbums();
    _cachedAlbums = albums;
    _albumsStreamController.add(_cachedAlbums);
    return _cachedAlbums;
  }

  /// Scan or retrieve cached artists.
  Future<List<Artist>> scanAllArtists({bool forceRefresh = false}) async {
    if (_cachedArtists.isNotEmpty && !forceRefresh) {
      return _cachedArtists;
    }

    final artists = await scanner.scanArtists();
    _cachedArtists = artists;
    _artistsStreamController.add(_cachedArtists);
    return _cachedArtists;
  }

  /// Rescan entire media library (songs, albums, and artists in parallel).
  Future<void> rescanLibrary() async {
    await Future.wait([
      scanAllSongs(forceRefresh: true),
      scanAllAlbums(forceRefresh: true),
      scanAllArtists(forceRefresh: true),
    ]);
  }

  /// Stream of all scanned songs.
  Stream<List<Song>> watchAllSongs() => _songsStreamController.stream;

  /// Stream of all scanned albums.
  Stream<List<Album>> watchAlbums() => _albumsStreamController.stream;

  /// Stream of all scanned artists.
  Stream<List<Artist>> watchArtists() => _artistsStreamController.stream;

  // ==========================================
  // Favorites & Hotlist Integration
  // ==========================================

  /// Watch Hotlist (favorites) powered by Drift and mapped to full [Song] models.
  Stream<List<Song>> watchHotlist() {
    return db.watchFavorites().map((favList) {
      final List<Song> hotlistSongs = [];
      for (final fav in favList) {
        final song = _songsMap[fav.songId];
        if (song != null) {
          hotlistSongs.add(song);
        }
      }
      return hotlistSongs;
    });
  }

  /// Watch set of favorite song IDs for instant O(1) checks.
  Stream<Set<int>> watchFavoriteSongIds() => db.favoritesDao.watchFavoriteSongIds();

  /// Check whether a song is marked as favorite.
  Future<bool> isFavorite(int songId) => db.isFavorite(songId);

  /// Watch favorite state of a single song.
  Stream<bool> watchIsFavorite(int songId) => db.favoritesDao.watchIsFavorite(songId);

  /// Toggle favorite status of a song. Returns true if favorited, false if unfavorited.
  Future<bool> toggleFavorite(int songId) => db.toggleFavorite(songId);

  // ==========================================
  // Recently Played Integration (Capped at 50)
  // ==========================================

  /// Watch recently played tracks mapped to full [Song] models.
  Stream<List<Song>> watchRecentlyPlayed() {
    return db.watchRecentlyPlayed().map((entries) {
      final List<Song> recentSongs = [];
      for (final entry in entries) {
        final song = _songsMap[entry.songId];
        if (song != null) {
          recentSongs.add(song);
        }
      }
      return recentSongs;
    });
  }

  /// Record a song playback into RecentlyPlayed (capped at 50).
  Future<void> addRecentlyPlayed(int songId, [DateTime? timestamp]) =>
      db.addRecentlyPlayed(songId, timestamp);

  // ==========================================
  // Playlists Integration
  // ==========================================

  /// Watch all user playlists.
  Stream<List<Playlist>> watchPlaylists() => db.watchPlaylists();

  /// Create a new playlist.
  Future<int> createPlaylist(String name) => db.createPlaylist(name);

  /// Delete a playlist.
  Future<int> deletePlaylist(int id) => db.playlistsDao.deletePlaylist(id);

  /// Watch songs belonging to a playlist mapped to full [Song] models.
  Stream<List<Song>> watchPlaylistSongs(int playlistId) {
    return db.playlistsDao.watchPlaylistSongs(playlistId).map((playlistEntries) {
      final List<Song> songs = [];
      for (final entry in playlistEntries) {
        final song = _songsMap[entry.songId];
        if (song != null) {
          songs.add(song);
        }
      }
      return songs;
    });
  }

  /// Add a song to a playlist.
  Future<void> addSongToPlaylist(int playlistId, int songId) =>
      db.addSongToPlaylist(playlistId, songId);

  /// Remove a song from a playlist.
  Future<int> removeSongFromPlaylist(int playlistId, int songId) =>
      db.removeSongFromPlaylist(playlistId, songId);
}
