import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_authenticator.dart';
import 'device_security_settings_opener.dart';

/// Defaults app lock to on in production while still allowing test overrides
/// and future rollout controls through Riverpod.
final appLockEnabledProvider = Provider<bool>((ref) => true);

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
