import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';

void main() {
  testWidgets('renders the entries route directly', (tester) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/entries'));

    await tester.pumpAndSettle();

    expect(find.text('Entries'), findsOneWidget);
  });

  testWidgets('renders the entry-detail route for a non-empty id', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/entry/day-001'));

    await tester.pumpAndSettle();

    expect(find.text('Entry preview'), findsOneWidget);
    expect(find.textContaining('day-001'), findsOneWidget);
  });

  testWidgets('redirects an empty entry id route back to entries', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(initialLocation: '/entry/%20%20'));

    await tester.pumpAndSettle();

    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Entry preview'), findsNothing);
  });

  testWidgets('supports the approved route user flow', (tester) async {
    final router = buildAppRouter();

    await tester.pumpWidget(_buildTestApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('Capture'), findsOneWidget);

    router.go('/entries');
    await tester.pumpAndSettle();
    expect(find.text('Entries'), findsOneWidget);

    router.go('/entry/today');
    await tester.pumpAndSettle();
    expect(find.text('Entry preview'), findsOneWidget);
    expect(find.textContaining('today'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('Capture'), findsOneWidget);
  });
}

Widget _buildTestApp({String initialLocation = '/', GoRouter? router}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      appRouterProvider.overrideWithValue(
        router ?? buildAppRouter(initialLocation: initialLocation),
      ),
    ],
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: WraitApp(),
    ),
  );
}
