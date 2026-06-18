part of 'local_entry_database.dart';

@DriftAccessor(tables: [EntryRecords])
class EntryDao extends DatabaseAccessor<LocalEntryDatabase>
    with _$EntryDaoMixin {
  EntryDao(super.attachedDatabase);

  Stream<List<EntryRecord>> watchAllEntries() {
    return (select(
      entryRecords,
    )..orderBy([(table) => OrderingTerm.desc(table.createdAt)])).watch();
  }

  Stream<EntryRecord?> watchEntryById(int id) {
    return (select(
      entryRecords,
    )..where((table) => table.id.equals(id))).watchSingleOrNull();
  }

  Future<EntryRecord?> getEntryById(int id) {
    return (select(
      entryRecords,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<List<EntryRecord>> getPendingDrafts() {
    return (select(entryRecords)
          ..where((table) => table.isDraft.equals(true))
          ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
        .get();
  }

  Future<List<EntryRecord>> getStaleDraftsOlderThan(int cutoffTimestamp) {
    return (select(entryRecords)..where(
          (table) =>
              table.isDraft.equals(true) &
              table.createdAt.isSmallerThanValue(cutoffTimestamp),
        ))
        .get();
  }

  Future<int> insertEntry(EntryRecordsCompanion entry) {
    return into(entryRecords).insert(entry);
  }

  Future<int> updateEditedCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(
        cleanedText: Value(cleanedText),
        wordCount: Value(wordCount),
      ),
    );
  }

  Future<int> updateWithCleanedText(int id, String cleanedText, int wordCount) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(
        cleanedText: Value(cleanedText),
        wordCount: Value(wordCount),
        isDraft: const Value(false),
        audioPath: const Value(null),
      ),
    );
  }

  Future<int> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(
        rawTranscript: Value(rawTranscript),
        wordCount: Value(wordCount),
        audioPath: const Value(null),
      ),
    );
  }

  Future<int> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(
        rawTranscript: Value(rawTranscript),
        wordCount: Value(wordCount),
        language: Value(language),
        audioPath: const Value(null),
      ),
    );
  }

  Future<int> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(
        rawTranscript: Value(rawTranscript),
        cleanedText: Value(cleanedText),
        wordCount: Value(wordCount),
        isDraft: const Value(false),
        audioPath: const Value(null),
      ),
    );
  }

  Future<int> updateEntryLanguage(int id, String language) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(language: Value(language)),
    );
  }

  Future<int> deleteEntryById(int id) {
    return (delete(entryRecords)..where((table) => table.id.equals(id))).go();
  }

  Future<int> deleteStaleDraftsOlderThan(int cutoffTimestamp) {
    return (delete(entryRecords)..where(
          (table) =>
              table.isDraft.equals(true) &
              table.createdAt.isSmallerThanValue(cutoffTimestamp),
        ))
        .go();
  }
}
