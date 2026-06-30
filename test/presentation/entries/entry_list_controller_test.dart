import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/entries/entry_export_file_writer.dart';
import 'package:wrait/data/entries/entry_export_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/service/entry_export_service.dart';
import 'package:wrait/presentation/entries/entry_list_controller.dart';

void main() {
  test('includes drafts and sorts entries newest first', () async {
    final repository = _FakeEntryRepository(
      entries: [
        _entry(id: 1, createdAt: DateTime(2026, 6, 14, 9)),
        _entry(
          id: 2,
          createdAt: DateTime(2026, 6, 15, 9),
          type: EntryType.draft,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [entryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final entriesCompleter = Completer<List<Entry>>();
    final subscription = container.listen<AsyncValue<List<Entry>>>(
      entryListEntriesProvider,
      (previous, next) {
        final entries = next.asData?.value;
        if (entries != null && !entriesCompleter.isCompleted) {
          entriesCompleter.complete(entries);
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final entries = await entriesCompleter.future;

    expect(entries.map((entry) => entry.id), [2, 1]);
    expect(entries.first.type, EntryType.draft);
  });

  test('delete success calls the repository', () async {
    final repository = _FakeEntryRepository(entries: [_entry(id: 1)]);
    final container = ProviderContainer(
      overrides: [entryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(entryListControllerProvider.notifier).deleteEntry(1);

    expect(repository.deletedIds, [1]);
  });

  test('delete failure is caught without throwing', () async {
    final repository = _FakeEntryRepository(
      entries: [_entry(id: 1)],
      throwsOnDelete: true,
    );
    final container = ProviderContainer(
      overrides: [entryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(entryListControllerProvider.notifier).deleteEntry(1);

    expect(repository.deletedIds, [1]);
  });

  test('export success returns the exported file metadata', () async {
    final repository = _FakeEntryRepository(entries: [_entry(id: 1)]);
    final service = EntryExportService(
      fileWriter: const _TestFileWriter(
        result: EntryExportFileWriteResult(
          fileName: 'entries.csv',
          pathLabel: 'Downloads/Wrait',
        ),
      ),
      now: () => DateTime.utc(2026, 6, 30, 12),
    );
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repository),
        entryExportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(entryListControllerProvider.notifier)
        .exportEntries(repository.entriesSnapshot);

    expect(result.didExport, isTrue);
    expect(result.fileName, 'entries.csv');
    expect(result.pathLabel, 'Downloads/Wrait');
    expect(container.read(entryListControllerProvider).isExporting, isFalse);
  });

  test('export failure is caught without throwing and resets state', () async {
    final repository = _FakeEntryRepository(entries: [_entry(id: 1)]);
    final service = EntryExportService(
      fileWriter: const _ThrowingTestFileWriter(),
      now: () => DateTime.utc(2026, 6, 30, 12),
    );
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repository),
        entryExportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(entryListControllerProvider.notifier)
        .exportEntries(repository.entriesSnapshot);

    expect(result.didExport, isFalse);
    expect(container.read(entryListControllerProvider).isExporting, isFalse);
    expect(repository.entriesSnapshot.single.id, 1);
  });
}

class _FakeEntryRepository implements EntryRepository {
  _FakeEntryRepository({
    required List<Entry> entries,
    this.throwsOnDelete = false,
  }) : _entries = List<Entry>.from(entries);

  final bool throwsOnDelete;
  final List<int> deletedIds = <int>[];
  final List<Entry> _entries;

  List<Entry> get entriesSnapshot => List<Entry>.from(_entries);

  @override
  Stream<List<Entry>> watchAllEntries() => Stream<List<Entry>>.value(_entries);

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
  Future<void> deleteEntry(int id) async {
    deletedIds.add(id);
    if (throwsOnDelete) {
      throw StateError('delete failed');
    }
    _entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}
}

class _TestFileWriter implements EntryExportFileWriter {
  const _TestFileWriter({required this.result});

  final EntryExportFileWriteResult result;

  @override
  Future<EntryExportFileWriteResult> writeCsvExport({
    required String fileName,
    required String contents,
  }) async {
    return result;
  }
}

class _ThrowingTestFileWriter implements EntryExportFileWriter {
  const _ThrowingTestFileWriter();

  @override
  Future<EntryExportFileWriteResult> writeCsvExport({
    required String fileName,
    required String contents,
  }) async {
    throw StateError('write failed');
  }
}

Entry _entry({
  required int id,
  DateTime? createdAt,
  EntryType type = EntryType.saved,
}) {
  return Entry(
    id: id,
    rawTranscript: 'entry $id',
    cleanedText: null,
    type: type,
    language: 'en-US',
    createdAt: (createdAt ?? DateTime(2026, 6, 15)).millisecondsSinceEpoch,
    wordCount: 2,
  );
}
