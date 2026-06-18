import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../domain/model/entry.dart';

class EntryDetailDateLabel {
  const EntryDetailDateLabel({required this.weekday, required this.date});

  final String weekday;
  final String date;
}

String entryDetailDisplayText(Entry entry) {
  final cleanedText = entry.cleanedText;
  if (cleanedText != null && cleanedText.trim().isNotEmpty) {
    return cleanedText;
  }

  if (entry.rawTranscript.trim().isNotEmpty) {
    return entry.rawTranscript;
  }

  return '';
}

bool entryDetailIsReadable(Entry? entry) {
  if (entry == null) {
    return false;
  }

  return entryDetailDisplayText(entry).trim().isNotEmpty;
}

EntryDetailDateLabel formatEntryDetailDate({
  required int createdAt,
  required Locale locale,
}) {
  final dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt).toLocal();
  final localeName = locale.toLanguageTag();

  return _tryFormatEntryDetailDate(dateTime, localeName) ??
      _tryFormatEntryDetailDate(dateTime, locale.languageCode) ??
      _tryFormatEntryDetailDate(dateTime, null)!;
}

String formatEntryWordCount(int wordCount) {
  return wordCount == 1 ? '1 word' : '$wordCount words';
}

EntryDetailDateLabel? _tryFormatEntryDetailDate(
  DateTime dateTime,
  String? localeName,
) {
  final formattedLocale = localeName == null || localeName.trim().isEmpty
      ? null
      : localeName;

  try {
    return EntryDetailDateLabel(
      weekday: DateFormat('EEEE', formattedLocale).format(dateTime),
      date: DateFormat.yMMMMd(formattedLocale).format(dateTime),
    );
  } catch (_) {
    return null;
  }
}
