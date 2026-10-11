import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offbeat/data/data.dart';

void main() {
  group('Domain Models', () {
    test('Song model creation and properties', () {
      const song = Song(
        id: 101,
        title: 'Echoes of Silence',
        artist: 'The Weeknd',
        album: 'Trilogy',
        albumId: 42,
        duration: Duration(minutes: 4, seconds: 2),
        filePath: '/storage/emulated/0/Music/echoes.flac',
        mimeType: 'audio/flac',
        trackNumber: 5,
        year: 2012,
      );

      expect(song.id, 101);
      expect(song.durationMs, 242000);
      expect(song.fileExtension, 'flac');
      expect(song.title, 'Echoes of Silence');
      expect(song.artist, 'The Weeknd');

      final map = song.toMap();
      final fromMap = Song.fromMap(map);
      expect(fromMap.id, song.id);
      expect(fromMap.title, song.title);
      expect(fromMap.duration, song.duration);
    });

    test('Album and Artist models', () {
      const album = Album(
        id: 12,
        title: 'After Hours',
        artist: 'The Weeknd',
        artistId: 5,
        numberOfSongs: 14,
      );
      expect(album.numberOfSongs, 14);

      const artist = Artist(
        id: 5,
        name: 'The Weeknd',
        numberOfAlbums: 6,
        numberOfTracks: 85,
      );
      expect(artist.numberOfTracks, 85);
    });
  });

  group('OffBeatDatabase & DAOs (In-Memory)', () {
    late OffBeatDatabase db;

    setUp(() {
      db = OffBeatDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('FavoritesDao - toggle and watch favorites', () async {
      expect(await db.isFavorite(1), isFalse);

      final added = await db.toggleFavorite(1);
      expect(added, isTrue);
      expect(await db.isFavorite(1), isTrue);

      final favorites = await db.watchFavorites().first;
      expect(favorites.length, 1);
      expect(favorites.first.songId, 1);

      final removed = await db.toggleFavorite(1);
      expect(removed, isFalse);
      expect(await db.isFavorite(1), isFalse);
    });

    test('PlaylistsDao - create playlist and manage songs', () async {
      final playlistId = await db.createPlaylist('Late Night Jams');
      expect(playlistId, isPositive);

      final playlists = await db.watchPlaylists().first;
      expect(playlists.length, 1);
      expect(playlists.first.name, 'Late Night Jams');

      await db.addSongToPlaylist(playlistId, 101);
      await db.addSongToPlaylist(playlistId, 102);

      final songs = await db.playlistsDao.watchPlaylistSongs(playlistId).first;
      expect(songs.length, 2);
      expect(songs.first.songId, 101);
      expect(songs.last.songId, 102);

      await db.removeSongFromPlaylist(playlistId, 101);
      final remaining = await db.playlistsDao.watchPlaylistSongs(playlistId).first;
      expect(remaining.length, 1);
      expect(remaining.first.songId, 102);
    });

    test('RecentlyPlayedDao - maintains max 50 entries', () async {
      for (int i = 1; i <= 55; i++) {
        await db.addRecentlyPlayed(i, DateTime.now().add(Duration(seconds: i)));
      }

      final recent = await db.watchRecentlyPlayed().first;
      expect(recent.length, 50);
      expect(recent.first.songId, 55); // Most recently added is first
    });
  });
}
