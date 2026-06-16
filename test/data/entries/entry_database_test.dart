import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/core/time/system_clock.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/entry_repository_impl.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/domain/repository/entry_repository.dart';

import '../../test_doubles/fake_clock.dart';
import '../../test_doubles/fake_secure_storage.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('wrait-db-test');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('generates and persists a database key once', () async {
    final storage = FakeSecureKeyValueStore();
    final keyStore = DatabaseKeyStore(storage, random: Random(1));

    final first = await keyStore.readOrCreateKey();
    final second = await keyStore.readOrCreateKey();

    expect(first, isNotEmpty);
    expect(second, first);
    expect(await storage.read(DatabaseKeyStore.storageKey), first);
  });

  test('fails fast when encrypted sqlite support is unavailable', () async {
    await expectLater(
      LocalEntryDatabase.open(
        keyStore: DatabaseKeyStore(
          FakeSecureKeyValueStore(),
          random: Random(9),
        ),
        databaseFile: _databaseFile(tempDirectory),
        verifyCipherSupport: (_) {
          throw StateError('cipher support unavailable');
        },
      ),
      throwsA(
        predicate(
          (error) => error.toString().contains('cipher support unavailable'),
          'error containing the injected cipher-support failure message',
        ),
      ),
    );
  });

  test(
    'creates an encrypted database file whose plaintext transcript is absent',
    () async {
      final harness = await _createHarness(
        directory: tempDirectory,
        storage: FakeSecureKeyValueStore(),
        clock: FakeClock(_ts(2026, 6, 8)),
        random: Random(2),
      );

      await harness.repository.saveEntry('very secret journal line', 'en-US');
      await harness.database.close();

      final fileContents = utf8.decode(
        await harness.databaseFile.readAsBytes(),
        allowMalformed: true,
      );

      expect(await harness.databaseFile.exists(), isTrue);
      expect(fileContents, isNot(contains('very secret journal line')));
    },
  );

  test('recreates a fresh usable database after key loss', () async {
    final initialStorage = FakeSecureKeyValueStore();
    final initialHarness = await _createHarness(
      directory: tempDirectory,
      storage: initialStorage,
      clock: FakeClock(_ts(2026, 6, 8)),
      random: Random(3),
    );
    await initialHarness.repository.saveEntry(
      'persisted before key loss',
      'en-US',
    );
    await initialHarness.database.close();

    final recoveredHarness = await _createHarness(
      directory: tempDirectory,
      storage: FakeSecureKeyValueStore(),
      clock: FakeClock(_ts(2026, 6, 9)),
      random: Random(4),
    );

    final entries = await recoveredHarness.repository.watchAllEntries().first;

    expect(entries, isEmpty);

    await recoveredHarness.repository.saveEntry(
      'fresh after recovery',
      'en-US',
    );
    final recoveredEntries = await recoveredHarness.repository
        .watchAllEntries()
        .firstWhere((items) => items.isNotEmpty);
    expect(recoveredEntries.single.rawTranscript, 'fresh after recovery');
    await recoveredHarness.database.close();
  });

  test(
    'startup bootstrap initializes the store and deletes stale drafts',
    () async {
      final storage = FakeSecureKeyValueStore();
      final keyStore = DatabaseKeyStore(storage, random: Random(5));
      final seedDatabase = await LocalEntryDatabase.open(
        keyStore: keyStore,
        databaseFile: _databaseFile(tempDirectory),
      );

      final oldClock = FakeClock(_ts(2026, 5, 20));
      final seedRepository = EntryRepositoryImpl(
        entryDao: seedDatabase.entryDao,
        clock: oldClock,
      );
      final staleAudioFile = File('${tempDirectory.path}/stale-audio.m4a');
      await staleAudioFile.writeAsString('audio');
      await seedRepository.saveAudioDraft(staleAudioFile.path, 'en-US');

      final freshClock = FakeClock(_ts(2026, 6, 6));
      final freshRepository = EntryRepositoryImpl(
        entryDao: seedDatabase.entryDao,
        clock: freshClock,
      );
      await freshRepository.saveDraft('keep me', 'en-US');
      await seedDatabase.close();

      final bootstrap = LocalEntryStartupBootstrap(
        keyStore: keyStore,
        clock: FakeClock(_ts(2026, 6, 8)),
        openDatabase: (keyStore, file) =>
            LocalEntryDatabase.open(keyStore: keyStore, databaseFile: file),
      );

      final bootstrappedDatabase = await bootstrap.prepare(
        databaseFile: _databaseFile(tempDirectory),
      );
      final bootstrappedRepository = EntryRepositoryImpl(
        entryDao: bootstrappedDatabase.entryDao,
        clock: const SystemClock(),
      );

      final remainingDrafts = await bootstrappedRepository.getPendingDrafts();

      expect(remainingDrafts, hasLength(1));
      expect(remainingDrafts.single.rawTranscript, 'keep me');
      expect(await staleAudioFile.exists(), isFalse);
      await bootstrappedDatabase.close();
    },
  );

  test(
    'reopens a seeded database with 1000 entries within a host-side startup budget',
    () async {
      final storage = FakeSecureKeyValueStore();
      final keyStore = DatabaseKeyStore(storage, random: Random(6));
      final file = _databaseFile(tempDirectory);
      final seedDatabase = await LocalEntryDatabase.open(
        keyStore: keyStore,
        databaseFile: file,
      );
      final createdAt = _ts(2026, 6, 8);

      await seedDatabase.batch((batch) {
        batch.insertAll(
          seedDatabase.entryRecords,
          List<EntryRecordsCompanion>.generate(
            1000,
            (index) => EntryRecordsCompanion.insert(
              rawTranscript: 'seeded entry $index',
              isDraft: false,
              language: 'en-US',
              createdAt: createdAt,
              cleanedText: const Value.absent(),
              wordCount: const Value(3),
              audioPath: const Value.absent(),
            ),
          ),
        );
      });
      await seedDatabase.close();

      final reopenStopwatch = Stopwatch()..start();
      final reopenedDatabase = await LocalEntryDatabase.open(
        keyStore: keyStore,
        databaseFile: file,
      );
      reopenStopwatch.stop();

      final countRow = await reopenedDatabase
          .customSelect('SELECT COUNT(*) AS count FROM entries;')
          .getSingle();
      final entryCount = countRow.data['count'] as int;
      debugPrint(
        'LocalEntryDatabase reopen with 1000 entries took ${reopenStopwatch.elapsedMilliseconds}ms.',
      );

      expect(entryCount, 1000);
      expect(reopenStopwatch.elapsed, lessThan(const Duration(seconds: 3)));
      await reopenedDatabase.close();
    },
  );
}

class _DatabaseHarness {
  _DatabaseHarness({
    required this.database,
    required this.repository,
    required this.databaseFile,
  });

  final LocalEntryDatabase database;
  final EntryRepository repository;
  final File databaseFile;
}

Future<_DatabaseHarness> _createHarness({
  required Directory directory,
  required FakeSecureKeyValueStore storage,
  required Clock clock,
  required Random random,
}) async {
  final keyStore = DatabaseKeyStore(storage, random: random);
  final databaseFile = _databaseFile(directory);
  final database = await LocalEntryDatabase.open(
    keyStore: keyStore,
    databaseFile: databaseFile,
  );
  final repository = EntryRepositoryImpl(
    entryDao: database.entryDao,
    clock: clock,
  );

  return _DatabaseHarness(
    database: database,
    repository: repository,
    databaseFile: databaseFile,
  );
}

File _databaseFile(Directory directory) =>
    File('${directory.path}/${LocalEntryDatabase.databaseFileName}');

int _ts(int year, int month, int day) =>
    DateTime(year, month, day).millisecondsSinceEpoch;
