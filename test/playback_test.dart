import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offbeat/data/data.dart';
import 'package:offbeat/playback/playback.dart';

void main() {
  group('MediaItem <-> Song Mappers', () {
    test('Round-trip mapping between Song and MediaItem', () {
      const originalSong = Song(
        id: 777,
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        albumId: 44,
        duration: Duration(minutes: 3, seconds: 20),
        filePath: '/storage/emulated/0/Music/blinding_lights.flac',
        mimeType: 'audio/flac',
        trackNumber: 9,
        year: 2020,
      );

      final mediaItem = songToMediaItem(originalSong);
      expect(mediaItem.id, '777');
      expect(mediaItem.title, 'Blinding Lights');
      expect(mediaItem.artist, 'The Weeknd');
      expect(mediaItem.album, 'After Hours');
      expect(mediaItem.duration, const Duration(minutes: 3, seconds: 20));
      expect(mediaItem.artUri, isNull);
      expect(mediaItem.extras?['filePath'], originalSong.filePath);

      final convertedSong = mediaItemToSong(mediaItem);
      expect(convertedSong.id, originalSong.id);
      expect(convertedSong.title, originalSong.title);
      expect(convertedSong.artist, originalSong.artist);
      expect(convertedSong.album, originalSong.album);
      expect(convertedSong.albumId, originalSong.albumId);
      expect(convertedSong.duration, originalSong.duration);
      expect(convertedSong.filePath, originalSong.filePath);
    });
  });

  group('PlayerState Model', () {
    test('Default values and copyWith', () {
      const state = PlayerState();
      expect(state.isPlaying, isFalse);
      expect(state.currentSong, isNull);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
      expect(state.shuffleEnabled, isFalse);
      expect(state.repeatMode, AudioServiceRepeatMode.none);
      expect(state.queue, isEmpty);

      const song = Song(
        id: 1,
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        duration: Duration(minutes: 3, seconds: 50),
        filePath: '/path/to/starboy.mp3',
      );

      final updated = state.copyWith(
        currentSong: song,
        isPlaying: true,
        position: const Duration(seconds: 45),
        duration: const Duration(minutes: 3, seconds: 50),
        shuffleEnabled: true,
        repeatMode: AudioServiceRepeatMode.all,
        queue: [song],
      );

      expect(updated.currentSong?.id, 1);
      expect(updated.isPlaying, isTrue);
      expect(updated.position.inSeconds, 45);
      expect(updated.shuffleEnabled, isTrue);
      expect(updated.repeatMode, AudioServiceRepeatMode.all);
      expect(updated.queue.length, 1);
    });
  });
}
