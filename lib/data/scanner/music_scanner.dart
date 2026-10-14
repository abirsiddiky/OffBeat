import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query_forked/on_audio_query.dart'
    hide SongModel, AlbumModel, ArtistModel;
import '../audio_query_gate.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/song_model.dart';

/// Container for the results of a music library scan.
class ScanResult {
  final List<SongModel> songs;
  final List<AlbumModel> albums;
  final List<ArtistModel> artists;

  const ScanResult({
    required this.songs,
    required this.albums,
    required this.artists,
  });

  static const ScanResult empty = ScanResult(
    songs: [],
    albums: [],
    artists: [],
  );
}

/// Single-flight music scanner that queries songs once and derives albums and artists in Dart.
class MusicScanner {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<ScanResult>? _inFlightScan;
  ScanResult? _cachedResult;

  /// In-memory cached result of the last successful scan.
  ScanResult? get cachedResult => _cachedResult;

  /// Scans songs from on_audio_query with single-flight deduplication.
  ///
  /// - If a scan is in flight, returns the same Future when [force] is false;
  ///   when [force] is true and a scan is running, ignores the tap (returns the running Future).
  /// - When [force] is false and a cached result exists, returns cached immediately.
  /// - When [force] is true and nothing is running, ALWAYS bypasses cached list and runs fresh querySongs via AudioQueryGate.
  Future<ScanResult> scan({bool force = false}) {
    if (_inFlightScan != null) {
      debugPrint('[MusicScanner] Scan already in progress, returning active Future');
      return _inFlightScan!;
    }

    if (!force && _cachedResult != null) {
      return Future.value(_cachedResult!);
    }

    final future = _executeScan();
    _inFlightScan = future;
    return future;
  }

  /// Sets or updates the cached scan result in memory.
  void updateCachedResult(ScanResult result) {
    _cachedResult = result;
  }

  /// Removes a song by ID from cache and re-derives albums & artists in Dart.
  void removeSongFromCache(String songId) {
    if (_cachedResult == null) return;
    final updatedSongs = _cachedResult!.songs.where((s) => s.id != songId).toList();
    final updatedAlbums = deriveAlbums(updatedSongs);
    final updatedArtists = deriveArtists(updatedSongs);
    _cachedResult = ScanResult(
      songs: updatedSongs,
      albums: updatedAlbums,
      artists: updatedArtists,
    );
  }

  /// Derives albums entirely in Dart by grouping songs by albumId / album name.
  List<AlbumModel> deriveAlbums(List<SongModel> songs) => _deriveAlbums(songs);

  /// Derives artists entirely in Dart by grouping songs by artist name.
  List<ArtistModel> deriveArtists(List<SongModel> songs) => _deriveArtists(songs);

  Future<ScanResult> _executeScan() async {
    try {
      final songs = await _querySongsSafely();

      // If transient scan returned empty but we previously had loaded songs, preserve them
      if (songs.isEmpty && _cachedResult != null && _cachedResult!.songs.isNotEmpty) {
        debugPrint('[MusicScanner] Query returned 0 songs, keeping previous non-empty cached result');
        return _cachedResult!;
      }

      final albums = _deriveAlbums(songs);
      final artists = _deriveArtists(songs);

      final result = ScanResult(
        songs: songs,
        albums: albums,
        artists: artists,
      );
      _cachedResult = result;
      return result;
    } catch (e, st) {
      debugPrint('[MusicScanner] Unexpected error during scan: $e\n$st');
      return _cachedResult ?? ScanResult.empty;
    } finally {
      _inFlightScan = null;
    }
  }

  /// Query songs through [AudioQueryGate] with retry and error handling.
  Future<List<SongModel>> _querySongsSafely() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (attempt > 0) {
          await Future.delayed(Duration(milliseconds: 350 * attempt));
        }

        final rawSongs = await AudioQueryGate.run(() async {
          return await _audioQuery.querySongs(
            sortType: SongSortType.DATE_ADDED,
            orderType: OrderType.DESC_OR_GREATER,
            uriType: UriType.EXTERNAL,
            ignoreCase: true,
          );
        });

        final songs = <SongModel>[];
        for (final s in rawSongs) {
          // Exclude sound effects, ringtones, or audio clips shorter than 5 seconds
          if ((s.duration ?? 0) < 5000) continue;

          songs.add(
            SongModel(
              id: s.id.toString(),
              title: (s.title.isNotEmpty ? s.title : s.displayNameWOExt).trim(),
              artist: (s.artist != null && s.artist!.isNotEmpty && s.artist != '<unknown>')
                  ? s.artist!.trim()
                  : 'Unknown Artist',
              album: (s.album != null && s.album!.isNotEmpty && s.album != '<unknown>')
                  ? s.album!.trim()
                  : 'Unknown Album',
              albumId: s.albumId,
              duration: Duration(milliseconds: s.duration ?? 0),
              uri: s.data,
              trackNumber: s.track,
              size: s.size,
              dateAdded: s.dateAdded,
            ),
          );
        }

        if (songs.isNotEmpty) {
          return songs;
        }
      } catch (e, st) {
        debugPrint('[MusicScanner] Safe querySongs attempt $attempt failure: $e\n$st');
      }
    }

    return [];
  }

  /// Derives albums entirely in Dart by grouping songs by albumId / album name.
  List<AlbumModel> _deriveAlbums(List<SongModel> songs) {
    if (songs.isEmpty) return [];

    final albumMap = <int, List<SongModel>>{};
    final fallbackTitleIds = <String, int>{};

    for (final song in songs) {
      final albumTitle = song.album.trim().isNotEmpty ? song.album.trim() : 'Unknown Album';
      int albumId;

      if (song.albumId != null && song.albumId! > 0) {
        albumId = song.albumId!;
      } else {
        albumId = fallbackTitleIds.putIfAbsent(
          albumTitle.toLowerCase(),
          () => albumTitle.hashCode.abs(),
        );
      }

      albumMap.putIfAbsent(albumId, () => []).add(song);
    }

    final albums = <AlbumModel>[];
    for (final entry in albumMap.entries) {
      final albumSongs = entry.value;
      final firstSong = albumSongs.first;
      final albumTitle = firstSong.album;
      final albumArtist = firstSong.artist;

      // Extract year from dateAdded if available
      int? year;
      for (final s in albumSongs) {
        if (s.dateAdded != null && s.dateAdded! > 0) {
          final dt = DateTime.fromMillisecondsSinceEpoch(s.dateAdded! * 1000);
          year = dt.year;
          break;
        }
      }

      albums.add(
        AlbumModel(
          id: entry.key,
          title: albumTitle,
          artist: albumArtist,
          songCount: albumSongs.length,
          year: year,
          firstSongId: firstSong.id,
        ),
      );
    }

    albums.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return albums;
  }

  /// Derives artists entirely in Dart by grouping songs by artist name.
  List<ArtistModel> _deriveArtists(List<SongModel> songs) {
    if (songs.isEmpty) return [];

    final artistMap = <String, List<SongModel>>{};
    for (final song in songs) {
      final artistName = song.artist.trim().isNotEmpty ? song.artist.trim() : 'Unknown Artist';
      artistMap.putIfAbsent(artistName, () => []).add(song);
    }

    final artists = <ArtistModel>[];
    var syntheticId = 1;
    for (final entry in artistMap.entries) {
      final artistName = entry.key;
      final artistSongs = entry.value;
      final distinctAlbums = artistSongs.map((s) => s.album.toLowerCase()).toSet().length;

      artists.add(
        ArtistModel(
          id: syntheticId++,
          name: artistName,
          trackCount: artistSongs.length,
          albumCount: distinctAlbums,
        ),
      );
    }

    artists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return artists;
  }

  /// Backward-compatible single-flight song scan delegate.
  Future<List<SongModel>> scanSongs({bool force = false}) async {
    final result = await scan(force: force);
    return result.songs;
  }

  /// Backward-compatible single-flight album scan delegate.
  Future<List<AlbumModel>> scanAlbums({bool force = false}) async {
    final result = await scan(force: force);
    return result.albums;
  }

  /// Backward-compatible single-flight artist scan delegate.
  Future<List<ArtistModel>> scanArtists({bool force = false}) async {
    final result = await scan(force: force);
    return result.artists;
  }
}
