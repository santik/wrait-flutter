import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
