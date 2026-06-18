import 'dart:io';

import 'package:drift/drift.dart';

import '../../core/time/system_clock.dart';
import '../../domain/model/entry.dart';
import '../../domain/model/supported_language.dart';
import '../../domain/repository/entry_repository.dart';
import 'entry_mapper.dart';
import 'local_entry_database.dart';

class EntryRepositoryImpl implements EntryRepository {
  EntryRepositoryImpl({required this.entryDao, required this.clock});

  final EntryDao entryDao;
  final Clock clock;

  @override
  Stream<List<Entry>> watchAllEntries() {
    return entryDao.watchAllEntries().map(
      (rows) => rows.map((row) => row.toDomain()).toList(growable: false),
    );
  }

  @override
  Stream<Entry?> watchEntryById(int id) {
    return entryDao.watchEntryById(id).map((row) => row?.toDomain());
  }

  @override
  Future<Entry?> getEntryById(int id) async {
    return (await entryDao.getEntryById(id))?.toDomain();
  }

  @override
  Future<int> saveDraft(String transcript, String language) {
    final canonicalLanguage = _requireSupportedLanguage(language);

    return entryDao.insertEntry(
      EntryRecordsCompanion.insert(
        rawTranscript: transcript,
        isDraft: true,
        language: canonicalLanguage,
        createdAt: clock.now(),
        wordCount: Value(_countWords(transcript)),
      ),
    );
  }

  @override
  Future<int> saveEntry(String transcript, String language) {
    final canonicalLanguage = _requireSupportedLanguage(language);

    return entryDao.insertEntry(
      EntryRecordsCompanion.insert(
        rawTranscript: transcript,
        isDraft: false,
        language: canonicalLanguage,
        createdAt: clock.now(),
        wordCount: Value(_countWords(transcript)),
      ),
    );
  }

  @override
  Future<int> saveAudioDraft(String audioPath, String language) {
    if (audioPath.trim().isEmpty) {
      throw ArgumentError.value(audioPath, 'audioPath', 'must not be empty');
    }
    final canonicalLanguage = _requireSupportedLanguage(language);

    return entryDao.insertEntry(
      EntryRecordsCompanion.insert(
        rawTranscript: '',
        isDraft: true,
        language: canonicalLanguage,
        createdAt: clock.now(),
        audioPath: Value(audioPath),
      ),
    );
  }

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {
    final affectedRows = await entryDao.updateEditedCleanedText(
      id,
      cleanedText,
      _countWords(cleanedText),
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {
    final affectedRows = await entryDao.updateWithCleanedText(
      id,
      cleanedText,
      wordCount,
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {
    final affectedRows = await entryDao.updateDraftTranscript(
      id,
      rawTranscript,
      wordCount,
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) async {
    final canonicalLanguage = _requireSupportedLanguage(language);
    final affectedRows = await entryDao.updateDraftTranscriptAndLanguage(
      id,
      rawTranscript,
      wordCount,
      canonicalLanguage,
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {
    final affectedRows = await entryDao.finalizeDraftWithCleanedText(
      id,
      rawTranscript,
      cleanedText,
      wordCount,
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<void> updateEntryLanguage(int id, String language) async {
    final canonicalLanguage = _requireSupportedLanguage(language);
    final affectedRows = await entryDao.updateEntryLanguage(
      id,
      canonicalLanguage,
    );
    _throwIfMissing(id, affectedRows);
  }

  @override
  Future<List<Entry>> getPendingDrafts() async {
    final drafts = await entryDao.getPendingDrafts();
    return drafts.map((draft) => draft.toDomain()).toList(growable: false);
  }

  @override
  Future<void> deleteEntry(int id) async {
    final existing = await entryDao.getEntryById(id);
    if (existing == null) {
      throw StateError('Entry with id $id not found or already deleted');
    }

    await entryDao.deleteEntryById(id);
    await _deleteFileIfPresent(existing.audioPath);
  }

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {
    if (daysOld < 0) {
      throw ArgumentError.value(daysOld, 'daysOld', 'must not be negative');
    }

    final cutoffTimestamp =
        clock.now() - Duration(days: daysOld).inMilliseconds;
    final staleDrafts = await entryDao.getStaleDraftsOlderThan(cutoffTimestamp);
    await entryDao.deleteStaleDraftsOlderThan(cutoffTimestamp);

    for (final draft in staleDrafts) {
      await _deleteFileIfPresent(draft.audioPath);
    }
  }

  void _throwIfMissing(int id, int affectedRows) {
    if (affectedRows == 0) {
      throw StateError('Entry with id $id not found or already deleted');
    }
  }

  String _requireSupportedLanguage(String language) {
    final resolved = resolveSupportedLanguageCode(language);
    if (resolved != null) {
      return resolved;
    }

    throw ArgumentError.value(
      language,
      'language',
      'must resolve to a supported BCP-47 language code',
    );
  }

  int _countWords(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .length;
  }

  Future<void> _deleteFileIfPresent(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) {
      return;
    }

    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup only.
    }
  }
}
