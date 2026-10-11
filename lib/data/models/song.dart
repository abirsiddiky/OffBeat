import 'package:on_audio_query_forked/on_audio_query.dart';

/// Representation of a local audio track in OffBeat.
class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final int? albumId;
  final Duration duration;
  final String filePath;
  final String? mimeType;
  final int? trackNumber;
  final int? year;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumId,
    required this.duration,
    required this.filePath,
    this.mimeType,
    this.trackNumber,
    this.year,
  });

  /// Duration in milliseconds for convenient playback integration
  int get durationMs => duration.inMilliseconds;

  /// File extension derived from mimeType or filePath
  String get fileExtension {
    if (mimeType != null && mimeType!.isNotEmpty) {
      return mimeType!.split('/').last;
    }
    final dotIndex = filePath.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < filePath.length - 1) {
      return filePath.substring(dotIndex + 1);
    }
    return '';
  }

  /// Factory constructor to map from [SongModel] (on_audio_query)
  factory Song.fromSongModel(SongModel model) {
    return Song(
      id: model.id,
      title: model.title.trim().isNotEmpty ? model.title.trim() : model.displayNameWOExt,
      artist: (model.artist != null && model.artist != '<unknown>' && model.artist!.trim().isNotEmpty)
          ? model.artist!.trim()
          : 'Unknown Artist',
      album: (model.album != null && model.album != '<unknown>' && model.album!.trim().isNotEmpty)
          ? model.album!.trim()
          : 'Unknown Album',
      albumId: model.albumId,
      duration: Duration(milliseconds: model.duration ?? 0),
      filePath: model.data,
      mimeType: model.fileExtension.isNotEmpty ? 'audio/${model.fileExtension}' : null,
      trackNumber: model.track,
      year: null, // Populated from ID3 tags or album metadata where available
    );
  }

  Song copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    int? albumId,
    Duration? duration,
    String? filePath,
    String? mimeType,
    int? trackNumber,
    int? year,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      mimeType: mimeType ?? this.mimeType,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumId': albumId,
      'durationMs': duration.inMilliseconds,
      'filePath': filePath,
      'mimeType': mimeType,
      'trackNumber': trackNumber,
      'year': year,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] as int,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      albumId: map['albumId'] as int?,
      duration: Duration(milliseconds: (map['durationMs'] as num?)?.toInt() ?? 0),
      filePath: map['filePath'] as String,
      mimeType: map['mimeType'] as String?,
      trackNumber: map['trackNumber'] as int?,
      year: map['year'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Song(id: $id, title: "$title", artist: "$artist", album: "$album")';
}
