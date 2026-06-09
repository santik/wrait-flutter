import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/preferences/platform_device_id_provider.dart';
import 'package:wrait/data/preferences/preferences_repository_impl.dart';

void main() {
  late _FakePreferencesStore preferencesStore;
  late PreferencesRepositoryImpl repository;
  late _FakePlatformDeviceIdProvider deviceIdProvider;

  setUp(() {
    preferencesStore = _FakePreferencesStore();
    deviceIdProvider = _FakePlatformDeviceIdProvider('device-id-001');
    repository = PreferencesRepositoryImpl(
      preferencesStore: preferencesStore,
      deviceIdProvider: deviceIdProvider,
    );
  });

  test('hasEverRecorded defaults to false when unset', () async {
    await expectLater(repository.getHasEverRecorded(), completion(isFalse));
  });

  test('hasEverRecorded persists true across repository re-creation', () async {
    await repository.setHasEverRecorded(true);

    final recreated = PreferencesRepositoryImpl(
      preferencesStore: preferencesStore,
      deviceIdProvider: _FakePlatformDeviceIdProvider('device-id-001'),
    );

    await expectLater(recreated.getHasEverRecorded(), completion(isTrue));
  });

  test('hasEverRecorded persists false after being reset from true', () async {
    await repository.setHasEverRecorded(true);
    await repository.setHasEverRecorded(false);

    final recreated = PreferencesRepositoryImpl(
      preferencesStore: preferencesStore,
      deviceIdProvider: _FakePlatformDeviceIdProvider('device-id-001'),
    );

    await expectLater(recreated.getHasEverRecorded(), completion(isFalse));
  });

  test(
    'setHasEverRecorded throws when persistence reports a failed write',
    () async {
      preferencesStore.failBoolWrites = true;

      await expectLater(
        repository.setHasEverRecorded(true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Failed to persist hasEverRecorded',
          ),
        ),
      );
    },
  );

  test(
    'getDeviceId returns an already stored value without querying the platform',
    () async {
      preferencesStore.stringValues[PreferencesRepositoryImpl.deviceIdKey] =
          'stored-device-id';

      final first = await repository.getDeviceId();
      final second = await repository.getDeviceId();

      expect(first, 'stored-device-id');
      expect(second, 'stored-device-id');
      expect(deviceIdProvider.callCount, 0);
    },
  );

  test(
    'getDeviceId stores and reuses the platform value when available first',
    () async {
      final first = await repository.getDeviceId();
      final recreated = PreferencesRepositoryImpl(
        preferencesStore: preferencesStore,
        deviceIdProvider: _FakePlatformDeviceIdProvider(null),
      );
      final second = await recreated.getDeviceId();

      expect(first, 'device-id-001');
      expect(second, 'device-id-001');
      expect(
        preferencesStore.stringValues[PreferencesRepositoryImpl.deviceIdKey],
        'device-id-001',
      );
      expect(deviceIdProvider.callCount, 1);
    },
  );

  test(
    'getDeviceId generates, stores, and reuses a fallback when platform is unavailable',
    () async {
      final fallbackRepository = PreferencesRepositoryImpl(
        preferencesStore: preferencesStore,
        deviceIdProvider: _FakePlatformDeviceIdProvider(null),
        random: _DeterministicRandom(),
      );
      final first = await fallbackRepository.getDeviceId();
      final recreated = PreferencesRepositoryImpl(
        preferencesStore: preferencesStore,
        deviceIdProvider: _FakePlatformDeviceIdProvider(
          'platform-now-available',
        ),
      );
      final second = await recreated.getDeviceId();

      expect(first, '00112233445566778899aabbccddeeff');
      expect(second, first);
      expect(
        preferencesStore.stringValues[PreferencesRepositoryImpl.deviceIdKey],
        first,
      );
    },
  );

  test('getDeviceId caches the first resolved value in memory', () async {
    final first = await repository.getDeviceId();
    deviceIdProvider.value = 'device-id-002';
    final second = await repository.getDeviceId();

    expect(first, 'device-id-001');
    expect(second, 'device-id-001');
    expect(deviceIdProvider.callCount, 1);
  });

  test(
    'getDeviceId hides whether the stored value came from platform or fallback',
    () async {
      final platformResolved = await repository.getDeviceId();

      final fallbackResolvedRepository = PreferencesRepositoryImpl(
        preferencesStore: _FakePreferencesStore(),
        deviceIdProvider: _FakePlatformDeviceIdProvider(null),
        random: _DeterministicRandom(),
      );
      final fallbackResolved = await fallbackResolvedRepository.getDeviceId();

      expect(platformResolved, isA<String>());
      expect(fallbackResolved, isA<String>());
      expect(platformResolved, isNotEmpty);
      expect(fallbackResolved, isNotEmpty);
    },
  );
}

class _FakePlatformDeviceIdProvider implements PlatformDeviceIdProvider {
  _FakePlatformDeviceIdProvider(this._initialValue);

  final String? _initialValue;
  int callCount = 0;
  String? value;

  @override
  Future<String?> getPlatformDeviceId() async {
    callCount += 1;
    return value ?? _initialValue;
  }
}

class _FakePreferencesStore implements PreferencesStore {
  final Map<String, bool> boolValues = {};
  final Map<String, String> stringValues = {};
  bool failBoolWrites = false;
  bool failStringWrites = false;

  @override
  bool? getBool(String key) => boolValues[key];

  @override
  String? getString(String key) => stringValues[key];

  @override
  Future<bool> setBool(String key, bool value) async {
    if (failBoolWrites) {
      return false;
    }

    boolValues[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (failStringWrites) {
      return false;
    }

    stringValues[key] = value;
    return true;
  }
}

class _DeterministicRandom extends _FakeRandom {
  @override
  int nextInt(int max) {
    const bytes = <int>[
      0x00,
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
      0x66,
      0x77,
      0x88,
      0x99,
      0xaa,
      0xbb,
      0xcc,
      0xdd,
      0xee,
      0xff,
    ];
    final value = bytes[_index % bytes.length];
    _index += 1;
    return value % max;
  }
}

abstract class _FakeRandom implements Random {
  int _index = 0;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  int nextInt(int max);
}
