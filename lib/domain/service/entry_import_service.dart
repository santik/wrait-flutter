import 'dart:convert';

import '../../data/entries/entry_import_file_reader.dart';
import '../model/entry.dart';
import '../model/supported_language.dart';
import '../repository/entry_repository.dart';
import 'entry_export_service.dart';

enum EntryImportFailureCategory {
  invalidFormat,
  unreadableFile,
  fileTooLarge,
  storageFailure,
}

class EntryImportTooLargeException implements Exception {
  const EntryImportTooLargeException(this.message);

  final String message;

  @override
  String toString() => 'EntryImportTooLargeException: $message';
}

class EntryImportResult {
  const EntryImportResult.success({
    required this.fileName,
    required this.importedCount,
  }) : didImport = true,
       wasCancelled = false,
       failureCategory = null,
       error = null,
       stackTrace = null;

  const EntryImportResult.cancelled()
    : didImport = false,
      wasCancelled = true,
      fileName = null,
      importedCount = 0,
      failureCategory = null,
      error = null,
      stackTrace = null;

  const EntryImportResult.failure({
    required this.failureCategory,
    this.error,
    this.stackTrace,
  }) : didImport = false,
       wasCancelled = false,
       fileName = null,
       importedCount = 0;

  final bool didImport;
  final bool wasCancelled;
  final String? fileName;
  final int importedCount;
  final EntryImportFailureCategory? failureCategory;
  final Object? error;
  final StackTrace? stackTrace;

  String? get failureMessage {
    return switch (failureCategory) {
      EntryImportFailureCategory.invalidFormat =>
        'Selected CSV is not a valid Wrait export.',
      EntryImportFailureCategory.unreadableFile =>
        'Could not read the selected CSV file.',
      EntryImportFailureCategory.fileTooLarge =>
        'Selected CSV is too large to import.',
      EntryImportFailureCategory.storageFailure =>
        'Could not save imported entries.',
      null => null,
    };
  }
}

class EntryImportService {
  EntryImportService({
    required this.fileReader,
    required this.entryRepository,
    this.maxImportBytes = defaultMaxImportBytes,
    this.maxTextFieldBytes = defaultMaxTextFieldBytes,
    this.maxSmallFieldBytes = defaultMaxSmallFieldBytes,
  });

  static const int defaultMaxImportBytes = 10 * 1024 * 1024;
  static const int defaultMaxTextFieldBytes = 1024 * 1024;
  static const int defaultMaxSmallFieldBytes = 128;
  static const int maxCreatedAtEpochMs = 4102444800000; // 2100-01-01T00:00:00Z

  final EntryImportFileReader fileReader;
  final EntryRepository entryRepository;
  final int maxImportBytes;
  final int maxTextFieldBytes;
  final int maxSmallFieldBytes;

  Future<EntryImportResult> importEntries() async {
    try {
      final file = await fileReader.pickCsvImport();
      if (file == null) {
        return const EntryImportResult.cancelled();
      }

      final entries = parseCsv(
        file.contents,
        maxImportBytes: maxImportBytes,
        maxTextFieldBytes: maxTextFieldBytes,
        maxSmallFieldBytes: maxSmallFieldBytes,
      );
      await entryRepository.importEntries(entries);
      return EntryImportResult.success(
        fileName: file.fileName,
        importedCount: entries.length,
      );
    } catch (error, stackTrace) {
      return EntryImportResult.failure(
        failureCategory: _categorizeFailure(error),
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static List<Entry> parseCsv(
    String contents, {
    int maxImportBytes = defaultMaxImportBytes,
    int maxTextFieldBytes = defaultMaxTextFieldBytes,
    int maxSmallFieldBytes = defaultMaxSmallFieldBytes,
  }) {
    if (contents.isEmpty) {
      throw const FormatException('Entry import requires non-empty CSV data.');
    }
    _validateImportSize(contents, maxImportBytes);

    final rows = _parseRows(contents);
    if (rows.isEmpty) {
      throw const FormatException('Entry import CSV contains no rows.');
    }

    final header = List<String>.from(rows.first, growable: false);
    if (header.isNotEmpty) {
      header[0] = _stripUtf8Bom(header.first);
    }
    if (!_listEquals(header, EntryExportService.csvHeaders)) {
      throw FormatException(
        'Entry import CSV header does not match the Wrait export format.',
      );
    }

    final importedEntries = <Entry>[];
    for (final row in rows.skip(1)) {
      if (_isBlankRow(row)) {
        continue;
      }
      if (row.length != EntryExportService.csvHeaders.length) {
        throw FormatException(
          'Entry import CSV row has ${row.length} columns; '
          'expected ${EntryExportService.csvHeaders.length}.',
        );
      }

      _validateRowFieldSizes(
        row,
        maxTextFieldBytes: maxTextFieldBytes,
        maxSmallFieldBytes: maxSmallFieldBytes,
      );
      importedEntries.add(_parseEntryRow(row));
    }

    return importedEntries;
  }

  static EntryImportFailureCategory _categorizeFailure(Object error) {
    if (error is EntryImportTooLargeException) {
      return EntryImportFailureCategory.fileTooLarge;
    }
    if (error is FormatException) {
      return EntryImportFailureCategory.invalidFormat;
    }
    if (error is EntryImportFileReaderException) {
      if (error.code ==
          MethodChannelEntryImportFileReader.fileTooLargeErrorCode) {
        return EntryImportFailureCategory.fileTooLarge;
      }
      return EntryImportFailureCategory.unreadableFile;
    }
    return EntryImportFailureCategory.storageFailure;
  }

  static Entry _parseEntryRow(List<String> row) {
    final entryType = EntryType.tryParse(row[0]);
    if (entryType == null) {
      throw FormatException(
        'Entry import CSV contains an unsupported type: ${row[0]}.',
      );
    }

    final createdAtValue = row[1];
    if (createdAtValue.isEmpty) {
      throw const FormatException(
        'Entry import CSV created_at cannot be empty.',
      );
    }
    final createdAt = int.tryParse(createdAtValue);
    if (createdAt == null) {
      throw const FormatException(
        'Entry import CSV created_at must be an integer.',
      );
    }
    if (createdAt < 0) {
      throw const FormatException(
        'Entry import CSV created_at cannot be negative.',
      );
    }
    if (createdAt > maxCreatedAtEpochMs) {
      throw const FormatException(
        'Entry import CSV created_at exceeds the maximum supported timestamp.',
      );
    }

    final resolvedLanguage = resolveSupportedLanguageCode(row[2]);
    if (resolvedLanguage == null) {
      throw FormatException(
        'Entry import CSV contains an unsupported language: ${row[2]}.',
      );
    }

    final wordCount = int.tryParse(row[3]);
    if (wordCount == null || wordCount < 0) {
      throw const FormatException(
        'Entry import CSV contains an invalid word_count value.',
      );
    }

    final cleanedText = row[5].isEmpty ? null : row[5];

    return Entry(
      rawTranscript: row[4],
      cleanedText: cleanedText,
      type: entryType,
      language: resolvedLanguage,
      createdAt: createdAt,
      wordCount: wordCount,
    );
  }

  static List<List<String>> _parseRows(String contents) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentField = StringBuffer();
    var isInsideQuotes = false;

    void commitField() {
      currentRow.add(currentField.toString());
      currentField.clear();
    }

    void commitRow() {
      commitField();
      rows.add(List<String>.from(currentRow, growable: false));
      currentRow.clear();
    }

    for (var i = 0; i < contents.length; i += 1) {
      final char = contents[i];
      if (isInsideQuotes) {
        if (char == '"') {
          if (i + 1 < contents.length && contents[i + 1] == '"') {
            currentField.write('"');
            i += 1;
          } else {
            isInsideQuotes = false;
          }
        } else {
          currentField.write(char);
        }
        continue;
      }

      if (char == '"') {
        isInsideQuotes = true;
      } else if (char == ',') {
        commitField();
      } else if (char == '\n') {
        commitRow();
      } else if (char == '\r') {
        if (i + 1 < contents.length && contents[i + 1] == '\n') {
          i += 1;
        }
        commitRow();
      } else {
        currentField.write(char);
      }
    }

    if (isInsideQuotes) {
      throw const FormatException(
        'Entry import CSV has an unterminated quote.',
      );
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      commitRow();
    }

    return rows;
  }

  static void _validateImportSize(String contents, int maxImportBytes) {
    final importBytes = utf8.encode(contents).length;
    if (importBytes > maxImportBytes) {
      throw EntryImportTooLargeException(
        'Entry import CSV exceeds the $maxImportBytes-byte limit.',
      );
    }
  }

  static void _validateRowFieldSizes(
    List<String> row, {
    required int maxTextFieldBytes,
    required int maxSmallFieldBytes,
  }) {
    for (var i = 0; i < row.length; i += 1) {
      final field = row[i];
      final header = EntryExportService.csvHeaders[i];
      final maxFieldBytes = switch (header) {
        'raw_transcript' || 'cleaned_text' => maxTextFieldBytes,
        _ => maxSmallFieldBytes,
      };

      if (utf8.encode(field).length > maxFieldBytes) {
        throw EntryImportTooLargeException(
          'Entry import CSV field "$header" exceeds the '
          '$maxFieldBytes-byte limit.',
        );
      }
    }
  }

  static bool _isBlankRow(List<String> row) {
    return row.every((field) => field.isEmpty);
  }

  static String _stripUtf8Bom(String value) {
    if (value.startsWith('\ufeff')) {
      return value.substring(1);
    }
    return value;
  }

  static bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i += 1) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }
}
