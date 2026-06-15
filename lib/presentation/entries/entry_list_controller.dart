import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entries/entry_providers.dart';
import '../../domain/model/entry.dart';
import '../../domain/repository/entry_repository.dart';

final entryListEntriesProvider = StreamProvider<List<Entry>>((ref) {
  return ref
      .watch(entryRepositoryProvider)
      .watchAllEntries()
      .map(EntryListController.sortEntriesNewestFirst);
});

final entryListControllerProvider = Provider<EntryListController>((ref) {
  return EntryListController(ref.read(entryRepositoryProvider));
});

class EntryListController {
  const EntryListController(this._entryRepository);

  final EntryRepository _entryRepository;

  Future<void> deleteEntry(int id) async {
    try {
      await _entryRepository.deleteEntry(id);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to delete entry from the entry list.',
        name: 'EntryListController',
        error: error,
        stackTrace: stackTrace,
        sequenceNumber: id,
      );
      // Keep the current list visible when deletion fails.
    }
  }

  static List<Entry> sortEntriesNewestFirst(List<Entry> entries) {
    final sortedEntries = entries.toList();
    sortedEntries.sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );
    return sortedEntries;
  }
}
