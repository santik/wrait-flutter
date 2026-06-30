import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/entries/entry_import_file_reader.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/service/entry_export_service.dart';
import 'package:wrait/domain/service/entry_import_service.dart';

void main() {
  test('imports saved and draft rows from a Wrait CSV export', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'wrait-import.csv',
          contents: _validCsv(),
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 2);
    expect(result.fileName, 'wrait-import.csv');
    expect(repository.importedEntries, hasLength(2));
    expect(repository.importedEntries.first.id, 0);
    expect(
      repository.importedEntries.first.rawTranscript,
      'line one,\n"quoted" two',
    );
    expect(repository.importedEntries.first.cleanedText, 'emoji 😀 and عربي');
    expect(repository.importedEntries.first.type, EntryType.saved);
    expect(repository.importedEntries.first.language, 'en-US');
    expect(repository.importedEntries.last.type, EntryType.draft);
    expect(repository.importedEntries.last.cleanedText, isNull);
  });

  test('imports a header-only Wrait CSV as zero records', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'empty.csv',
          contents: EntryExportService.buildCsv(const <Entry>[]),
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 0);
    expect(repository.importCallCount, 1);
    expect(repository.importedEntries, isEmpty);
  });

  test('re-importing the same valid CSV stays additive', () async {
    final repository = _FakeEntryRepository();
    final csv = EntryExportService.buildCsv(<Entry>[
      Entry(
        id: 9,
        rawTranscript: 'repeat me',
        cleanedText: null,
        type: EntryType.saved,
        language: 'en-US',
        createdAt: DateTime.utc(2026, 6, 30, 7).millisecondsSinceEpoch,
        wordCount: 2,
      ),
    ]);
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(fileName: 'repeat.csv', contents: csv),
      ),
      entryRepository: repository,
    );

    final firstResult = await service.importEntries();
    final secondResult = await service.importEntries();

    expect(firstResult.didImport, isTrue);
    expect(secondResult.didImport, isTrue);
    expect(repository.importCallCount, 2);
    expect(repository.importedEntries, hasLength(2));
  });

  test('accepts a UTF-8 BOM on the header row', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'bom.csv',
          contents:
              '\ufeff${EntryExportService.buildCsv(<Entry>[_entry(id: 1)])}',
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 1);
    expect(repository.importCallCount, 1);
  });

  test('accepts CR-only line endings', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'cr.csv',
          contents: EntryExportService.buildCsv(<Entry>[
            _entry(id: 1),
          ]).replaceAll('\n', '\r'),
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isTrue);
    expect(result.importedCount, 1);
    expect(repository.importCallCount, 1);
  });

  test('returns cancelled when the picker is dismissed', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: const _StaticImportFileReader(null),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.wasCancelled, isTrue);
    expect(result.didImport, isFalse);
    expect(repository.importCallCount, 0);
  });

  test(
    'fails without repository mutation when the header is invalid',
    () async {
      final repository = _FakeEntryRepository();
      final service = EntryImportService(
        fileReader: const _StaticImportFileReader(
          EntryImportFileReadResult(
            fileName: 'bad.csv',
            contents: 'wrong,header\n1,2\n',
          ),
        ),
        entryRepository: repository,
      );

      final result = await service.importEntries();

      expect(result.didImport, isFalse);
      expect(result.failureCategory, EntryImportFailureCategory.invalidFormat);
      expect(result.error, isA<FormatException>());
      expect(repository.importCallCount, 0);
    },
  );

  test('fails without repository mutation when a row is malformed', () async {
    final repository = _FakeEntryRepository();
    final validCsv = EntryExportService.buildCsv(<Entry>[
      _entry(id: 3, rawTranscript: 'hello world', cleanedText: 'clean'),
    ]);
    final malformedCsv = validCsv.replaceFirst(
      ',2,hello world,clean',
      ',-2,hello world,clean',
    );
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'bad-word-count.csv',
          contents: malformedCsv,
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.invalidFormat);
    expect(result.error, isA<FormatException>());
    expect(repository.importCallCount, 0);
  });

  test(
    'fails without repository mutation when timestamps do not match',
    () async {
      final repository = _FakeEntryRepository();
      final csv = [
        'id,type,created_at,created_at_epoch_ms,language,word_count,raw_transcript,cleaned_text',
        '1,saved,2026-06-30T09:00:00.000Z,1,en-US,2,hello,clean',
      ].join('\n');
      final service = EntryImportService(
        fileReader: _StaticImportFileReader(
          EntryImportFileReadResult(fileName: 'bad-time.csv', contents: csv),
        ),
        entryRepository: repository,
      );

      final result = await service.importEntries();

      expect(result.didImport, isFalse);
      expect(result.failureCategory, EntryImportFailureCategory.invalidFormat);
      expect(result.error, isA<FormatException>());
      expect(repository.importCallCount, 0);
    },
  );

  test('fails when the CSV exceeds the configured file size limit', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'large.csv',
          contents: '${EntryExportService.csvHeaders.join(',')}\n1234567890',
        ),
      ),
      entryRepository: repository,
      maxImportBytes: 8,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.fileTooLarge);
    expect(result.error, isA<EntryImportTooLargeException>());
    expect(repository.importCallCount, 0);
  });

  test(
    'fails when a transcript field exceeds the configured size limit',
    () async {
      final repository = _FakeEntryRepository();
      final largeTranscript = 'é' * 6;
      final service = EntryImportService(
        fileReader: _StaticImportFileReader(
          EntryImportFileReadResult(
            fileName: 'field-limit.csv',
            contents: EntryExportService.buildCsv(<Entry>[
              _entry(id: 1, rawTranscript: largeTranscript),
            ]),
          ),
        ),
        entryRepository: repository,
        maxTextFieldBytes: 8,
      );

      final result = await service.importEntries();

      expect(result.didImport, isFalse);
      expect(result.failureCategory, EntryImportFailureCategory.fileTooLarge);
      expect(result.error, isA<EntryImportTooLargeException>());
      expect(repository.importCallCount, 0);
    },
  );

  test('maps native file-too-large failures to the size category', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: const _ThrowingImportFileReader(
        EntryImportFileReaderException(
          'too large',
          code: MethodChannelEntryImportFileReader.fileTooLargeErrorCode,
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.fileTooLarge);
    expect(repository.importCallCount, 0);
  });

  test('maps unreadable file-reader failures to the file category', () async {
    final repository = _FakeEntryRepository();
    final service = EntryImportService(
      fileReader: const _ThrowingImportFileReader(
        EntryImportFileReaderException('read failed'),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.unreadableFile);
    expect(repository.importCallCount, 0);
  });

  test('maps repository failures to the storage category', () async {
    final repository = _FakeEntryRepository(throwOnImport: true);
    final service = EntryImportService(
      fileReader: _StaticImportFileReader(
        EntryImportFileReadResult(
          fileName: 'storage.csv',
          contents: EntryExportService.buildCsv(<Entry>[_entry(id: 1)]),
        ),
      ),
      entryRepository: repository,
    );

    final result = await service.importEntries();

    expect(result.didImport, isFalse);
    expect(result.failureCategory, EntryImportFailureCategory.storageFailure);
    expect(result.error, isA<StateError>());
    expect(repository.importCallCount, 1);
  });
}

class _StaticImportFileReader implements EntryImportFileReader {
  const _StaticImportFileReader(this.result);

  final EntryImportFileReadResult? result;

  @override
  Future<EntryImportFileReadResult?> pickCsvImport() async => result;
}

class _ThrowingImportFileReader implements EntryImportFileReader {
  const _ThrowingImportFileReader(this.error);

  final Object error;

  @override
  Future<EntryImportFileReadResult?> pickCsvImport() async {
    throw error;
  }
}

class _FakeEntryRepository implements EntryRepository {
  _FakeEntryRepository({this.throwOnImport = false});

  final bool throwOnImport;
  final List<Entry> importedEntries = <Entry>[];
  int importCallCount = 0;

  @override
  Future<void> importEntries(List<Entry> entries) async {
    importCallCount += 1;
    if (throwOnImport) {
      throw StateError('save failed');
    }
    importedEntries.addAll(entries);
  }

  @override
  Stream<List<Entry>> watchAllEntries() => const Stream<List<Entry>>.empty();

  @override
  Stream<Entry?> watchEntryById(int id) => const Stream<Entry?>.empty();

  @override
  Future<Entry?> getEntryById(int id) async => null;

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {}

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) async {}

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateEntryLanguage(int id, String language) async {}

  @override
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}
}

Entry _entry({
  required int id,
  String rawTranscript = 'imported entry',
  String? cleanedText,
}) {
  return Entry(
    id: id,
    rawTranscript: rawTranscript,
    cleanedText: cleanedText,
    type: EntryType.saved,
    language: 'en-US',
    createdAt: DateTime.utc(2026, 6, 30, 12, 34, 56).millisecondsSinceEpoch,
    wordCount: 2,
  );
}

String _validCsv() {
  return EntryExportService.buildCsv(<Entry>[
    Entry(
      id: 41,
      rawTranscript: 'line one,\n"quoted" two',
      cleanedText: 'emoji 😀 and عربي',
      type: EntryType.saved,
      language: 'en-US',
      createdAt: DateTime.utc(2026, 6, 30, 12, 34, 56).millisecondsSinceEpoch,
      wordCount: 5,
    ),
    Entry(
      id: 42,
      rawTranscript: 'draft import',
      cleanedText: null,
      type: EntryType.draft,
      language: 'fr-FR',
      createdAt: DateTime.utc(2026, 6, 29, 8).millisecondsSinceEpoch,
      wordCount: 2,
    ),
  ]);
}
