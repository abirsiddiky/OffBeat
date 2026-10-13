import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/song_model.dart';
import '../data/repository/music_repository.dart';
import 'audio_handler.dart';

final audioHandlerProvider = Provider<OffBeatAudioHandler>((ref) {
  throw UnimplementedError('Initialize audioHandlerProvider in main()');
});

final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.mediaItem;
});

final currentSongProvider = Provider<SongModel?>((ref) {
  final mediaItem = ref.watch(currentMediaItemProvider).value;
  if (mediaItem == null) return null;
  return SongModel.fromMediaItem(mediaItem);
});

final playbackStateStreamProvider = StreamProvider<PlaybackState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState;
});

final isPlayingProvider = Provider<bool>((ref) {
  final state = ref.watch(playbackStateStreamProvider).value;
  return state?.playing ?? false;
});

final currentPositionProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.stream.position;
});

final currentDurationProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.stream.duration;
});

final repeatModeProvider = Provider<AudioServiceRepeatMode>((ref) {
  final state = ref.watch(playbackStateStreamProvider).value;
  return state?.repeatMode ?? AudioServiceRepeatMode.none;
});

final isShuffleEnabledProvider = Provider<bool>((ref) {
  final state = ref.watch(playbackStateStreamProvider).value;
  return state?.shuffleMode == AudioServiceShuffleMode.all;
});

class AudioController {
  final OffBeatAudioHandler handler;
  final MusicRepository repository;

  AudioController(this.handler, this.repository) {
    handler.onTrackChanged = (songId) {
      repository.logRecentlyPlayed(songId);
    };
  }

  void play() => handler.play();
  void pause() => handler.pause();
  void togglePlay() {
    if (handler.player.state.playing) {
      handler.pause();
    } else {
      handler.play();
    }
  }

  void skipToNext() => handler.skipToNext();
  void skipToPrevious() => handler.skipToPrevious();
  void seek(Duration pos) => handler.seek(pos);
  void toggleRepeat() => handler.toggleRepeatMode();
  void toggleShuffle() => handler.toggleShuffleMode();

  void playSong(SongModel song) {
    handler.playSingle(song);
  }

  void playQueue(List<SongModel> songs, {int initialIndex = 0}) {
    handler.setQueueAndPlay(songs, initialIndex: initialIndex);
  }

  void playNext(SongModel song) => handler.playNextInQueue(song);
  void addToQueue(SongModel song) => handler.addToQueueEnd(song);
  void removeFromQueue(int index) => handler.removeQueueItemAt(index);
  void reorderQueue(int oldIndex, int newIndex) => handler.reorderQueueItem(oldIndex, newIndex);
  void jumpToQueueItem(int index) => handler.skipToQueueItem(index);
  void clearUpcomingQueue() => handler.clearUpcomingQueue();

  List<SongModel> get upcomingQueue {
    final full = handler.currentActiveQueue;
    final current = handler.currentSong;
    if (current == null || full.isEmpty) return [];
    final idx = full.indexWhere((s) => s.id == current.id);
    if (idx == -1 || idx + 1 >= full.length) return [];
    return full.sublist(idx + 1);
  }
}

final audioControllerProvider = Provider<AudioController>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  final repo = ref.watch(musicRepositoryProvider);
  return AudioController(handler, repo);
});
