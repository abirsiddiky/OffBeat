import 'package:drift/drift.dart';

@DataClassName('RecentlyPlayedEntry')
class RecentlyPlayed extends Table {
  IntColumn get songId => integer()();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {songId};
}
