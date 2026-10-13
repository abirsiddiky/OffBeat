class Formatters {
  Formatters._();

  /// Format milliseconds or Duration into m:ss or h:mm:ss
  static String formatDuration(Duration? duration) {
    if (duration == null || duration.inMilliseconds <= 0) return '0:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Format track index as two digits e.g. "01", "02"
  static String formatTrackNumber(int index) {
    return index.toString().padLeft(2, '0');
  }

  /// Extract extension/format e.g. "MP3", "FLAC", "M4A", "WAV", "OGG"
  static String formatExtension(String? path) {
    if (path == null || path.isEmpty) return 'AUDIO';
    final ext = path.split('.').last.toUpperCase();
    return ext.length <= 5 ? ext : 'AUDIO';
  }

  /// Build chips list for Now Playing screen
  /// MP3 · 320 kbps · 48 kHz · 16-bit · Stereo
  static List<String> buildAudioSpecs({
    required String? filePath,
    int? bitrate,
    int? sampleRate,
    int? channels,
    String? format,
    int? fileSize,
    Duration? duration,
  }) {
    final List<String> specs = [];

    // Format
    final ext = formatExtension(filePath);
    specs.add(ext);

    // Bitrate
    var effectiveBitrate = bitrate;
    if ((effectiveBitrate == null || effectiveBitrate <= 0) &&
        fileSize != null &&
        fileSize > 0 &&
        duration != null &&
        duration.inSeconds > 0) {
      effectiveBitrate = ((fileSize * 8) ~/ duration.inSeconds);
    }

    if (effectiveBitrate != null && effectiveBitrate > 0) {
      final kbps = (effectiveBitrate / 1000).round();
      if (kbps > 0) {
        specs.add('$kbps kbps');
      }
    }

    // Sample rate
    if (sampleRate != null && sampleRate > 0) {
      final khz = sampleRate / 1000.0;
      specs.add(khz == khz.roundToDouble() ? '${khz.toInt()} kHz' : '${khz.toStringAsFixed(1)} kHz');
    }

    // Bit depth / format
    if (format != null && format.isNotEmpty && format != 'null') {
      if (format.contains('16')) {
        specs.add('16-bit');
      } else if (format.contains('24')) {
        specs.add('24-bit');
      } else if (format.contains('32')) {
        specs.add('32-bit');
      }
    }

    // Channels
    if (channels != null && channels > 0) {
      if (channels == 1) {
        specs.add('Mono');
      } else if (channels == 2) {
        specs.add('Stereo');
      } else {
        specs.add('$channels ch');
      }
    }

    return specs;
  }
}
