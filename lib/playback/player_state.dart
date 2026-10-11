import 'package:audio_service/audio_service.dart';
import '../data/models/models.dart';

/// Audio quality metadata retrieved from native media player or file attributes.
class AudioQualityInfo {
  final String? format;
  final int? bitrate; // in bps
  final int? sampleRate; // in Hz
  final int? channels;
  final String? bitDepth;

  const AudioQualityInfo({
    this.format,
    this.bitrate,
    this.sampleRate,
    this.channels,
    this.bitDepth,
  });

  /// Single-line list of non-null, non-zero chips for display.
  List<String> get chips {
    final list = <String>[];
    if (format != null && format!.isNotEmpty && format != 'null') {
      list.add(format!.toUpperCase());
    }
    if (bitrate != null && bitrate! > 0) {
      final kbps = (bitrate! / 1000).round();
      if (kbps > 0) list.add('$kbps kbps');
    }
    if (sampleRate != null && sampleRate! > 0) {
      final khz = sampleRate! / 1000.0;
      final khzStr =
          khz % 1 == 0 ? khz.toInt().toString() : khz.toStringAsFixed(1);
      list.add('$khzStr kHz');
    }
    if (bitDepth != null && bitDepth!.isNotEmpty && bitDepth != 'null') {
      list.add(bitDepth!);
    }
    if (channels != null && channels! > 0) {
      if (channels == 1) {
        list.add('Mono');
      } else if (channels == 2) {
        list.add('Stereo');
      } else if (channels == 6) {
        list.add('5.1');
      } else {
        list.add('$channels ch');
      }
    }
    return list;
  }
}

/// Immutable state representing current playback status in OffBeat.
class PlayerState {
  final Song? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool shuffleEnabled;
  final AudioServiceRepeatMode repeatMode;
  final List<Song> queue;
  final int currentIndex;

  const PlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffleEnabled = false,
    this.repeatMode = AudioServiceRepeatMode.none,
    this.queue = const [],
    this.currentIndex = -1,
  });

  PlayerState copyWith({
    Song? currentSong,
    bool clearCurrentSong = false,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? shuffleEnabled,
    AudioServiceRepeatMode? repeatMode,
    List<Song>? queue,
    int? currentIndex,
  }) {
    return PlayerState(
      currentSong: clearCurrentSong ? null : (currentSong ?? this.currentSong),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  @override
  String toString() =>
      'PlayerState(currentSong: ${currentSong?.title}, playing: $isPlaying, pos: $position, dur: $duration)';
}
