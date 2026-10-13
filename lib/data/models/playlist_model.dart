class PlaylistModel {
  final int id;
  final String name;
  final int songCount;
  final DateTime createdAt;

  const PlaylistModel({
    required this.id,
    required this.name,
    required this.songCount,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
