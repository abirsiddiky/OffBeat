import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offbeat/data/artwork/artwork_service.dart';
import 'package:offbeat/data/models/song_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('offbeat_test_cache_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  const song1 = SongModel(
    id: '101',
    title: 'First Track',
    artist: 'Artist One',
    album: 'Album Alpha',
    albumId: 1,
    duration: Duration(seconds: 180),
    uri: '/storage/emulated/0/Music/test1.mp3',
  );

  const song2 = SongModel(
    id: '102',
    title: 'Second Track',
    artist: 'Artist Two',
    album: 'Album Beta',
    albumId: 2,
    duration: Duration(seconds: 210),
    uri: '/storage/emulated/0/Music/test2.mp3',
  );

  group('Fast Notification Artwork Cache Tests', () {
    test('getCachedNotificationArtworkUri returns null for uncached song', () async {
      await ArtworkService.init();

      final nonExistent = ArtworkService.getCachedNotificationArtworkUri(songId: 'non_existent_999');
      expect(nonExistent, isNull);
    });

    test('toMediaItem creates valid MediaItem with and without artUri', () {
      final itemWithoutArt = song1.toMediaItem();
      expect(itemWithoutArt.id, '101');
      expect(itemWithoutArt.title, 'First Track');
      expect(itemWithoutArt.artist, 'Artist One');
      expect(itemWithoutArt.album, 'Album Alpha');
      expect(itemWithoutArt.artUri, isNull);

      final artUri = Uri.file('${tempDir.path}/art_notif_102.jpg');
      final itemWithArt = song2.toMediaItem(artUri: artUri);
      expect(itemWithArt.id, '102');
      expect(itemWithArt.title, 'Second Track');
      expect(itemWithArt.artUri, artUri);
    });

    test('getCachedNotificationArtworkUri reads cached art file instantly when present', () async {
      await ArtworkService.init();

      final dummyArt = File('${tempDir.path}/art_notif_dummy_123.jpg');
      await dummyArt.writeAsBytes(List.filled(1024, 0xFF));

      final cached = ArtworkService.getCachedNotificationArtworkUri(songId: 'dummy_123');
      expect(cached, isNotNull);
      expect(File(cached!.toFilePath()).existsSync(), isTrue);
      expect(File(cached.toFilePath()).lengthSync(), 1024);

      await dummyArt.delete();
    });
  });
}
