import 'package:flutter_test/flutter_test.dart';
import 'package:offbeat/data/models/song_model.dart';
import 'package:offbeat/data/scanner/music_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MusicScanner tests', () {
    test('force=false returns cachedResult if available', () async {
      final scanner = MusicScanner();
      const mockResult = ScanResult(
        songs: [
          SongModel(
            id: '1',
            title: 'Song 1',
            artist: 'Artist 1',
            album: 'Album 1',
            duration: Duration(seconds: 180),
            uri: '/storage/1.mp3',
          ),
        ],
        albums: [],
        artists: [],
      );

      scanner.updateCachedResult(mockResult);

      final result = await scanner.scan(force: false);
      expect(result.songs.length, 1);
      expect(result.songs.first.id, '1');
    });

    test('deriveAlbums and deriveArtists group songs properly in Dart', () {
      final scanner = MusicScanner();
      final songs = [
        const SongModel(
          id: '1',
          title: 'Track A',
          artist: 'Artist Alpha',
          album: 'Album One',
          albumId: 10,
          duration: Duration(minutes: 3),
          uri: '/a.mp3',
        ),
        const SongModel(
          id: '2',
          title: 'Track B',
          artist: 'Artist Alpha',
          album: 'Album One',
          albumId: 10,
          duration: Duration(minutes: 4),
          uri: '/b.mp3',
        ),
        const SongModel(
          id: '3',
          title: 'Track C',
          artist: 'Artist Beta',
          album: 'Album Two',
          albumId: 20,
          duration: Duration(minutes: 2),
          uri: '/c.mp3',
        ),
      ];

      final albums = scanner.deriveAlbums(songs);
      expect(albums.length, 2);
      expect(albums.firstWhere((a) => a.id == 10).songCount, 2);
      expect(albums.firstWhere((a) => a.id == 20).songCount, 1);

      final artists = scanner.deriveArtists(songs);
      expect(artists.length, 2);
      expect(artists.firstWhere((a) => a.name == 'Artist Alpha').trackCount, 2);
      expect(artists.firstWhere((a) => a.name == 'Artist Beta').trackCount, 1);
    });

    test('removeSongFromCache removes song and re-derives albums/artists', () {
      final scanner = MusicScanner();
      final songs = [
        const SongModel(
          id: '101',
          title: 'Track 1',
          artist: 'Artist 1',
          album: 'Album 1',
          albumId: 1,
          duration: Duration(minutes: 3),
          uri: '/1.mp3',
        ),
        const SongModel(
          id: '102',
          title: 'Track 2',
          artist: 'Artist 2',
          album: 'Album 2',
          albumId: 2,
          duration: Duration(minutes: 4),
          uri: '/2.mp3',
        ),
      ];

      final initialResult = ScanResult(
        songs: songs,
        albums: scanner.deriveAlbums(songs),
        artists: scanner.deriveArtists(songs),
      );
      scanner.updateCachedResult(initialResult);

      expect(scanner.cachedResult!.songs.length, 2);

      scanner.removeSongFromCache('101');

      expect(scanner.cachedResult!.songs.length, 1);
      expect(scanner.cachedResult!.songs.first.id, '102');
      expect(scanner.cachedResult!.albums.length, 1);
      expect(scanner.cachedResult!.artists.length, 1);
    });
  });
}
