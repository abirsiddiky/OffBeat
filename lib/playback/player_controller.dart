import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import '../data/providers/music_providers.dart';
import 'audio_handler.dart';
import 'player_state.dart';

/// Provider for the singleton OffBeatAudioHandler.
/// Overridden in ProviderScope in main.dart once AudioService.init() completes.
final audioHandlerProvider = Provider<OffBeatAudioHandler>((ref) {
  final repo = ref.watch(musicRepositoryProvider);
  return OffBeatAudioHandler(repository: repo);
});

/// Riverpod Notifier managing playback state and providing high-level playback actions.
class PlayerController extends Notifier<PlayerState> {
  final List<StreamSubscription> _subscriptions = [];

  @override
  PlayerState build() {
    final handler = ref.watch(audioHandlerProvider);

    _subscriptions.clear();

    // Listen to mediaItem changes (current track & duration)
    _subscriptions.add(
      handler.mediaItem.listen((item) {
        if (item != null) {
          final song = handler.currentSong ?? mediaItemToSong(item);
          state = state.copyWith(
            currentSong: song,
            duration: item.duration ?? state.duration,
          );
        } else {
          state = state.copyWith(clearCurrentSong: true);
        }
      }),
    );

    // Listen to playbackState changes (playing, shuffle, repeat, queue index)
    _subscriptions.add(
      handler.playbackState.listen((ps) {
        state = state.copyWith(
          isPlaying: ps.playing,
          position: ps.position,
          shuffleEnabled: ps.shuffleMode == AudioServiceShuffleMode.all,
          repeatMode: ps.repeatMode,
          currentIndex: ps.queueIndex ?? state.currentIndex,
        );
      }),
    );

    // Listen to queue changes
    _subscriptions.add(
      handler.queue.listen((mediaItems) {
        final songs = handler.songsQueue;
        state = state.copyWith(
          queue: songs.isNotEmpty
              ? songs
              : mediaItems.map(mediaItemToSong).toList(),
        );
      }),
    );

    // Listen to smooth 200ms position updates
    _subscriptions.add(
      handler.smoothPositionStream.listen((pos) {
        state = state.copyWith(position: pos);
      }),
    );

    ref.onDispose(() {
      for (final sub in _subscriptions) {
        sub.cancel();
      }
    });

    return PlayerState(
      currentSong: handler.currentSong,
      queue: handler.songsQueue,
      isPlaying: handler.playbackState.value.playing,
      position: handler.playbackState.value.position,
      duration: handler.mediaItem.value?.duration ?? Duration.zero,
      shuffleEnabled: handler.playbackState.value.shuffleMode == AudioServiceShuffleMode.all,
      repeatMode: handler.playbackState.value.repeatMode,
    );
  }

  OffBeatAudioHandler get _handler => ref.read(audioHandlerProvider);

  /// Load and play a list of songs starting at [startIndex].
  Future<void> playSongs(List<Song> songs, [int startIndex = 0]) async {
    await _handler.loadQueue(songs, startIndex: startIndex, autoPlay: true);
  }

  /// Toggle between play and pause.
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  /// Skip to next track.
  Future<void> next() async {
    await _handler.skipToNext();
  }

  /// Skip to previous track or start of current track.
  Future<void> previous() async {
    await _handler.skipToPrevious();
  }

  /// Seek to target [position].
  Future<void> seekTo(Duration position) async {
    await _handler.seek(position);
  }

  /// Toggle shuffle mode.
  Future<void> toggleShuffle() async {
    final nextMode = state.shuffleEnabled
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all;
    await _handler.setShuffleMode(nextMode);
  }

  /// Cycle repeat mode through: none -> all -> one -> none.
  Future<void> cycleRepeatMode() async {
    AudioServiceRepeatMode nextMode;
    switch (state.repeatMode) {
      case AudioServiceRepeatMode.none:
        nextMode = AudioServiceRepeatMode.all;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        nextMode = AudioServiceRepeatMode.one;
        break;
      case AudioServiceRepeatMode.one:
        nextMode = AudioServiceRepeatMode.none;
        break;
    }
    await _handler.setRepeatMode(nextMode);
  }

  /// Insert song to play next.
  void playNext(Song song) {
    _handler.playNext(song);
  }

  /// Add song to the end of the queue.
  void addToQueue(Song song) {
    _handler.addToQueue(song);
  }

  /// Skip directly to index in the queue.
  Future<void> skipToQueueIndex(int index) async {
    await _handler.skipToQueueItem(index);
  }

  /// Remove item from queue at [index].
  Future<void> removeFromQueue(int index) async {
    await _handler.removeQueueItemAt(index);
  }

  /// Remove all upcoming songs in queue after current song
  void clearUpcoming() {
    _handler.clearUpcoming();
  }

  /// Insert song at index in queue
  void insertSongAt(int index, Song song) {
    _handler.insertSongAt(index, song);
  }

  /// Reorder queue items.
  void reorderQueue(int oldIndex, int newIndex) {
    _handler.reorderQueue(oldIndex, newIndex);
  }
}

/// Primary controller provider.
final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(
  PlayerController.new,
);

// ==========================================
// Selective Providers for Granular Rebuilding
// ==========================================

/// Current playing song
final currentSongProvider = Provider<Song?>((ref) {
  return ref.watch(playerControllerProvider.select((s) => s.currentSong));
});

/// Current queue index
final currentIndexProvider = Provider<int>((ref) {
  return ref.watch(playerControllerProvider.select((s) => s.currentIndex));
});

/// Play / pause boolean status
final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(playerControllerProvider.select((s) => s.isPlaying));
});

/// Smooth playback position (~200ms updates)
final playbackPositionProvider = Provider<Duration>((ref) {
  return ref.watch(playerControllerProvider.select((s) => s.position));
});

/// Total track duration
final playbackDurationProvider = Provider<Duration>((ref) {
  return ref.watch(playerControllerProvider.select((s) => s.duration));
});

/// Shuffle mode enabled boolean
final shuffleEnabledProvider = Provider<bool>((ref) {
  return ref.watch(playerControllerProvider.select((s) => s.shuffleEnabled));
});

/// Repeat mode (none, one, all)
final repeatModeProvider = Provider<AudioServiceRepeatMode>((ref) {
  return ref.watch(playerControllerProvider.select((s) => s.repeatMode));
});

/// Current playback queue
final queueProvider = Provider<List<Song>>((ref) {
  return ref.watch(playerControllerProvider.select((s) => s.queue));
});

/// Audio quality metadata (format, bitrate, sample rate, channels, bit depth)
final audioQualityProvider =
    FutureProvider.autoDispose<AudioQualityInfo?>((ref) async {
  final currentSong = ref.watch(currentSongProvider);
  if (currentSong == null) return null;
  final handler = ref.watch(audioHandlerProvider);
  // Give media_kit/libmpv a brief moment to initialize track properties
  await Future.delayed(const Duration(milliseconds: 350));
  return handler.getAudioQualityInfo(currentSong);
});

