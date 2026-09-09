import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entries/entry_export_providers.dart';
import '../../data/entries/entry_import_providers.dart';
import '../../data/entries/entry_providers.dart';
import '../../domain/model/entry.dart';
import '../../domain/service/entry_export_service.dart';
import '../../domain/service/entry_import_service.dart';
import 'entry_deletion_controller.dart';

final entryListEntriesProvider = StreamProvider<List<Entry>>((ref) {
  return ref
      .watch(entryRepositoryProvider)
      .watchAllEntries()
      .map(EntryListController.sortEntriesNewestFirst);
});

final entryListSearchQueryProvider =
    NotifierProvider.autoDispose<EntryListSearchQuery, String>(
      EntryListSearchQuery.new,
    );

final entryListFilteredEntriesProvider = Provider.autoDispose<List<Entry>>((
  ref,
) {
  final entries = ref.watch(entryListEntriesProvider).value ?? const [];
  final query = ref.watch(entryListSearchQueryProvider);
  return EntryListController.filterEntries(entries, query);
});

class EntryListSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

typedef EntryListWarningLogger =
    void Function(String message, {Object? error, StackTrace? stackTrace});

final entryListWarningLoggerProvider = Provider<EntryListWarningLogger>((ref) {
  return (message, {error, stackTrace}) {
    developer.log(
      message,
      name: 'EntryListController',
      error: error,
      stackTrace: stackTrace,
    );
  };
});

final entryListControllerProvider =
    NotifierProvider<EntryListController, EntryListControllerState>(
      EntryListController.new,
    );

class EntryListControllerState {
  const EntryListControllerState({
    this.isExporting = false,
    this.isImporting = false,
  });

  final bool isExporting;
  final bool isImporting;

  EntryListControllerState copyWith({bool? isExporting, bool? isImporting}) {
    return EntryListControllerState(
      isExporting: isExporting ?? this.isExporting,
      isImporting: isImporting ?? this.isImporting,
    );
  }
}

class EntryListController extends Notifier<EntryListControllerState> {
  @override
  EntryListControllerState build() {
    return const EntryListControllerState();
  }

  EntryDeletionController get _entryDeletionController =>
      ref.read(entryDeletionControllerProvider);
  EntryExportService get _entryExportService =>
      ref.read(entryExportServiceProvider);
  EntryImportService get _entryImportService =>
      ref.read(entryImportServiceProvider);
  EntryListWarningLogger get _logWarning =>
      ref.read(entryListWarningLoggerProvider);

  Future<void> deleteEntry(int id) async {
    await _entryDeletionController.deleteEntry(
      id,
      failureContext: 'Failed to delete entry from the entry list.',
    );
  }

  Future<EntryExportResult> exportEntries(List<Entry> entries) async {
    if (state.isExporting) {
      return const EntryExportResult.failure();
    }

    state = state.copyWith(isExporting: true);
    try {
      final result = await _entryExportService.exportEntries(entries);
      if (!result.didExport) {
        _logWarning(
          'Failed to export entries from the entry list.',
          error: result.error,
          stackTrace: result.stackTrace,
        );
      }
      return result;
    } finally {
      state = state.copyWith(isExporting: false);
    }
  }

  Future<EntryImportResult> importEntries() async {
    if (state.isImporting) {
      return const EntryImportResult.cancelled();
    }

    state = state.copyWith(isImporting: true);
    try {
      final result = await _entryImportService.importEntries();
      if (!result.didImport && !result.wasCancelled) {
        _logWarning(
          'Failed to import entries from the entry list.',
          error: result.error,
          stackTrace: result.stackTrace,
        );
      }
      return result;
    } finally {
      state = state.copyWith(isImporting: false);
    }
  }

  static List<Entry> sortEntriesNewestFirst(List<Entry> entries) {
    final sortedEntries = entries.toList();
    sortedEntries.sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );
    return sortedEntries;
  }

  static List<Entry> filterEntries(List<Entry> entries, String query) {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .map((term) => term.toLowerCase())
        .toList(growable: false);
    if (terms.isEmpty) {
      return entries;
    }

    return entries
        .where((entry) {
          final cleanedText = entry.cleanedText?.toLowerCase() ?? '';
          final rawTranscript = entry.rawTranscript.toLowerCase();
          return terms.every(
            (term) =>
                cleanedText.contains(term) || rawTranscript.contains(term),
          );
        })
        .toList(growable: false);
  }
}
