import 'dart:async';
import 'dart:io' as io;
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../data/models/models.dart';
import '../data/repositories/music_repository.dart';
import '../data/services/artwork_cache_service.dart';
import 'player_state.dart';

/// Flag to completely disable notification artwork for verification.
/// When true, always set artUri = null.
const bool kNoArtworkMode = false;

/// Maps a [Song] domain model to an [audio_service.MediaItem] for OS notifications.
/// Uses a cached local JPEG file:// Uri instead of content:// MediaStore URIs.
/// If no valid normalized artwork exists or kNoArtworkMode is true, artUri is null.
MediaItem songToMediaItem(Song song, [Uri? explicitArtUri]) {
  Uri? artUri;
  if (!kNoArtworkMode) {
    artUri = explicitArtUri ?? ArtworkCacheService.instance.getCachedArtUri(song.id);
  }

  return MediaItem(
    id: song.id.toString(),
    title: song.title,
    artist: song.artist,
    album: song.album,
    duration: song.duration,
    artUri: artUri,
    extras: {
      'filePath': song.filePath,
      'albumId': song.albumId,
      'mimeType': song.mimeType,
      'trackNumber': song.trackNumber,
      'year': song.year,
    },
  );
}

/// Converts an [audio_service.MediaItem] back to a [Song] domain model.
Song mediaItemToSong(MediaItem item) {
  final extras = item.extras ?? {};
  return Song(
    id: int.tryParse(item.id) ?? 0,
    title: item.title,
    artist: item.artist ?? 'Unknown Artist',
    album: item.album ?? 'Unknown Album',
    albumId: extras['albumId'] as int?,
    duration: item.duration ?? Duration.zero,
    filePath: (extras['filePath'] as String?) ?? '',
    mimeType: extras['mimeType'] as String?,
    trackNumber: extras['trackNumber'] as int?,
    year: extras['year'] as int?,
  );
}

/// Primary audio handler wrapping media_kit Player with background audio_service
/// notification integration and audio session focus handling.
class OffBeatAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final MusicRepository repository;
  final int sdkInt;
  late final Player _player;

  AudioSession? _session;
  final List<Song> _songsQueue = [];
  List<Song>? _originalQueue;
  int _currentIndex = -1;
  int? _lastLoggedSongId;

  bool _shuffleEnabled = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  Timer? _smoothPositionTimer;
  final _smoothPositionController = StreamController<Duration>.broadcast();

  final List<StreamSubscription> _subscriptions = [];

  OffBeatAudioHandler({
    required this.repository,
    this.sdkInt = 0,
    Player? player,
    bool initPlayer = true,
  }) {
    if (initPlayer) {
      _player = player ??
          Player(
            configuration: const PlayerConfiguration(
              title: 'OffBeat',
            ),
          );

      // Call initial state immediately so MediaSession is active before the first play()
      _initInitialState();
      _initAudioSession();
      _listenToPlayerStreams();
    }
  }

  /// Expose the underlying media_kit Player if needed
  Player get player => _player;

  /// Current playback queue index
  int get currentIndex => _currentIndex;

  /// Current song being played
  Song? get currentSong {
    if (_currentIndex >= 0 && _currentIndex < _songsQueue.length) {
      return _songsQueue[_currentIndex];
    }
    return null;
  }

  /// Current queue as domain [Song] list
  List<Song> get songsQueue => List.unmodifiable(_songsQueue);

  /// Smooth position updates (~200ms) for responsive UI progress
  Stream<Duration> get smoothPositionStream =>
      _smoothPositionController.stream;

  // ==========================================
  // MediaSession Initialization & State
  // ==========================================

  void _initInitialState() {
    playbackState.add(
      PlaybackState(
        controls: const [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
        queueIndex: -1,
        repeatMode: _repeatMode,
        shuffleMode: _shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
    debugPrint('[OffBeat][SDK: $sdkInt] Initial MediaSession PlaybackState set.');
  }

  // ==========================================
  // Audio Session & Becoming Noisy
  // ==========================================

  Future<void> _initAudioSession() async {
    try {
      _session = await AudioSession.instance;
      await _session?.configure(const AudioSessionConfiguration.music());

      // Handle headphones unplugged (becoming noisy)
      _subscriptions.add(
        _session!.becomingNoisyEventStream.listen((_) {
          pause();
        }),
      );

      // Handle audio focus loss / interruptions (phone calls, navigation)
      _subscriptions.add(
        _session!.interruptionEventStream.listen((event) {
          if (event.begin) {
            switch (event.type) {
              case AudioInterruptionType.duck:
                _player.setVolume(40.0);
                break;
              case AudioInterruptionType.pause:
              case AudioInterruptionType.unknown:
                pause();
                break;
            }
          } else {
            switch (event.type) {
              case AudioInterruptionType.duck:
                _player.setVolume(100.0);
                break;
              case AudioInterruptionType.pause:
                play();
                break;
              case AudioInterruptionType.unknown:
                break;
            }
          }
        }),
      );
    } catch (e) {
      debugPrint('[OffBeat][SDK: $sdkInt] AudioSession initialization error: $e');
    }
  }

  // ==========================================
  // MediaKit Stream Mapping
  // ==========================================

  void _listenToPlayerStreams() {
    // Playing state
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        _broadcastState();
        if (playing) {
          _startSmoothPositionTimer();
        } else {
          _stopSmoothPositionTimer();
        }
      }),
    );

    // Position updates
    _subscriptions.add(
      _player.stream.position.listen((pos) {
        _smoothPositionController.add(pos);
        _broadcastState(position: pos);
      }),
    );

    // Duration updates - only update if duration was previously unknown to avoid
    // re-emitting mediaItem repeatedly in quick succession.
    _subscriptions.add(
      _player.stream.duration.listen((dur) {
        final current = mediaItem.value;
        if (current != null &&
            dur > Duration.zero &&
            (current.duration == null || current.duration == Duration.zero)) {
          mediaItem.add(current.copyWith(duration: dur));
        }
      }),
    );

    // Buffering state
    _subscriptions.add(
      _player.stream.buffering.listen((buffering) {
        _broadcastState(isBuffering: buffering);
      }),
    );

    // Track completion
    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (completed) {
          _onTrackCompleted();
        }
      }),
    );
  }

  void _startSmoothPositionTimer() {
    _smoothPositionTimer?.cancel();
    _smoothPositionTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) {
        final currentPos = _player.state.position;
        _smoothPositionController.add(currentPos);
      },
    );
  }

  void _stopSmoothPositionTimer() {
    _smoothPositionTimer?.cancel();
    _smoothPositionTimer = null;
  }

  void _onTrackCompleted() {
    if (_repeatMode == AudioServiceRepeatMode.one) {
      seek(Duration.zero);
      play();
    } else {
      skipToNext();
    }
  }

  void _logRecentlyPlayed(Song song) {
    if (_lastLoggedSongId != song.id) {
      _lastLoggedSongId = song.id;
      repository.addRecentlyPlayed(song.id);
    }
  }

  void _broadcastState({
    Duration? position,
    bool? isBuffering,
    bool? forcePlaying,
  }) {
    final playing = forcePlaying ?? _player.state.playing;
    final pos = position ?? _player.state.position;
    final buffering = isBuffering ?? _player.state.buffering;

    AudioProcessingState processingState;
    if (buffering) {
      processingState = AudioProcessingState.buffering;
    } else if (_songsQueue.isEmpty) {
      processingState = AudioProcessingState.idle;
    } else {
      processingState = AudioProcessingState.ready;
    }

    final state = PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: pos,
      bufferedPosition: pos,
      speed: 1.0,
      queueIndex: _currentIndex,
      repeatMode: _repeatMode,
      shuffleMode: _shuffleEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );

    playbackState.add(state);
    debugPrint(
      '[OffBeat][SDK: $sdkInt] playbackState: playing=$playing, processing=$processingState, pos=$pos, compact=[0,1,2]',
    );
  }

  // ==========================================
  // Playback Operations & Codec Execution
  // ==========================================

  /// Load a queue of songs and start playback at [startIndex].
  Future<void> loadQueue(
    List<Song> songs, {
    int startIndex = 0,
    bool autoPlay = true,
  }) async {
    if (songs.isEmpty) return;

    _songsQueue.clear();
    _songsQueue.addAll(songs);

    if (_shuffleEnabled) {
      _originalQueue = List<Song>.from(songs);
      final current = songs[startIndex.clamp(0, songs.length - 1)];
      final rest = songs.where((s) => s.id != current.id).toList()..shuffle();
      _songsQueue.clear();
      _songsQueue.add(current);
      _songsQueue.addAll(rest);
      _currentIndex = 0;
    } else {
      _originalQueue = null;
      _currentIndex = startIndex.clamp(0, songs.length - 1);
    }

    final mediaItems = _songsQueue.map((s) => songToMediaItem(s)).toList();
    queue.add(mediaItems);

    await _playCurrentIndex(autoPlay: autoPlay);
  }

  Future<void> _playCurrentIndex({bool autoPlay = true}) async {
    if (_currentIndex < 0 || _currentIndex >= _songsQueue.length) return;

    final song = _songsQueue[_currentIndex];

    // Prepare artwork BEFORE emitting mediaItem:
    // Await normalization with a 1.5s timeout (fallback to artUri = null on timeout or error)
    Uri? artUri;
    if (!kNoArtworkMode) {
      try {
        artUri = await ArtworkCacheService.instance
            .getOrFetchArtworkUri(song.id)
            .timeout(
              const Duration(milliseconds: 1500),
              onTimeout: () => null,
            );
      } catch (e) {
        artUri = null;
      }
    }

    // Guard: Check if the track changed while awaiting artwork normalization
    if (_currentIndex < 0 ||
        _currentIndex >= _songsQueue.length ||
        _songsQueue[_currentIndex].id != song.id) {
      return;
    }

    // 1. mediaItem is prepared and emitted ONCE per track change
    final item = songToMediaItem(song, artUri);
    mediaItem.add(item);
    debugPrint(
      '[OffBeat][SDK: $sdkInt] mediaItem emitted before play: "${item.title}" by ${item.artist} (artUri: ${item.artUri})',
    );

    // 2. playbackState emitted IMMEDIATELY when track starts
    _broadcastState(position: Duration.zero, forcePlaying: autoPlay);

    // 3. Open file through media_kit (supports all audio codecs)
    await _player.open(
      Media(song.filePath),
      play: autoPlay,
    );

    if (autoPlay) {
      await _session?.setActive(true);
      _logRecentlyPlayed(song);
    }
  }

  @override
  Future<void> play() async {
    await _session?.setActive(true);
    await _player.play();
    final song = currentSong;
    if (song != null) {
      _logRecentlyPlayed(song);
    }
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _session?.setActive(false);
    _broadcastState();
    super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState(position: position);
  }

  @override
  Future<void> skipToNext() async {
    if (_songsQueue.isEmpty) return;

    if (_currentIndex < _songsQueue.length - 1) {
      _currentIndex++;
      await _playCurrentIndex();
    } else if (_repeatMode == AudioServiceRepeatMode.all) {
      _currentIndex = 0;
      await _playCurrentIndex();
    } else {
      await pause();
      await seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_songsQueue.isEmpty) return;

    // If more than 3 seconds in, seek to start of track
    if (_player.state.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrentIndex();
    } else {
      await seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _songsQueue.length) {
      _currentIndex = index;
      await _playCurrentIndex();
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleEnabled = shuffleMode == AudioServiceShuffleMode.all;

    if (_shuffleEnabled) {
      _originalQueue = List<Song>.from(_songsQueue);
      if (_currentIndex >= 0 && _currentIndex < _songsQueue.length) {
        final current = _songsQueue[_currentIndex];
        final played = _songsQueue.sublist(0, _currentIndex);
        final upcoming = _songsQueue.sublist(_currentIndex + 1)..shuffle();

        _songsQueue.clear();
        _songsQueue.addAll(played);
        _songsQueue.add(current);
        _currentIndex = played.length;
        _songsQueue.addAll(upcoming);
      } else {
        _songsQueue.shuffle();
      }
    } else {
      if (_originalQueue != null && _originalQueue!.isNotEmpty) {
        final current = currentSong;
        _songsQueue.clear();
        _songsQueue.addAll(_originalQueue!);
        _originalQueue = null;
        if (current != null) {
          final found = _songsQueue.indexWhere((s) => s.id == current.id);
          if (found != -1) {
            _currentIndex = found;
          }
        }
      }
    }

    queue.add(_songsQueue.map((s) => songToMediaItem(s)).toList());
    _broadcastState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    PlaylistMode mode;
    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        mode = PlaylistMode.single;
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        mode = PlaylistMode.loop;
        break;
      case AudioServiceRepeatMode.none:
        mode = PlaylistMode.none;
        break;
    }
    await _player.setPlaylistMode(mode);
    _broadcastState();
  }

  // ==========================================
  // Queue Modification Operations
  // ==========================================

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final song = mediaItemToSong(mediaItem);
    addToQueue(song);
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    final song = mediaItemToSong(mediaItem);
    insertSongAt(index, song);
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _songsQueue.length) return;

    _songsQueue.removeAt(index);
    final updatedMediaItems =
        _songsQueue.map((s) => songToMediaItem(s)).toList();
    queue.add(updatedMediaItems);

    if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_songsQueue.isEmpty) {
        _currentIndex = -1;
        await stop();
      } else {
        _currentIndex = _currentIndex.clamp(0, _songsQueue.length - 1);
        await _playCurrentIndex();
      }
    }
    _broadcastState();
  }

  /// Remove all upcoming songs after current playing song, keeping current track
  void clearUpcoming() {
    if (_currentIndex >= 0 && _currentIndex < _songsQueue.length - 1) {
      _songsQueue.removeRange(_currentIndex + 1, _songsQueue.length);
      queue.add(_songsQueue.map((s) => songToMediaItem(s)).toList());
      _broadcastState();
    }
  }

  /// Convenience method to insert a song into queue
  void insertSongAt(int index, Song song) {
    final insertIdx = index.clamp(0, _songsQueue.length);
    _songsQueue.insert(insertIdx, song);
    queue.add(_songsQueue.map((s) => songToMediaItem(s)).toList());
    if (insertIdx <= _currentIndex) {
      _currentIndex++;
    }
    _broadcastState();
  }

  /// Insert a song to play immediately after the current song
  void playNext(Song song) {
    if (_songsQueue.isEmpty) {
      loadQueue([song]);
    } else {
      insertSongAt(_currentIndex + 1, song);
    }
  }

  /// Add song to the end of the current queue
  void addToQueue(Song song) {
    if (_songsQueue.isEmpty) {
      loadQueue([song]);
    } else {
      _songsQueue.add(song);
      queue.add(_songsQueue.map((s) => songToMediaItem(s)).toList());
      _broadcastState();
    }
  }

  /// Reorder queue items. Does not interrupt playback if reordering upcoming tracks.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _songsQueue.length) return;
    if (newIndex < 0 || newIndex > _songsQueue.length) return;

    final song = _songsQueue.removeAt(oldIndex);
    final targetIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    _songsQueue.insert(targetIndex, song);

    if (_currentIndex == oldIndex) {
      _currentIndex = targetIndex;
    } else if (oldIndex < _currentIndex && targetIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && targetIndex <= _currentIndex) {
      _currentIndex++;
    }

    queue.add(_songsQueue.map((s) => songToMediaItem(s)).toList());
    _broadcastState();
  }

  /// Retrieve audio quality parameters from media_kit native properties or file metadata.
  Future<AudioQualityInfo?> getAudioQualityInfo(Song? song) async {
    if (song == null) return null;

    String? format;
    if (song.filePath.contains('.')) {
      format = song.filePath.split('.').last.toUpperCase();
    } else if (song.mimeType != null && song.mimeType!.isNotEmpty) {
      format = song.mimeType!.split('/').last.toUpperCase();
    }

    int? bitrate;
    int? sampleRate;
    int? channels;
    String? bitDepth;

    try {
      final platform = _player.platform;
      final bitrateStr =
          await (platform as dynamic).getProperty('audio-bitrate');
      if (bitrateStr != null && bitrateStr.toString().isNotEmpty) {
        final b = double.tryParse(bitrateStr.toString());
        if (b != null && b > 0) {
          bitrate = b.round();
        }
      }
    } catch (_) {}

    // Fallback: calculate bitrate from file size and song duration if missing/zero
    if ((bitrate == null || bitrate == 0) &&
        song.duration > Duration.zero &&
        song.filePath.isNotEmpty) {
      try {
        final file = io.File(song.filePath);
        if (file.existsSync()) {
          final sizeInBytes = file.lengthSync();
          final durationSec = song.duration.inSeconds;
          if (durationSec > 0) {
            bitrate = ((sizeInBytes * 8) / durationSec).round();
          }
        }
      } catch (_) {}
    }

    try {
      final platform = _player.platform;
      final srStr =
          await (platform as dynamic).getProperty('audio-params/samplerate');
      if (srStr != null && srStr.toString().isNotEmpty) {
        final sr = int.tryParse(srStr.toString());
        if (sr != null && sr > 0) {
          sampleRate = sr;
        }
      }

      final chStr =
          await (platform as dynamic).getProperty('audio-params/channel-count');
      if (chStr != null && chStr.toString().isNotEmpty) {
        final ch = int.tryParse(chStr.toString());
        if (ch != null && ch > 0) {
          channels = ch;
        }
      }

      final fmtStr =
          await (platform as dynamic).getProperty('audio-params/format');
      if (fmtStr != null && fmtStr.toString().isNotEmpty) {
        final f = fmtStr.toString().toLowerCase();
        if (f.contains('16')) {
          bitDepth = '16-bit';
        } else if (f.contains('24')) {
          bitDepth = '24-bit';
        } else if (f.contains('32')) {
          bitDepth = '32-bit';
        } else if (f.contains('64')) {
          bitDepth = '64-bit';
        } else if (f.contains('flt')) {
          bitDepth = '32-bit float';
        }
      }
    } catch (_) {}

    return AudioQualityInfo(
      format: format,
      bitrate: bitrate,
      sampleRate: sampleRate,
      channels: channels,
      bitDepth: bitDepth,
    );
  }

  Future<void> dispose() async {
    _stopSmoothPositionTimer();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _smoothPositionController.close();
    await _player.dispose();
  }
}
