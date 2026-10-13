class ArtistModel {
  final int id;
  final String name;
  final int trackCount;
  final int? albumCount;

  const ArtistModel({
    required this.id,
    required this.name,
    required this.trackCount,
    this.albumCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtistModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
