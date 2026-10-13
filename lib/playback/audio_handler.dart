import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import '../core/permission_service.dart';
import '../data/artwork/artwork_service.dart';
import '../data/models/song_model.dart';

class OffBeatAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final Player player = Player();

  // Internal queue
  List<SongModel> _rawQueue = [];
  List<SongModel> _shuffledQueue = [];
  int _currentIndex = -1;

  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;

  Timer? _debounceTimer;
  Function(String songId)? onTrackChanged;

  OffBeatAudioHandler() {
    _initMediaKitAndSession();
  }

  Future<void> _initMediaKitAndSession() async {
    // Listen to media_kit events
    player.stream.playing.listen((isPlaying) {
      _broadcastPlaybackState();
    });

    player.stream.buffering.listen((isBuffering) {
      _broadcastPlaybackState();
    });

    player.stream.completed.listen((isCompleted) {
      if (isCompleted) {
        _onTrackCompleted();
      }
    });

    // Audio session configuration
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.becomingNoisyEventStream.listen((_) {
        pause();
      });

      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              player.setVolume(40.0);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              player.setVolume(100.0);
              break;
            case AudioInterruptionType.pause:
              play();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('[AudioHandler] Failed to configure audio_session: $e');
    }

    _broadcastPlaybackState();
  }

  List<SongModel> get currentActiveQueue =>
      _shuffleMode == AudioServiceShuffleMode.all ? _shuffledQueue : _rawQueue;

  SongModel? get currentSong {
    final q = currentActiveQueue;
    if (_currentIndex >= 0 && _currentIndex < q.length) {
      return q[_currentIndex];
    }
    return null;
  }

  // Real PlaybackState emitter (Section F: Do NOT emit on every position tick)
  void _broadcastPlaybackState() {
    final isPlaying = player.state.playing;
    final isBuffering = player.state.buffering;
    final isCompleted = player.state.completed;

    AudioProcessingState processingState;
    if (currentSong == null) {
      processingState = AudioProcessingState.idle;
    } else if (isBuffering) {
      processingState = AudioProcessingState.buffering;
    } else if (isCompleted) {
      processingState = AudioProcessingState.completed;
    } else {
      processingState = AudioProcessingState.ready;
    }

    final state = PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.setRepeatMode,
        MediaAction.setShuffleMode,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: isPlaying,
      updatePosition: player.state.position,
      bufferedPosition: player.state.buffer,
      speed: 1.0,
      repeatMode: _repeatMode,
      shuffleMode: _shuffleMode,
      updateTime: DateTime.now(),
    );

    debugPrint(
      '[AudioService API ${PermissionService.sdkInt}] Emitting PlaybackState: playing=$isPlaying, state=$processingState',
    );
    playbackState.add(state);
  }

  Future<void> setQueueAndPlay(List<SongModel> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;
    _rawQueue = List.from(songs);

    if (_shuffleMode == AudioServiceShuffleMode.all) {
      _buildShuffledQueue(retainingSong: songs[initialIndex.clamp(0, songs.length - 1)]);
      _currentIndex = 0;
    } else {
      _currentIndex = initialIndex.clamp(0, songs.length - 1);
    }

    _syncAudioServiceQueue();
    _debouncedLoadAndPlayCurrent();
  }

  Future<void> playSingle(SongModel song) async {
    final idx = _rawQueue.indexWhere((s) => s.id == song.id);
    if (idx != -1) {
      _currentIndex = idx;
      _debouncedLoadAndPlayCurrent();
    } else {
      await setQueueAndPlay([song], initialIndex: 0);
    }
  }

  void _syncAudioServiceQueue() {
    final q = currentActiveQueue;
    queue.add(q.map((s) => s.toMediaItem()).toList());
  }

  void _debouncedLoadAndPlayCurrent() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadAndPlayCurrent();
    });
  }

  // Track change execution (Section F strict order)
  Future<void> _loadAndPlayCurrent() async {
    final song = currentSong;
    if (song == null) return;

    // (1) Prepare notification artwork with 1.5s timeout (null on timeout)
    Uri? notifArtUri;
    try {
      notifArtUri = await ArtworkService.getNotificationArtworkUri(
        songId: song.id,
        filePath: song.uri,
        albumId: song.albumId,
      );
    } catch (e) {
      debugPrint('[AudioHandler] Artwork prep error: $e');
    }

    // (2) Emit mediaItem exactly ONCE per track
    final item = song.toMediaItem(artUri: notifArtUri);
    debugPrint(
      '[AudioService API ${PermissionService.sdkInt}] Emitting MediaItem: "${item.title}" artUri=$notifArtUri',
    );
    mediaItem.add(item);

    // Notify repository to log recently played
    onTrackChanged?.call(song.id);

    // (3) Open / Play in media_kit
    try {
      if (song.uri.startsWith('asset://')) {
        // Mock / Asset song
        await player.open(Media(song.uri), play: true);
      } else {
        final file = File(song.uri);
        if (await file.exists()) {
          await player.open(Media(file.path), play: true);
        } else {
          // File might not exist directly on storage or uri is content URI
          await player.open(Media(song.uri), play: true);
        }
      }
    } catch (e) {
      debugPrint('[AudioHandler] media_kit player open error: $e');
    }

    // (4) Emit playbackState immediately
    _broadcastPlaybackState();
  }

  void _onTrackCompleted() {
    if (_repeatMode == AudioServiceRepeatMode.one) {
      seek(Duration.zero);
      play();
    } else {
      skipToNext();
    }
  }

  @override
  Future<void> play() async {
    await player.play();
    _broadcastPlaybackState();
  }

  @override
  Future<void> pause() async {
    await player.pause();
    _broadcastPlaybackState();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    _currentIndex = -1;
    mediaItem.add(null);
    _broadcastPlaybackState();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
    _broadcastPlaybackState();
  }

  @override
  Future<void> skipToNext() async {
    final q = currentActiveQueue;
    if (q.isEmpty) return;

    if (_currentIndex + 1 < q.length) {
      _currentIndex++;
      _debouncedLoadAndPlayCurrent();
    } else if (_repeatMode == AudioServiceRepeatMode.all) {
      _currentIndex = 0;
      _debouncedLoadAndPlayCurrent();
    } else {
      await player.stop();
      _broadcastPlaybackState();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final q = currentActiveQueue;
    if (q.isEmpty) return;

    // If more than 3 seconds into the song, restart song
    if (player.state.position.inSeconds > 3) {
      seek(Duration.zero);
      return;
    }

    if (_currentIndex - 1 >= 0) {
      _currentIndex--;
      _debouncedLoadAndPlayCurrent();
    } else if (_repeatMode == AudioServiceRepeatMode.all) {
      _currentIndex = q.length - 1;
      _debouncedLoadAndPlayCurrent();
    } else {
      seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final q = currentActiveQueue;
    if (index >= 0 && index < q.length) {
      _currentIndex = index;
      _debouncedLoadAndPlayCurrent();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    _broadcastPlaybackState();
  }

  void toggleRepeatMode() {
    final nextMode = switch (_repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
      _ => AudioServiceRepeatMode.none,
    };
    setRepeatMode(nextMode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleMode = shuffleMode;
    final current = currentSong;
    if (_shuffleMode == AudioServiceShuffleMode.all) {
      _buildShuffledQueue(retainingSong: current);
      _currentIndex = 0;
    } else {
      if (current != null) {
        final originalIdx = _rawQueue.indexWhere((s) => s.id == current.id);
        _currentIndex = originalIdx >= 0 ? originalIdx : 0;
      }
    }
    _syncAudioServiceQueue();
    _broadcastPlaybackState();
  }

  void toggleShuffleMode() {
    final nextMode = _shuffleMode == AudioServiceShuffleMode.all
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all;
    setShuffleMode(nextMode);
  }

  void _buildShuffledQueue({SongModel? retainingSong}) {
    final pool = List<SongModel>.from(_rawQueue);
    if (retainingSong != null) {
      pool.removeWhere((s) => s.id == retainingSong.id);
      pool.shuffle(Random());
      _shuffledQueue = [retainingSong, ...pool];
    } else {
      pool.shuffle(Random());
      _shuffledQueue = pool;
    }
  }

  // Queue Operations
  void playNextInQueue(SongModel song) {
    if (currentActiveQueue.isEmpty) {
      setQueueAndPlay([song]);
      return;
    }
    final targetIndex = (_currentIndex + 1).clamp(0, currentActiveQueue.length);
    if (_shuffleMode == AudioServiceShuffleMode.all) {
      _shuffledQueue.insert(targetIndex, song);
      _rawQueue.add(song);
    } else {
      _rawQueue.insert(targetIndex, song);
    }
    _syncAudioServiceQueue();
  }

  void addToQueueEnd(SongModel song) {
    if (currentActiveQueue.isEmpty) {
      setQueueAndPlay([song]);
      return;
    }
    if (_shuffleMode == AudioServiceShuffleMode.all) {
      _shuffledQueue.add(song);
      _rawQueue.add(song);
    } else {
      _rawQueue.add(song);
    }
    _syncAudioServiceQueue();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    final q = _shuffleMode == AudioServiceShuffleMode.all ? _shuffledQueue : _rawQueue;
    if (index < 0 || index >= q.length) return;

    final isRemovingCurrent = (index == _currentIndex);
    q.removeAt(index);

    if (isRemovingCurrent) {
      if (_currentIndex < q.length) {
        _debouncedLoadAndPlayCurrent();
      } else if (q.isNotEmpty) {
        _currentIndex = 0;
        _debouncedLoadAndPlayCurrent();
      } else {
        stop();
      }
    } else if (index < _currentIndex) {
      _currentIndex--;
    }

    _syncAudioServiceQueue();
  }

  void reorderQueueItem(int oldIndex, int newIndex) {
    final q = _shuffleMode == AudioServiceShuffleMode.all ? _shuffledQueue : _rawQueue;
    if (oldIndex < 0 || oldIndex >= q.length || newIndex < 0 || newIndex > q.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = q.removeAt(oldIndex);
    q.insert(newIndex, item);

    // Update currentIndex to follow currently playing song
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    _syncAudioServiceQueue();
  }

  void clearUpcomingQueue() {
    final current = currentSong;
    if (current == null) {
      _rawQueue.clear();
      _shuffledQueue.clear();
      _currentIndex = -1;
    } else {
      _rawQueue = [current];
      _shuffledQueue = [current];
      _currentIndex = 0;
    }
    _syncAudioServiceQueue();
  }

  /// Handles song deletion from device.
  ///
  /// If [songId] is currently playing, advances to the next song first (or stops playback
  /// and hides mini player if it was the only/last song). Removes [songId] from every occurrence
  /// in the queue without interrupting other playback.
  Future<void> handleSongDeleted(String songId) async {
    final wasCurrent = currentSong?.id == songId;
    final activeQ = currentActiveQueue;

    final remaining = activeQ.where((s) => s.id != songId).toList();

    if (wasCurrent) {
      if (remaining.isEmpty) {
        // Only / last song in queue: stop playback and hide mini player
        _rawQueue.clear();
        _shuffledQueue.clear();
        _currentIndex = -1;
        _syncAudioServiceQueue();
        await stop();
        return;
      }

      // Next song candidate (look ahead from current index, wrap around if needed)
      int nextIndex = -1;
      for (var i = _currentIndex + 1; i < activeQ.length; i++) {
        if (activeQ[i].id != songId) {
          nextIndex = i;
          break;
        }
      }
      if (nextIndex == -1) {
        for (var i = 0; i < _currentIndex; i++) {
          if (activeQ[i].id != songId) {
            nextIndex = i;
            break;
          }
        }
      }

      final nextSong = (nextIndex != -1) ? activeQ[nextIndex] : remaining.first;

      _rawQueue.removeWhere((s) => s.id == songId);
      _shuffledQueue.removeWhere((s) => s.id == songId);

      final newActive = currentActiveQueue;
      _currentIndex = newActive.indexWhere((s) => s.id == nextSong.id);
      if (_currentIndex == -1) _currentIndex = 0;

      _syncAudioServiceQueue();
      await _loadAndPlayCurrent();
    } else {
      // Non-playing song: remove every occurrence without interrupting playback
      final currentId = currentSong?.id;
      _rawQueue.removeWhere((s) => s.id == songId);
      _shuffledQueue.removeWhere((s) => s.id == songId);

      if (currentId != null) {
        final newIdx = currentActiveQueue.indexWhere((s) => s.id == currentId);
        _currentIndex = newIdx != -1 ? newIdx : 0;
      }
      _syncAudioServiceQueue();
    }
  }
}
