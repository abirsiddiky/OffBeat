import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:offbeat/core/permission_service.dart';
import 'package:offbeat/features/permission/permission_screen.dart';

void main() {
  group('PermissionFlow and GoRouter redirect tests', () {
    testWidgets('Router redirect sends ungranted users to /permission', (tester) async {
      final container = ProviderContainer(
        overrides: [
          permissionProvider.overrideWith(() => _MockPermissionNotifier(PermissionStatus.denied)),
        ],
      );

      final router = container.read(testRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Permission Screen'), findsOneWidget);
      expect(find.text('Home Screen'), findsNothing);
      container.dispose();
    });

    testWidgets('Router redirect keeps granted users on / (Home)', (tester) async {
      final container = ProviderContainer(
        overrides: [
          permissionProvider.overrideWith(() => _MockPermissionNotifier(PermissionStatus.granted)),
        ],
      );

      final router = container.read(testRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('Permission Screen'), findsNothing);
      container.dispose();
    });

    testWidgets('Router redirect automatically moves from /permission to / when granted', (tester) async {
      final notifier = _MockPermissionNotifier(PermissionStatus.denied);
      final container = ProviderContainer(
        overrides: [
          permissionProvider.overrideWith(() => notifier),
        ],
      );

      final router = container.read(testRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Permission Screen'), findsOneWidget);

      // Grant permission
      notifier.setStatus(PermissionStatus.granted);
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('Permission Screen'), findsNothing);
      container.dispose();
    });

    testWidgets('Router redirect automatically sends back to /permission when revoked in background', (tester) async {
      final notifier = _MockPermissionNotifier(PermissionStatus.granted);
      final container = ProviderContainer(
        overrides: [
          permissionProvider.overrideWith(() => notifier),
        ],
      );

      final router = container.read(testRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);

      // Revoke permission (e.g. from app settings)
      notifier.setStatus(PermissionStatus.denied);
      await tester.pumpAndSettle();

      expect(find.text('Permission Screen'), findsOneWidget);
      expect(find.text('Home Screen'), findsNothing);
      container.dispose();
    });

    testWidgets('PermissionScreen UI is driven by permissionProvider', (tester) async {
      final notifier = _MockPermissionNotifier(PermissionStatus.denied);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            permissionProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: PermissionScreen(),
          ),
        ),
      );

      expect(find.text('Access Your Music'), findsOneWidget);
      expect(find.text('Grant Storage Access'), findsOneWidget);

      // Transition to permanently denied
      notifier.setStatus(PermissionStatus.permanentlyDenied);
      await tester.pump();

      expect(find.text('Open Settings'), findsOneWidget);
      expect(
        find.text('Storage permission is permanently denied. Tap "Open Settings" to enable it.'),
        findsOneWidget,
      );
    });
  });
}

class _MockPermissionNotifier extends PermissionNotifier {
  PermissionStatus _mockStatus;
  _MockPermissionNotifier(this._mockStatus);

  @override
  PermissionStatus build() {
    ref.keepAlive();
    return _mockStatus;
  }

  void setStatus(PermissionStatus status) {
    _mockStatus = status;
    state = status;
  }

  @override
  Future<PermissionStatus> refresh() async {
    state = _mockStatus;
    return _mockStatus;
  }

  @override
  Future<PermissionStatus> request() async {
    state = _mockStatus;
    return _mockStatus;
  }
}

final testRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _TestRefreshNotifier(ref);
  ref.onDispose(() => notifier.dispose());

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final status = ref.read(permissionProvider);
      final isGranted = status.isGranted || status.isLimited;
      final location = state.matchedLocation;

      String? target;
      if (!isGranted) {
        if (location != '/permission') {
          target = '/permission';
        }
      } else {
        if (location == '/permission') {
          target = '/';
        }
      }

      debugPrint('[Test GoRouter redirect] location: $location -> target: $target');
      return target;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home Screen')),
      ),
      GoRoute(
        path: '/permission',
        builder: (context, state) => const Scaffold(body: Text('Permission Screen')),
      ),
    ],
  );
});

class _TestRefreshNotifier extends ChangeNotifier {
  _TestRefreshNotifier(Ref ref) {
    ref.listen<PermissionStatus>(permissionProvider, (_, __) {
      notifyListeners();
    });
  }
}
