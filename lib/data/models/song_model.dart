import 'package:audio_service/audio_service.dart';

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int? albumId;
  final Duration duration;
  final String uri;
  final int? trackNumber;
  final int? size;
  final int? dateAdded;

  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumId,
    required this.duration,
    required this.uri,
    this.trackNumber,
    this.size,
    this.dateAdded,
  });

  /// Convert to sanitized MediaItem for AudioService (Section F)
  MediaItem toMediaItem({Uri? artUri}) {
    // Sanitize values
    final cleanId = id.isEmpty ? 'track_${DateTime.now().millisecondsSinceEpoch}' : id;
    var cleanTitle = title.trim();
    if (cleanTitle.isEmpty) cleanTitle = 'Unknown Track';
    if (cleanTitle.length > 100) cleanTitle = cleanTitle.substring(0, 100);

    var cleanArtist = artist.trim();
    if (cleanArtist.isEmpty || cleanArtist == '<unknown>') cleanArtist = 'Unknown Artist';
    if (cleanArtist.length > 80) cleanArtist = cleanArtist.substring(0, 80);

    var cleanAlbum = album.trim();
    if (cleanAlbum.isEmpty || cleanAlbum == '<unknown>') cleanAlbum = 'Unknown Album';
    if (cleanAlbum.length > 80) cleanAlbum = cleanAlbum.substring(0, 80);

    final safeDuration = duration.inMilliseconds > 0 ? duration : const Duration(seconds: 1);

    return MediaItem(
      id: cleanId,
      title: cleanTitle,
      artist: cleanArtist,
      album: cleanAlbum,
      duration: safeDuration,
      artUri: artUri,
      extras: {
        'uri': uri,
        'albumId': albumId,
        'size': size,
        'trackNumber': trackNumber,
      },
    );
  }

  factory SongModel.fromMediaItem(MediaItem item) {
    return SongModel(
      id: item.id,
      title: item.title,
      artist: item.artist ?? 'Unknown Artist',
      album: item.album ?? 'Unknown Album',
      albumId: item.extras?['albumId'] as int?,
      duration: item.duration ?? Duration.zero,
      uri: (item.extras?['uri'] as String?) ?? '',
      trackNumber: item.extras?['trackNumber'] as int?,
      size: item.extras?['size'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
