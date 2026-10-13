class AlbumModel {
  final int id;
  final String title;
  final String artist;
  final int songCount;
  final int? year;
  final String? firstSongId;

  const AlbumModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.songCount,
    this.year,
    this.firstSongId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlbumModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
