import 'package:on_audio_query_forked/on_audio_query.dart';

/// Representation of an album collection in OffBeat.
class Album {
  final int id;
  final String title;
  final String artist;
  final int? artistId;
  final int numberOfSongs;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    this.artistId,
    required this.numberOfSongs,
  });

  /// Factory constructor to map from [AlbumModel] (on_audio_query)
  factory Album.fromAlbumModel(AlbumModel model) {
    return Album(
      id: model.id,
      title: model.album.trim().isNotEmpty ? model.album.trim() : 'Unknown Album',
      artist: (model.artist != null && model.artist != '<unknown>' && model.artist!.trim().isNotEmpty)
          ? model.artist!.trim()
          : 'Unknown Artist',
      artistId: model.artistId,
      numberOfSongs: model.numOfSongs,
    );
  }

  Album copyWith({
    int? id,
    String? title,
    String? artist,
    int? artistId,
    int? numberOfSongs,
  }) {
    return Album(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artistId: artistId ?? this.artistId,
      numberOfSongs: numberOfSongs ?? this.numberOfSongs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'artistId': artistId,
      'numberOfSongs': numberOfSongs,
    };
  }

  factory Album.fromMap(Map<String, dynamic> map) {
    return Album(
      id: map['id'] as int,
      title: map['title'] as String,
      artist: map['artist'] as String,
      artistId: map['artistId'] as int?,
      numberOfSongs: (map['numberOfSongs'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Album && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Album(id: $id, title: "$title", artist: "$artist", songs: $numberOfSongs)';
}
