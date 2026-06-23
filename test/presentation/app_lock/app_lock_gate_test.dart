import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/auth/app_lock_authenticator.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/auth/device_security_settings_opener.dart';
import 'package:wrait/presentation/app_lock/app_lock_gate.dart';
import 'package:wrait/presentation/app_lock/app_lock_test_keys.dart';

void main() {
  testWidgets('disabled app lock shows child without overlay', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appLockEnabledProvider.overrideWithValue(false)],
        child: const MaterialApp(
          home: AppLockGate(child: Scaffold(body: Text('secret content'))),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('secret content'), findsOneWidget);
    expect(find.byKey(appLockOverlayKey), findsNothing);
  });

  testWidgets('locked gate blurs content and blocks interaction', (
    tester,
  ) async {
    var tapCount = 0;
    final authenticator = _TestGateAuthenticator()
      ..authenticateCompleter = Completer<AppLockAuthResult>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockAuthenticatorProvider.overrideWithValue(authenticator),
          deviceSecuritySettingsOpenerProvider.overrideWithValue(
            _TestSettingsOpener(),
          ),
        ],
        child: MaterialApp(
          home: AppLockGate(
            child: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    tapCount += 1;
                  },
                  child: const Text('secret action'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byKey(appLockOverlayKey), findsOneWidget);
    expect(find.byKey(appLockBlurKey), findsOneWidget);

    await tester.tap(find.text('secret action'));
    await tester.pump();
    expect(tapCount, 0);
  });

  testWidgets('automatic prompt runs on launch and cancel shows still locked', (
    tester,
  ) async {
    final authenticator = _TestGateAuthenticator(
      nextResults: [AppLockAuthResult.canceled],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockAuthenticatorProvider.overrideWithValue(authenticator),
          deviceSecuritySettingsOpenerProvider.overrideWithValue(
            _TestSettingsOpener(),
          ),
        ],
        child: const MaterialApp(
          home: AppLockGate(child: Scaffold(body: Text('secret content'))),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(authenticator.authenticateCallCount, 1);
    expect(find.text('still locked'), findsOneWidget);
  });

  testWidgets('background and resume re-locks and re-prompts', (tester) async {
    final authenticator = _TestGateAuthenticator(
      nextResults: [AppLockAuthResult.success, AppLockAuthResult.canceled],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockAuthenticatorProvider.overrideWithValue(authenticator),
          deviceSecuritySettingsOpenerProvider.overrideWithValue(
            _TestSettingsOpener(),
          ),
        ],
        child: const MaterialApp(
          home: AppLockGate(child: Scaffold(body: Text('secret content'))),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(appLockOverlayKey), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(authenticator.authenticateCallCount, 2);
    expect(find.text('still locked'), findsOneWidget);
  });

  testWidgets('inactive during an auth prompt does not cancel and restart it', (
    tester,
  ) async {
    final authenticator = _TestGateAuthenticator()
      ..authenticateCompleter = Completer<AppLockAuthResult>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockAuthenticatorProvider.overrideWithValue(authenticator),
          deviceSecuritySettingsOpenerProvider.overrideWithValue(
            _TestSettingsOpener(),
          ),
        ],
        child: const MaterialApp(
          home: AppLockGate(child: Scaffold(body: Text('secret content'))),
        ),
      ),
    );

    await tester.pump();

    expect(authenticator.authenticateCallCount, 1);
    expect(authenticator.cancelCallCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(authenticator.authenticateCallCount, 1);
    expect(authenticator.cancelCallCount, 0);
    expect(find.byKey(appLockOverlayKey), findsOneWidget);

    authenticator.authenticateCompleter!.complete(AppLockAuthResult.success);
    await tester.pumpAndSettle();

    expect(find.byKey(appLockOverlayKey), findsNothing);
  });

  testWidgets('no-security state offers settings and bypass actions', (
    tester,
  ) async {
    final authenticator = _TestGateAuthenticator(
      nextResults: [AppLockAuthResult.noSecurityConfigured],
    );
    final settingsOpener = _TestSettingsOpener();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockAuthenticatorProvider.overrideWithValue(authenticator),
          deviceSecuritySettingsOpenerProvider.overrideWithValue(
            settingsOpener,
          ),
        ],
        child: const MaterialApp(
          home: AppLockGate(child: Scaffold(body: Text('secret content'))),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('set up device security to protect Wrait'),
      findsOneWidget,
    );
    expect(find.byKey(appLockSettingsButtonKey), findsOneWidget);
    expect(find.byKey(appLockBypassButtonKey), findsOneWidget);

    await tester.tap(find.byKey(appLockSettingsButtonKey));
    await tester.pump();
    expect(settingsOpener.openCallCount, 1);

    await tester.tap(find.byKey(appLockBypassButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(appLockOverlayKey), findsNothing);
  });

  testWidgets('lock screen actions expose accessibility semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final authenticator = _TestGateAuthenticator(
      nextResults: [AppLockAuthResult.noSecurityConfigured],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockAuthenticatorProvider.overrideWithValue(authenticator),
          deviceSecuritySettingsOpenerProvider.overrideWithValue(
            _TestSettingsOpener(),
          ),
        ],
        child: const MaterialApp(
          home: AppLockGate(child: Scaffold(body: Text('secret content'))),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final unlockNode = tester.getSemantics(find.byKey(appLockUnlockButtonKey));
    expect(unlockNode.label, contains('Unlock'));
    expect(
      unlockNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(find.text('wrait is locked'), findsOneWidget);
    expect(find.byKey(appLockSettingsButtonKey), findsOneWidget);

    semantics.dispose();
  });
}

class _TestGateAuthenticator implements AppLockAuthenticator {
  _TestGateAuthenticator({List<AppLockAuthResult>? nextResults})
    : _nextResults = nextResults ?? <AppLockAuthResult>[];

  final List<AppLockAuthResult> _nextResults;
  Completer<AppLockAuthResult>? authenticateCompleter;
  int authenticateCallCount = 0;
  int cancelCallCount = 0;

  @override
  Future<AppLockAvailability> availability() async {
    return AppLockAvailability.available;
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
    if (_nextResults.isEmpty) {
      return AppLockAuthResult.success;
    }
    return _nextResults.removeAt(0);
  }

  @override
  Future<void> cancel() async {
    cancelCallCount += 1;
  }
}

class _TestSettingsOpener implements DeviceSecuritySettingsOpener {
  int openCallCount = 0;

  @override
  Future<bool> openDeviceSecuritySettings() async {
    openCallCount += 1;
    return true;
  }
}
