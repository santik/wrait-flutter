import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/auth/app_lock_authenticator.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/auth/device_security_settings_opener.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/app_lock/app_lock_test_keys.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main cold launch is usable without authentication', (
    tester,
  ) async {
    final harness = await _buildHarness(authResults: const []);

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
    expect(find.byKey(appLockOverlayKey), findsNothing);
    expect(harness.authenticator.authenticateCallCount, 0);
  });

  testWidgets('main remains usable after a foreground cycle without auth', (
    tester,
  ) async {
    final harness = await _buildHarness(authResults: const []);

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
    expect(find.byKey(appLockOverlayKey), findsNothing);
    expect(harness.authenticator.authenticateCallCount, 0);
  });

  testWidgets('entries stay locked until auth succeeds and share one visit', (
    tester,
  ) async {
    final harness = await _buildHarness(
      initialLocation: '/entries',
      authResults: <AppLockAuthResult>[
        AppLockAuthResult.canceled,
        AppLockAuthResult.success,
      ],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(harness.authenticator.authenticateCallCount, 1);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);
    expect(find.byKey(appLockBlurKey), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('entryCard-1')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsNothing);
    expect(harness.authenticator.authenticateCallCount, 1);

    await tester.tap(find.byKey(appLockUnlockButtonKey));
    await tester.pumpAndSettle();

    expect(harness.authenticator.authenticateCallCount, 2);
    expect(find.byKey(appLockOverlayKey), findsNothing);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryCard-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.text('synthetic entry text'), findsOneWidget);
    expect(harness.authenticator.authenticateCallCount, 2);
  });

  testWidgets('a direct valid detail route starts locked', (tester) async {
    final harness = await _buildHarness(
      initialLocation: '/entry/1',
      authResults: <AppLockAuthResult>[
        AppLockAuthResult.canceled,
        AppLockAuthResult.success,
      ],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(harness.authenticator.authenticateCallCount, 1);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);
    expect(find.byKey(appLockBlurKey), findsOneWidget);

    await tester.tap(find.byKey(appLockUnlockButtonKey));
    await tester.pumpAndSettle();

    expect(harness.authenticator.authenticateCallCount, 2);
    expect(find.byKey(appLockOverlayKey), findsNothing);
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.text('synthetic entry text'), findsOneWidget);
  });

  testWidgets('an invalid direct detail route redirects to protected entries', (
    tester,
  ) async {
    final harness = await _buildHarness(
      initialLocation: '/entry/not-a-number',
      authResults: <AppLockAuthResult>[AppLockAuthResult.canceled],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(harness.authenticator.authenticateCallCount, 1);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsNothing);
  });

  testWidgets('returning from main starts a new protected entries visit', (
    tester,
  ) async {
    final harness = await _buildHarness(
      authResults: <AppLockAuthResult>[
        AppLockAuthResult.success,
        AppLockAuthResult.canceled,
      ],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    harness.router.go('/entries');
    await tester.pumpAndSettle();
    expect(harness.authenticator.authenticateCallCount, 1);
    expect(find.byKey(appLockOverlayKey), findsNothing);

    harness.router.go('/');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);

    harness.router.go('/entries');
    await tester.pumpAndSettle();

    expect(harness.authenticator.authenticateCallCount, 2);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);
    expect(find.text('still locked'), findsOneWidget);
  });

  testWidgets('foreground exit relocks entries but not main', (tester) async {
    final harness = await _buildHarness(
      authResults: <AppLockAuthResult>[
        AppLockAuthResult.success,
        AppLockAuthResult.canceled,
      ],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    harness.router.go('/entries');
    await tester.pumpAndSettle();
    expect(harness.authenticator.authenticateCallCount, 1);
    expect(find.byKey(appLockOverlayKey), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(harness.authenticator.authenticateCallCount, 2);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);

    harness.router.go('/');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
    expect(find.byKey(appLockOverlayKey), findsNothing);
  });

  testWidgets(
    'inactive lifecycle churn during an entry auth prompt does not restart it',
    (tester) async {
      final completer = Completer<AppLockAuthResult>();
      final harness = await _buildHarness(
        initialLocation: '/entries',
        authResults: const [],
        authenticateCompleter: completer,
      );

      await tester.pumpWidget(harness.app);
      await tester.pump();

      expect(harness.authenticator.authenticateCallCount, 1);
      expect(find.byKey(appLockOverlayKey), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(harness.authenticator.authenticateCallCount, 1);
      expect(find.byKey(appLockOverlayKey), findsOneWidget);

      completer.complete(AppLockAuthResult.success);
      await tester.pumpAndSettle();

      expect(find.byKey(appLockOverlayKey), findsNothing);
      expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    },
  );

  testWidgets('no-security recovery remains limited to entries', (
    tester,
  ) async {
    final harness = await _buildHarness(
      initialLocation: '/entries',
      authResults: <AppLockAuthResult>[AppLockAuthResult.noSecurityConfigured],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(
      find.text('set up device security to protect Wrait'),
      findsOneWidget,
    );
    expect(find.byKey(appLockSettingsButtonKey), findsOneWidget);
    expect(find.byKey(appLockBypassButtonKey), findsOneWidget);

    await tester.tap(find.byKey(appLockSettingsButtonKey));
    await tester.pump();
    expect(harness.settingsOpener.openCallCount, 1);

    await tester.tap(find.byKey(appLockBypassButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(appLockOverlayKey), findsNothing);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });

  testWidgets('temporary unavailability keeps entries locked until retry', (
    tester,
  ) async {
    final harness = await _buildHarness(
      initialLocation: '/entries',
      authResults: <AppLockAuthResult>[
        AppLockAuthResult.temporarilyUnavailable,
        AppLockAuthResult.success,
      ],
    );

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('unlock unavailable · try again'), findsOneWidget);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);

    await tester.tap(find.byKey(appLockUnlockButtonKey));
    await tester.pumpAndSettle();

    expect(harness.authenticator.authenticateCallCount, 2);
    expect(find.byKey(appLockOverlayKey), findsNothing);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });
}

class _Harness {
  const _Harness({
    required this.app,
    required this.router,
    required this.authenticator,
    required this.settingsOpener,
  });

  final Widget app;
  final GoRouter router;
  final _FakeAppLockAuthenticator authenticator;
  final _FakeDeviceSecuritySettingsOpener settingsOpener;
}

Future<_Harness> _buildHarness({
  required List<AppLockAuthResult> authResults,
  String initialLocation = '/',
  Completer<AppLockAuthResult>? authenticateCompleter,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final sharedPreferences = await SharedPreferences.getInstance();
  final router = buildAppRouter(initialLocation: initialLocation);
  final authenticator = _FakeAppLockAuthenticator(
    authResults,
    authenticateCompleter: authenticateCompleter,
  );
  final settingsOpener = _FakeDeviceSecuritySettingsOpener();

  final app = ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      appRouterProvider.overrideWithValue(router),
      appLockEnabledProvider.overrideWithValue(true),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      appLockAuthenticatorProvider.overrideWithValue(authenticator),
      deviceSecuritySettingsOpenerProvider.overrideWithValue(settingsOpener),
      preferencesRepositoryProvider.overrideWithValue(
        const _TestPreferencesRepository(),
      ),
      entryRepositoryProvider.overrideWithValue(const _TestEntryRepository()),
      mainRecordingControllerProvider.overrideWith(_SmokeController.new),
    ],
    child: const WraitApp(),
  );

  return _Harness(
    app: app,
    router: router,
    authenticator: authenticator,
    settingsOpener: settingsOpener,
  );
}

class _FakeAppLockAuthenticator implements AppLockAuthenticator {
  _FakeAppLockAuthenticator(
    List<AppLockAuthResult> authResults, {
    this.authenticateCompleter,
  }) : _authResults = List<AppLockAuthResult>.from(authResults);

  final List<AppLockAuthResult> _authResults;
  Completer<AppLockAuthResult>? authenticateCompleter;
  int authenticateCallCount = 0;

  @override
  Future<AppLockAvailability> availability() async {
    final nextResult = _authResults.isEmpty
        ? AppLockAuthResult.success
        : _authResults.first;
    return switch (nextResult) {
      AppLockAuthResult.noSecurityConfigured =>
        AppLockAvailability.noSecurityConfigured,
      AppLockAuthResult.temporarilyUnavailable =>
        AppLockAvailability.temporarilyUnavailable,
      AppLockAuthResult.unavailable => AppLockAvailability.unavailable,
      _ => AppLockAvailability.available,
    };
  }

  @override
  Future<AppLockAuthResult> authenticate({
    required String localizedReason,
  }) async {
    authenticateCallCount += 1;
    final completer = authenticateCompleter;
    if (completer != null) {
      return completer.future;
    }
    if (_authResults.isEmpty) {
      return AppLockAuthResult.success;
    }
    return _authResults.removeAt(0);
  }

  @override
  Future<void> cancel() async {}
}

class _FakeDeviceSecuritySettingsOpener
    implements DeviceSecuritySettingsOpener {
  int openCallCount = 0;

  @override
  Future<bool> openDeviceSecuritySettings() async {
    openCallCount += 1;
    return true;
  }
}

class _SmokeController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _TestEntryRepository implements EntryRepository {
  const _TestEntryRepository();

  @override
  Stream<List<Entry>> watchAllEntries() =>
      Stream<List<Entry>>.value(const <Entry>[_syntheticEntry]);

  @override
  Stream<Entry?> watchEntryById(int id) =>
      Stream<Entry?>.value(id == _syntheticEntry.id ? _syntheticEntry : null);

  @override
  Future<Entry?> getEntryById(int id) async =>
      id == _syntheticEntry.id ? _syntheticEntry : null;

  @override
  Future<void> importEntries(List<Entry> entries) async {}

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {}

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) async {}

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateEntryLanguage(int id, String language) async {}

  @override
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}
}

const _syntheticEntry = Entry(
  id: 1,
  rawTranscript: 'synthetic entry text',
  cleanedText: 'synthetic entry text',
  type: EntryType.saved,
  language: 'en-US',
  createdAt: 1781341200000,
  wordCount: 3,
);

class _TestPreferencesRepository implements PreferencesRepository {
  const _TestPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}
