import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repository/app_lock_preferences_repository.dart';
import '../../domain/repository/preferences_repository.dart';
import 'platform_device_id_provider.dart';
import 'preferences_repository_impl.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'SharedPreferences must be provided at app startup.',
  ),
);

final platformDeviceIdProvider = Provider<PlatformDeviceIdProvider>(
  (ref) => const MethodChannelPlatformDeviceIdProvider(),
);

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepositoryImpl(
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    deviceIdProvider: ref.watch(platformDeviceIdProvider),
  ),
);

final appLockPreferencesRepositoryProvider =
    Provider<AppLockPreferencesRepository>((ref) {
      final repository = ref.watch(preferencesRepositoryProvider);
      return switch (repository) {
        AppLockPreferencesRepository appLockRepository => appLockRepository,
        _ => const _DisabledAppLockPreferencesRepository(),
      };
    });

class _DisabledAppLockPreferencesRepository
    implements AppLockPreferencesRepository {
  const _DisabledAppLockPreferencesRepository();

  @override
  Future<bool> getAppLockEnabled() async => false;

  @override
  Future<void> setAppLockEnabled(bool value) async {
    throw UnsupportedError('App-lock preferences are not writable.');
  }
}
