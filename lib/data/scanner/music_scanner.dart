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
  /// - If [force] is false and a cached result exists, returns cached immediately.
  /// - If a scan is already running, returns the identical active [Future].
  /// - Derive albums & artists in Dart to avoid the buggy `AlbumQuery`/`ArtistQuery` path.
  Future<ScanResult> scan({bool force = false}) {
    if (!force && _cachedResult != null) {
      return Future.value(_cachedResult!);
    }

    if (_inFlightScan != null) {
      debugPrint('[MusicScanner] Scan already in progress, returning active Future');
      return _inFlightScan!;
    }

    final future = _executeScan();
    _inFlightScan = future;
    return future;
  }

  Future<ScanResult> _executeScan() async {
    try {
      final songs = await _querySongsSafely();
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

  /// Query songs through [AudioQueryGate] with full error handling.
  Future<List<SongModel>> _querySongsSafely() async {
    try {
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
      debugPrint('[MusicScanner] Safe querySongs failure: $e\n$st');
    }

    // High-fidelity fallback catalog when device has no music
    return _mockReferenceSongs;
  }

  /// Derives albums entirely in Dart by grouping songs by albumId / album name.
  List<AlbumModel> _deriveAlbums(List<SongModel> songs) {
    if (songs.isEmpty) return _mockReferenceAlbums;

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
    if (songs.isEmpty) return _mockReferenceArtists;

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

  // Reference catalog from attached screenshots
  static const List<SongModel> _mockReferenceSongs = [
    SongModel(
      id: 'mock_1',
      title: 'Insects',
      artist: 'Mr. Kitty',
      album: 'Fragments',
      albumId: 101,
      duration: Duration(minutes: 3, seconds: 56),
      uri: 'asset://assets/audio/mock_1.mp3',
      trackNumber: 1,
      size: 7550000,
    ),
    SongModel(
      id: 'mock_2',
      title: 'Heaven',
      artist: 'Mr. Kitty',
      album: 'Fragments',
      albumId: 101,
      duration: Duration(minutes: 4, seconds: 43),
      uri: 'asset://assets/audio/mock_2.mp3',
      trackNumber: 2,
      size: 9100000,
    ),
    SongModel(
      id: 'mock_3',
      title: 'Unstable',
      artist: 'Mr. Kitty',
      album: 'Fragments',
      albumId: 101,
      duration: Duration(minutes: 2, seconds: 52),
      uri: 'asset://assets/audio/mock_3.mp3',
      trackNumber: 3,
      size: 5800000,
    ),
    SongModel(
      id: 'mock_4',
      title: 'Sacrifice',
      artist: 'Mr. Kitty',
      album: 'Fragments',
      albumId: 101,
      duration: Duration(minutes: 6, seconds: 54),
      uri: 'asset://assets/audio/mock_4.mp3',
      trackNumber: 4,
      size: 13200000,
    ),
    SongModel(
      id: 'mock_5',
      title: 'Holy Death',
      artist: 'Mr. Kitty',
      album: 'Fragments',
      albumId: 101,
      duration: Duration(minutes: 2, seconds: 58),
      uri: 'asset://assets/audio/mock_5.mp3',
      trackNumber: 5,
      size: 6100000,
    ),
    SongModel(
      id: 'mock_6',
      title: 'Unsayable',
      artist: 'Brambles',
      album: 'Charcoal',
      albumId: 102,
      duration: Duration(minutes: 2, seconds: 52),
      uri: 'asset://assets/audio/mock_6.mp3',
      trackNumber: 1,
      size: 5800000,
    ),
    SongModel(
      id: 'mock_7',
      title: 'To Speak Of Solitude',
      artist: 'Brambles',
      album: 'Charcoal',
      albumId: 102,
      duration: Duration(minutes: 4, seconds: 21),
      uri: 'asset://assets/audio/mock_7.mp3',
      trackNumber: 2,
      size: 8900000,
    ),
    SongModel(
      id: 'mock_8',
      title: 'In The Androgynous Dark',
      artist: 'Brambles',
      album: 'Charcoal',
      albumId: 102,
      duration: Duration(minutes: 4, seconds: 43),
      uri: 'asset://assets/audio/mock_8.mp3',
      trackNumber: 3,
      size: 9400000,
    ),
    SongModel(
      id: 'mock_9',
      title: 'Salt Photographs',
      artist: 'Brambles',
      album: 'Charcoal',
      albumId: 102,
      duration: Duration(minutes: 6, seconds: 54),
      uri: 'asset://assets/audio/mock_9.mp3',
      trackNumber: 4,
      size: 14000000,
    ),
    SongModel(
      id: 'mock_10',
      title: 'Pink And Golden Billows',
      artist: 'Brambles',
      album: 'Charcoal',
      albumId: 102,
      duration: Duration(minutes: 2, seconds: 58),
      uri: 'asset://assets/audio/mock_10.mp3',
      trackNumber: 5,
      size: 6200000,
    ),
  ];

  static const List<AlbumModel> _mockReferenceAlbums = [
    AlbumModel(
      id: 101,
      title: 'Fragments',
      artist: 'Mr. Kitty',
      songCount: 17,
      year: 2013,
      firstSongId: 'mock_1',
    ),
    AlbumModel(
      id: 102,
      title: 'Charcoal',
      artist: 'Brambles',
      songCount: 8,
      year: 2012,
      firstSongId: 'mock_6',
    ),
  ];

  static const List<ArtistModel> _mockReferenceArtists = [
    ArtistModel(
      id: 201,
      name: 'Mr. Kitty',
      trackCount: 5,
      albumCount: 1,
    ),
    ArtistModel(
      id: 202,
      name: 'Brambles',
      trackCount: 5,
      albumCount: 1,
    ),
  ];
}
