import '../../domain/model/entry.dart';
import 'local_entry_database.dart';

extension EntryRecordMapper on EntryRecord {
  Entry toDomain() {
    return Entry(
      id: id,
      rawTranscript: rawTranscript,
      cleanedText: cleanedText,
      isDraft: isDraft,
      language: language,
      createdAt: createdAt,
      wordCount: wordCount,
      audioPath: audioPath,
    );
  }
}
