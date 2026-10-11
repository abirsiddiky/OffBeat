import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offbeat/data/data.dart';
import 'package:offbeat/main.dart';
import 'package:offbeat/playback/playback.dart';

class FakeAudioHandler extends OffBeatAudioHandler {
  FakeAudioHandler({required super.repository}) : super(initPlayer: false);
}

void main() {
  testWidgets('OffBeat app smoke test', (WidgetTester tester) async {
    final db = OffBeatDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());

    final fakeHandler = FakeAudioHandler(
      repository: MusicRepository(
        scanner: MusicScanner(),
        db: db,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(fakeHandler),
          databaseProvider.overrideWithValue(db),
          musicPermissionProvider.overrideWith(() => _FakePermissionNotifier()),
        ],
        child: const OffBeatApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('OffBeat'), findsWidgets);

    // Unmount and pump out teardown timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}

class _FakePermissionNotifier extends MusicPermissionNotifier {
  @override
  Future<bool> build() async => true;
}
