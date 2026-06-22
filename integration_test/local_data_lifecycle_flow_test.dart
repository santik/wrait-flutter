import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/core/time/system_clock.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/preferences/platform_device_id_provider.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/main.dart';

import '../test/test_doubles/fake_secure_storage.dart';

const _scenario = String.fromEnvironment(
  'US030_SCENARIO',
  defaultValue: 'isolated',
);
const _platformRawDeviceId = 'us030-platform-device';
const _savedRawTranscript = 'raw transcript seed';
const _savedCleanedText = 'cleaned transcript seed';
const _draftLanguage = 'en-US';
const _savedLanguage = 'en-US';
const _deviceIdSalt = 'wrait-v1';
const _seededStatePrefsPrefix = 'us030.seeded_state.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  switch (_scenario) {
    case 'platform-seed':
      _registerPlatformSeedScenario();
      break;
    case 'platform-update-verify':
      _registerPlatformUpdateVerifyScenario();
      break;
    case 'platform-fresh-state':
      _registerPlatformFreshStateScenario();
      break;
    default:
      _registerIsolatedScenario();
      break;
  }
}

void _registerIsolatedScenario() {
  testWidgets(
    'isolated lifecycle preserves update state and resets after explicit data removal',
    (tester) async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'wrait-us030-lifecycle',
      );
      final secureStorage = FakeSecureKeyValueStore();
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();

      _LifecycleRuntime? runtime;
      try {
        final seedClock = _MutableClock(DateTime(2026, 6, 20, 9));
        runtime = await _createIsolatedRuntime(
          tempDirectory: tempDirectory,
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          clock: seedClock,
          initialLocation: '/entries',
        );
        final seededState = await _seedLifecycleState(
          repository: runtime.container.read(entryRepositoryProvider),
          preferencesRepository: runtime.container.read(
            preferencesRepositoryProvider,
          ),
          clock: seedClock,
          draftAudioFile: File('${tempDirectory.path}/us030-draft-audio.m4a'),
        );
        await runtime.dispose(deleteTempDirectory: false);

        runtime = await _createIsolatedRuntime(
          tempDirectory: tempDirectory,
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          clock: _MutableClock(DateTime(2026, 6, 20, 10)),
          initialLocation: '/entries',
        );

        await _expectLifecycleState(
          repository: runtime.container.read(entryRepositoryProvider),
          preferencesRepository: runtime.container.read(
            preferencesRepositoryProvider,
          ),
          expected: seededState,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: runtime.container,
            child: const WraitApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
        expect(find.textContaining(_savedCleanedText), findsOneWidget);

        await runtime.dispose(deleteTempDirectory: false);

        await _clearIsolatedState(
          tempDirectory: tempDirectory,
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
        );

        runtime = await _createIsolatedRuntime(
          tempDirectory: tempDirectory,
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          clock: _MutableClock(DateTime(2026, 6, 20, 11)),
          initialLocation: '/entries',
        );

        await _expectFreshState(
          repository: runtime.container.read(entryRepositoryProvider),
          preferencesRepository: runtime.container.read(
            preferencesRepositoryProvider,
          ),
        );
      } finally {
        await runtime?.dispose();
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      }
    },
  );
}

void _registerPlatformSeedScenario() {
  testWidgets('platform seed scenario prepares persistent update data', (
    tester,
  ) async {
    await _clearPlatformState();

    final seedClock = _MutableClock(DateTime(2026, 6, 20, 12));
    final runtime = await _createPlatformRuntime(clock: seedClock);
    try {
      final seededState = await _seedLifecycleState(
        repository: runtime.container.read(entryRepositoryProvider),
        preferencesRepository: runtime.container.read(
          preferencesRepositoryProvider,
        ),
        clock: seedClock,
        draftAudioFile: await _platformDraftAudioFile(),
      );
      await _persistPlatformExpectedState(seededState);
      await _expectLifecycleState(
        repository: runtime.container.read(entryRepositoryProvider),
        preferencesRepository: runtime.container.read(
          preferencesRepositoryProvider,
        ),
        expected: seededState,
      );
    } finally {
      await runtime.dispose(deleteTempDirectory: false);
    }
  });
}

void _registerPlatformUpdateVerifyScenario() {
  testWidgets('platform update verify scenario keeps local data intact', (
    tester,
  ) async {
    final runtime = await _createPlatformRuntime();

    try {
      await _expectLifecycleState(
        repository: runtime.container.read(entryRepositoryProvider),
        preferencesRepository: runtime.container.read(
          preferencesRepositoryProvider,
        ),
        expected: await _loadPlatformExpectedState(),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: runtime.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
      expect(find.textContaining(_savedCleanedText), findsOneWidget);
    } finally {
      await runtime.dispose(deleteTempDirectory: false);
    }
  });
}

void _registerPlatformFreshStateScenario() {
  testWidgets('platform fresh state scenario starts without prior diary data', (
    tester,
  ) async {
    final runtime = await _createPlatformRuntime();

    try {
      await _expectFreshState(
        repository: runtime.container.read(entryRepositoryProvider),
        preferencesRepository: runtime.container.read(
          preferencesRepositoryProvider,
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: runtime.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);
    } finally {
      await runtime.dispose(deleteTempDirectory: false);
    }
  });
}

class _LifecycleRuntime {
  _LifecycleRuntime({
    required this.container,
    required this.database,
    this.tempDirectory,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory? tempDirectory;

  Future<void> dispose({bool deleteTempDirectory = true}) async {
    container.dispose();
    await database.close();
    if (deleteTempDirectory && tempDirectory != null) {
      final directory = tempDirectory!;
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }
}

class _SeededLifecycleState {
  const _SeededLifecycleState({
    required this.savedEntryId,
    required this.draftEntryId,
    required this.savedCreatedAt,
    required this.draftCreatedAt,
    required this.savedLanguage,
    required this.draftLanguage,
    required this.savedRawTranscript,
    required this.savedCleanedText,
    required this.savedWordCount,
    required this.draftAudioPath,
    required this.storedDeviceId,
  });

  final int savedEntryId;
  final int draftEntryId;
  final int savedCreatedAt;
  final int draftCreatedAt;
  final String savedLanguage;
  final String draftLanguage;
  final String savedRawTranscript;
  final String savedCleanedText;
  final int savedWordCount;
  final String draftAudioPath;
  final String storedDeviceId;
}

class _MutableClock implements Clock {
  _MutableClock(DateTime seed) : _now = seed.millisecondsSinceEpoch;

  int _now;

  void advance(Duration duration) {
    _now += duration.inMilliseconds;
  }

  @override
  int now() => _now;
}

class _FakePlatformDeviceIdProvider implements PlatformDeviceIdProvider {
  const _FakePlatformDeviceIdProvider(this.value);

  final String value;

  @override
  Future<String?> getPlatformDeviceId() async => value;
}

Future<_LifecycleRuntime> _createIsolatedRuntime({
  required Directory tempDirectory,
  required FakeSecureKeyValueStore secureStorage,
  required SharedPreferences sharedPreferences,
  required Clock clock,
  required String initialLocation,
}) async {
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(secureStorage, random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );

  final container = createAppContainer(
    appConfig: _appConfig,
    entryDatabase: database,
    sharedPreferences: sharedPreferences,
    overrides: [
      clockProvider.overrideWithValue(clock),
      appRouterProvider.overrideWithValue(
        buildAppRouter(initialLocation: initialLocation),
      ),
      platformDeviceIdProvider.overrideWithValue(
        const _FakePlatformDeviceIdProvider(_platformRawDeviceId),
      ),
    ],
  );

  return _LifecycleRuntime(
    container: container,
    database: database,
    tempDirectory: tempDirectory,
  );
}

Future<_LifecycleRuntime> _createPlatformRuntime({
  Clock clock = const SystemClock(),
}) async {
  final database = await bootstrapLocalEntryDatabase();
  final sharedPreferences = await SharedPreferences.getInstance();

  final container = createAppContainer(
    appConfig: _appConfig,
    entryDatabase: database,
    sharedPreferences: sharedPreferences,
    overrides: [
      clockProvider.overrideWithValue(clock),
      appRouterProvider.overrideWithValue(
        buildAppRouter(initialLocation: '/entries'),
      ),
      platformDeviceIdProvider.overrideWithValue(
        const _FakePlatformDeviceIdProvider(_platformRawDeviceId),
      ),
    ],
  );

  return _LifecycleRuntime(container: container, database: database);
}

Future<_SeededLifecycleState> _seedLifecycleState({
  required EntryRepository repository,
  required PreferencesRepository preferencesRepository,
  required _MutableClock clock,
  required File draftAudioFile,
}) async {
  if (await draftAudioFile.exists()) {
    await draftAudioFile.delete();
  }
  await draftAudioFile.parent.create(recursive: true);
  await draftAudioFile.writeAsString('draft audio bytes');

  final savedEntryId = await repository.saveEntry(
    _savedRawTranscript,
    _savedLanguage,
  );
  await repository.updateEditedCleanedText(savedEntryId, _savedCleanedText);
  final savedEntry = await repository.getEntryById(savedEntryId);
  expect(savedEntry, isNotNull);

  clock.advance(const Duration(minutes: 1));
  final draftEntryId = await repository.saveAudioDraft(
    draftAudioFile.path,
    _draftLanguage,
  );
  await preferencesRepository.setHasEverRecorded(true);
  final storedDeviceId = await preferencesRepository.getDeviceId();

  return _SeededLifecycleState(
    savedEntryId: savedEntryId,
    draftEntryId: draftEntryId,
    savedCreatedAt: savedEntry!.createdAt,
    draftCreatedAt: (await repository.getEntryById(draftEntryId))!.createdAt,
    savedLanguage: savedEntry.language,
    draftLanguage: _draftLanguage,
    savedRawTranscript: _savedRawTranscript,
    savedCleanedText: _savedCleanedText,
    savedWordCount: savedEntry.wordCount,
    draftAudioPath: draftAudioFile.path,
    storedDeviceId: storedDeviceId,
  );
}

Future<void> _persistPlatformExpectedState(_SeededLifecycleState state) async {
  final sharedPreferences = await SharedPreferences.getInstance();
  await sharedPreferences.setInt(
    '${_seededStatePrefsPrefix}savedEntryId',
    state.savedEntryId,
  );
  await sharedPreferences.setInt(
    '${_seededStatePrefsPrefix}draftEntryId',
    state.draftEntryId,
  );
  await sharedPreferences.setInt(
    '${_seededStatePrefsPrefix}savedCreatedAt',
    state.savedCreatedAt,
  );
  await sharedPreferences.setInt(
    '${_seededStatePrefsPrefix}draftCreatedAt',
    state.draftCreatedAt,
  );
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}savedLanguage',
    state.savedLanguage,
  );
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}draftLanguage',
    state.draftLanguage,
  );
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}savedRawTranscript',
    state.savedRawTranscript,
  );
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}savedCleanedText',
    state.savedCleanedText,
  );
  await sharedPreferences.setInt(
    '${_seededStatePrefsPrefix}savedWordCount',
    state.savedWordCount,
  );
  await sharedPreferences.setString(
    '${_seededStatePrefsPrefix}storedDeviceId',
    state.storedDeviceId,
  );
}

Future<_SeededLifecycleState> _loadPlatformExpectedState() async {
  final sharedPreferences = await SharedPreferences.getInstance();

  int requireInt(String suffix) {
    final value = sharedPreferences.getInt('$_seededStatePrefsPrefix$suffix');
    if (value == null) {
      throw StateError('Missing persisted US-030 seeded-state int: $suffix');
    }
    return value;
  }

  String requireString(String suffix) {
    final value = sharedPreferences.getString(
      '$_seededStatePrefsPrefix$suffix',
    );
    if (value == null || value.isEmpty) {
      throw StateError('Missing persisted US-030 seeded-state string: $suffix');
    }
    return value;
  }

  return _SeededLifecycleState(
    savedEntryId: requireInt('savedEntryId'),
    draftEntryId: requireInt('draftEntryId'),
    savedCreatedAt: requireInt('savedCreatedAt'),
    draftCreatedAt: requireInt('draftCreatedAt'),
    savedLanguage: requireString('savedLanguage'),
    draftLanguage: requireString('draftLanguage'),
    savedRawTranscript: requireString('savedRawTranscript'),
    savedCleanedText: requireString('savedCleanedText'),
    savedWordCount: requireInt('savedWordCount'),
    draftAudioPath: (await _platformDraftAudioFile()).path,
    storedDeviceId: requireString('storedDeviceId'),
  );
}

Future<void> _expectLifecycleState({
  required EntryRepository repository,
  required PreferencesRepository preferencesRepository,
  required _SeededLifecycleState expected,
}) async {
  final entries = await repository.watchAllEntries().first;
  final savedEntry = entries.singleWhere(
    (entry) => entry.id == expected.savedEntryId,
  );
  final draftEntry = entries.singleWhere(
    (entry) => entry.id == expected.draftEntryId,
  );

  expect(entries, hasLength(2));
  expect(savedEntry.isDraft, isFalse);
  expect(savedEntry.rawTranscript, expected.savedRawTranscript);
  expect(savedEntry.cleanedText, expected.savedCleanedText);
  expect(savedEntry.language, expected.savedLanguage);
  expect(savedEntry.createdAt, expected.savedCreatedAt);
  expect(savedEntry.wordCount, expected.savedWordCount);
  expect(savedEntry.audioPath, isNull);

  expect(draftEntry.isDraft, isTrue);
  expect(draftEntry.rawTranscript, isEmpty);
  expect(draftEntry.cleanedText, isNull);
  expect(draftEntry.language, expected.draftLanguage);
  expect(draftEntry.createdAt, expected.draftCreatedAt);
  expect(draftEntry.audioPath, expected.draftAudioPath);
  expect(await File(draftEntry.audioPath!).exists(), isTrue);

  expect(await preferencesRepository.getHasEverRecorded(), isTrue);
  expect(await preferencesRepository.getDeviceId(), expected.storedDeviceId);
}

Future<void> _expectFreshState({
  required EntryRepository repository,
  required PreferencesRepository preferencesRepository,
}) async {
  final entries = await repository.watchAllEntries().first;
  final drafts = await repository.getPendingDrafts();

  expect(entries, isEmpty);
  expect(drafts, isEmpty);
  expect(await preferencesRepository.getHasEverRecorded(), isFalse);
  expect(await preferencesRepository.getDeviceId(), _expectedStoredDeviceId());
}

Future<void> _clearIsolatedState({
  required Directory tempDirectory,
  required FakeSecureKeyValueStore secureStorage,
  required SharedPreferences sharedPreferences,
}) async {
  await LocalEntryDatabase.deleteDatabaseArtifacts(
    File('${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}'),
  );
  await secureStorage.delete(DatabaseKeyStore.storageKey);
  await sharedPreferences.clear();

  final draftFile = File('${tempDirectory.path}/us030-draft-audio.m4a');
  if (await draftFile.exists()) {
    await draftFile.delete();
  }
}

Future<void> _clearPlatformState() async {
  await LocalEntryDatabase.deleteDatabaseArtifacts(
    await LocalEntryDatabase.defaultDatabaseFile(),
  );

  final secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );
  await secureStorage.delete(key: DatabaseKeyStore.storageKey);

  final sharedPreferences = await SharedPreferences.getInstance();
  await sharedPreferences.clear();

  final draftFile = await _platformDraftAudioFile();
  if (await draftFile.exists()) {
    await draftFile.delete();
  }
}

Future<File> _platformDraftAudioFile() async {
  final directory = await getTemporaryDirectory();
  return File('${directory.path}/us030-draft-audio.m4a');
}

String _expectedStoredDeviceId() {
  final digest = sha256.convert(
    utf8.encode('$_platformRawDeviceId|$_deviceIdSalt'),
  );
  return digest.toString();
}

const _appConfig = AppConfig(
  backendUrl: 'https://wrait-backend.vercel.app',
  proxySecret: '',
  recordingHardCapMs: 120000,
);
