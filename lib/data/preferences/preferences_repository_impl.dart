import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repository/preferences_repository.dart';
import 'platform_device_id_provider.dart';

abstract interface class PreferencesStore {
  bool? getBool(String key);
  String? getString(String key);
  Future<bool> setBool(String key, bool value);
  Future<bool> setString(String key, String value);
}

class SharedPreferencesStore implements PreferencesStore {
  const SharedPreferencesStore(this._sharedPreferences);

  final SharedPreferences _sharedPreferences;

  @override
  bool? getBool(String key) => _sharedPreferences.getBool(key);

  @override
  String? getString(String key) => _sharedPreferences.getString(key);

  @override
  Future<bool> setBool(String key, bool value) {
    return _sharedPreferences.setBool(key, value);
  }

  @override
  Future<bool> setString(String key, String value) {
    return _sharedPreferences.setString(key, value);
  }
}

class PreferencesRepositoryImpl implements PreferencesRepository {
  PreferencesRepositoryImpl({
    SharedPreferences? sharedPreferences,
    PreferencesStore? preferencesStore,
    required this.deviceIdProvider,
    Random? random,
  }) : assert(
         sharedPreferences != null || preferencesStore != null,
         'sharedPreferences or preferencesStore must be provided',
       ),
       _preferencesStore =
           preferencesStore ?? SharedPreferencesStore(sharedPreferences!),
       _random = random ?? Random.secure();

  static const hasEverRecordedKey = 'has_ever_recorded';
  static const deviceIdKey = 'app_device_id';
  static const deviceIdSalt = 'wrait-v1';

  final PlatformDeviceIdProvider deviceIdProvider;
  final PreferencesStore _preferencesStore;
  final Random _random;
  String? _cachedDeviceId;

  @override
  Future<bool> getHasEverRecorded() async {
    return _preferencesStore.getBool(hasEverRecordedKey) ?? false;
  }

  @override
  Future<void> setHasEverRecorded(bool value) async {
    final persisted = await _preferencesStore.setBool(
      hasEverRecordedKey,
      value,
    );
    if (!persisted) {
      throw StateError('Failed to persist hasEverRecorded');
    }
  }

  @override
  Future<String> getDeviceId() async {
    final cachedDeviceId = _cachedDeviceId;
    if (cachedDeviceId != null && cachedDeviceId.isNotEmpty) {
      return cachedDeviceId;
    }

    final storedDeviceId = _preferencesStore.getString(deviceIdKey)?.trim();
    if (storedDeviceId != null && storedDeviceId.isNotEmpty) {
      _cachedDeviceId = storedDeviceId;
      return storedDeviceId;
    }

    final platformDeviceId = await deviceIdProvider.getPlatformDeviceId();
    final rawDeviceId = platformDeviceId ?? _generateFallbackDeviceId();
    final resolvedDeviceId = _hashDeviceId(rawDeviceId);
    final persisted = await _preferencesStore.setString(
      deviceIdKey,
      resolvedDeviceId,
    );
    if (!persisted) {
      throw StateError('Failed to persist deviceId');
    }

    _cachedDeviceId = resolvedDeviceId;
    return resolvedDeviceId;
  }

  String _hashDeviceId(String rawDeviceId) {
    final digest = sha256.convert(utf8.encode('$rawDeviceId|$deviceIdSalt'));
    return digest.toString();
  }

  String _generateFallbackDeviceId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
