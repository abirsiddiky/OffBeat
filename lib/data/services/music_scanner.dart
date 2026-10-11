import 'package:on_audio_query_forked/on_audio_query.dart';
import '../models/models.dart';

/// Service responsible for scanning local audio tracks, albums, and artists via MediaStore.
class MusicScanner {
  final OnAudioQuery _audioQuery;

  MusicScanner({OnAudioQuery? audioQuery})
      : _audioQuery = audioQuery ?? OnAudioQuery();

  /// Queries all device music files, filtering out ringtones, alarms, notifications,
  /// and short clips under 5 seconds.
  Future<List<Song>> scanSongs() async {
    try {
      final rawSongs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      return rawSongs
          .where((s) {
            // Respect MediaStore flags where present
            if (s.isMusic == false) return false;
            if (s.isAlarm == true || s.isRingtone == true || s.isNotification == true) {
              return false;
            }
            final duration = s.duration ?? 0;
            // Filter audio clips shorter than 5 seconds
            if (duration < 5000) return false;
            return true;
          })
          .map(Song.fromSongModel)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Queries all music albums from MediaStore.
  Future<List<Album>> scanAlbums() async {
    try {
      final rawAlbums = await _audioQuery.queryAlbums(
        sortType: AlbumSortType.ALBUM,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      return rawAlbums
          .where((a) => a.numOfSongs > 0)
          .map(Album.fromAlbumModel)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Queries all music artists from MediaStore.
  Future<List<Artist>> scanArtists() async {
    try {
      final rawArtists = await _audioQuery.queryArtists(
        sortType: ArtistSortType.ARTIST,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      return rawArtists
          .where((a) => (a.numberOfTracks ?? 0) > 0)
          .map(Artist.fromArtistModel)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
