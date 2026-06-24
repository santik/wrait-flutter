import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_authenticator.dart';
import 'device_security_settings_opener.dart';

const _appLockEnabledDefine = 'APP_LOCK_ENABLED';
const _defaultAppLockEnabled = bool.fromEnvironment(
  _appLockEnabledDefine,
  defaultValue: true,
);

/// Defaults app lock to on in production while still allowing test overrides
/// and future rollout controls through Riverpod.
///
/// A targeted `--dart-define=APP_LOCK_ENABLED=false` escape hatch exists for
/// simulator/manual validation where the lock surface would otherwise mask
/// native privacy-cover evidence. Production behavior remains enabled by
/// default.
final appLockEnabledProvider = Provider<bool>((ref) => _defaultAppLockEnabled);

final appLockWarningLoggerProvider = Provider<AppLockLogWarning>((ref) {
  return (message, {error, stackTrace}) {
    developer.log(
      message,
      name: 'AppLock',
      error: error,
      stackTrace: stackTrace,
    );
  };
});

final appLockAuthenticatorProvider = Provider<AppLockAuthenticator>((ref) {
  return LocalAuthAppLockAuthenticator(
    logWarning: ref.read(appLockWarningLoggerProvider),
  );
});

final deviceSecuritySettingsOpenerProvider =
    Provider<DeviceSecuritySettingsOpener>((ref) {
      return BestEffortDeviceSecuritySettingsOpener();
    });
