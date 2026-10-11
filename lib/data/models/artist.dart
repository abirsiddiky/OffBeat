import 'package:on_audio_query_forked/on_audio_query.dart';

/// Representation of an artist in OffBeat.
class Artist {
  final int id;
  final String name;
  final int? numberOfAlbums;
  final int? numberOfTracks;

  const Artist({
    required this.id,
    required this.name,
    this.numberOfAlbums,
    this.numberOfTracks,
  });

  /// Factory constructor to map from [ArtistModel] (on_audio_query)
  factory Artist.fromArtistModel(ArtistModel model) {
    return Artist(
      id: model.id,
      name: (model.artist != '<unknown>' && model.artist.trim().isNotEmpty)
          ? model.artist.trim()
          : 'Unknown Artist',
      numberOfAlbums: model.numberOfAlbums,
      numberOfTracks: model.numberOfTracks,
    );
  }

  Artist copyWith({
    int? id,
    String? name,
    int? numberOfAlbums,
    int? numberOfTracks,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      numberOfAlbums: numberOfAlbums ?? this.numberOfAlbums,
      numberOfTracks: numberOfTracks ?? this.numberOfTracks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'numberOfAlbums': numberOfAlbums,
      'numberOfTracks': numberOfTracks,
    };
  }

  factory Artist.fromMap(Map<String, dynamic> map) {
    return Artist(
      id: map['id'] as int,
      name: map['name'] as String,
      numberOfAlbums: map['numberOfAlbums'] as int?,
      numberOfTracks: map['numberOfTracks'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Artist && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Artist(id: $id, name: "$name", albums: $numberOfAlbums, tracks: $numberOfTracks)';
}
