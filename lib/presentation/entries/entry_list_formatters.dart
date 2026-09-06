import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../domain/model/entry.dart';
import '../../domain/model/supported_language.dart';

const entryListAudioDraftPreview = 'pending · will retry';
const entryListAudioDraftStateDescription = 'Audio draft, not yet transcribed';
const entryListDeleteActionLabel = 'Delete entry';

class EntryListTimestampLabel {
  const EntryListTimestampLabel({
    required this.shortWeekday,
    required this.date,
    required this.time,
  });

  final String shortWeekday;
  final String date;
  final String time;

  String get displayLabel => '$shortWeekday, $date · $time';
}

EntryListTimestampLabel formatEntryListTimestamp({
  required int createdAt,
  required Locale locale,
}) {
  final dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt).toLocal();
  final localeName = locale.toLanguageTag();

  return _tryFormatEntryListTimestamp(dateTime, localeName) ??
      _tryFormatEntryListTimestamp(dateTime, locale.languageCode) ??
      _tryFormatEntryListTimestamp(dateTime, null)!;
}

String entryListPreviewText(Entry entry) {
  final preferredText = entry.cleanedText;
  if (preferredText != null && preferredText.trim().isNotEmpty) {
    return _firstNonBlankLine(preferredText);
  }

  if (entry.rawTranscript.trim().isNotEmpty) {
    return _firstNonBlankLine(entry.rawTranscript);
  }

  if (entryListIsAudioOnlyDraft(entry)) {
    return entryListAudioDraftPreview;
  }

  return '';
}

String entryListLanguageLabel(String languageCode) {
  return supportedLanguageDisplayName(languageCode) ?? languageCode;
}

bool entryListIsAudioOnlyDraft(Entry entry) {
  final audioPath = entry.audioPath;
  return entry.type == EntryType.draft &&
      audioPath != null &&
      audioPath.isNotEmpty &&
      (entry.cleanedText == null || entry.cleanedText!.trim().isEmpty) &&
      entry.rawTranscript.trim().isEmpty;
}

String _firstNonBlankLine(String text) {
  final normalizedText = text.replaceAll('\r\n', '\n');
  for (final line in normalizedText.split('\n')) {
    if (line.trim().isNotEmpty) {
      return line;
    }
  }

  return '';
}

EntryListTimestampLabel? _tryFormatEntryListTimestamp(
  DateTime dateTime,
  String? localeName,
) {
  final formattedLocale = localeName == null || localeName.trim().isEmpty
      ? null
      : localeName;

  try {
    return EntryListTimestampLabel(
      shortWeekday: DateFormat('EEE', formattedLocale).format(dateTime),
      date: DateFormat.yMd(formattedLocale).format(dateTime),
      time: DateFormat.jm(formattedLocale).format(dateTime),
    );
  } catch (_) {
    return null;
  }
}
