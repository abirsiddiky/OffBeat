// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recently_played_dao.dart';

// ignore_for_file: type=lint
mixin _$RecentlyPlayedDaoMixin on DatabaseAccessor<OffBeatDatabase> {
  $RecentlyPlayedTable get recentlyPlayed => attachedDatabase.recentlyPlayed;
  RecentlyPlayedDaoManager get managers => RecentlyPlayedDaoManager(this);
}

class RecentlyPlayedDaoManager {
  final _$RecentlyPlayedDaoMixin _db;
  RecentlyPlayedDaoManager(this._db);
  $$RecentlyPlayedTableTableManager get recentlyPlayed =>
      $$RecentlyPlayedTableTableManager(
        _db.attachedDatabase,
        _db.recentlyPlayed,
      );
}
