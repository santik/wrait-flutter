import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/auth/app_lock_authenticator.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/repository/app_lock_preferences_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';
import 'package:wrait/presentation/settings/settings_screen.dart';
import 'package:wrait/presentation/settings/settings_test_keys.dart';

void main() {
  testWidgets('shows disabled default and enables without authenticating', (
    tester,
  ) async {
    final repository = _PreferencesRepository();
    final authenticator = _Authenticator();
    await tester.pumpWidget(
      _app(repository: repository, authenticator: authenticator),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byKey(appLockSwitchKey)).value,
      false,
    );

    await tester.tap(find.byKey(appLockSwitchKey));
    await tester.pumpAndSettle();

    expect(repository.enabled, isTrue);
    expect(authenticator.authenticateCalls, 0);
    expect(
      tester.widget<SwitchListTile>(find.byKey(appLockSwitchKey)).value,
      true,
    );
  });

  testWidgets('no security keeps switch off and offers device settings', (
    tester,
  ) async {
    final repository = _PreferencesRepository();
    final authenticator = _Authenticator(
      nextAvailability: AppLockAvailability.noSecurityConfigured,
    );
    await tester.pumpWidget(
      _app(repository: repository, authenticator: authenticator),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(appLockSwitchKey));
    await tester.pumpAndSettle();

    expect(repository.enabled, isFalse);
    expect(find.byKey(appLockDeviceSettingsKey), findsOneWidget);
    expect(find.textContaining('Set up a device screen lock'), findsOneWidget);
  });

  testWidgets('large text keeps app-lock controls reachable', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(
          repository: _PreferencesRepository(),
          authenticator: _Authenticator(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App lock'), findsOneWidget);
    expect(find.byKey(appLockSwitchKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recording disables changes until recording stops', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        repository: _PreferencesRepository(),
        authenticator: _Authenticator(),
        recordingController: _RecordingController.new,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byKey(appLockSwitchKey)).onChanged,
      isNull,
    );
    expect(
      find.text('Finish the current recording before changing app lock.'),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final controller = container.read(
      mainRecordingControllerProvider.notifier,
    ) as _RecordingController;
    controller.finishRecording();
    await tester.pump();

    expect(
      tester.widget<SwitchListTile>(find.byKey(appLockSwitchKey)).onChanged,
      isNotNull,
    );
    expect(
      find.text('Finish the current recording before changing app lock.'),
      findsNothing,
    );
  });
}

Widget _app({
  required _PreferencesRepository repository,
  required _Authenticator authenticator,
  MainRecordingController Function()? recordingController,
}) {
  return ProviderScope(
    overrides: [
      preferencesRepositoryProvider.overrideWithValue(repository),
      appLockAuthenticatorProvider.overrideWithValue(authenticator),
      mainRecordingControllerProvider.overrideWith(
        recordingController ?? _IdleController.new,
      ),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

class _IdleController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();
}

class _RecordingController extends MainRecordingController {
  @override
  RecordingControllerState build() => RecordingControllerState(
    recordingState: RecordingListening(hardCapDeadlineElapsedRealtime: 1),
  );

  void finishRecording() {
    state = const RecordingControllerState();
  }
}

class _PreferencesRepository
    implements PreferencesRepository, AppLockPreferencesRepository {
  bool enabled = false;

  @override
  Future<bool> getAppLockEnabled() async => enabled;

  @override
  Future<void> setAppLockEnabled(bool value) async {
    enabled = value;
  }

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => false;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

class _Authenticator implements AppLockAuthenticator {
  _Authenticator({this.nextAvailability = AppLockAvailability.available});

  final AppLockAvailability nextAvailability;
  int authenticateCalls = 0;

  @override
  Future<AppLockAvailability> availability() async => nextAvailability;

  @override
  Future<AppLockAuthResult> authenticate({
    required String localizedReason,
  }) async {
    authenticateCalls += 1;
    return AppLockAuthResult.success;
  }

  @override
  Future<void> cancel() async {}
}
