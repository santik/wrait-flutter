import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entries/entry_providers.dart';
import '../../domain/model/entry.dart';
import 'entry_deletion_controller.dart';

final entryListEntriesProvider = StreamProvider<List<Entry>>((ref) {
  return ref
      .watch(entryRepositoryProvider)
      .watchAllEntries()
      .map(EntryListController.sortEntriesNewestFirst);
});

final entryListControllerProvider = Provider<EntryListController>((ref) {
  return EntryListController(ref.read(entryDeletionControllerProvider));
});

class EntryListController {
  const EntryListController(this._entryDeletionController);

  final EntryDeletionController _entryDeletionController;

  Future<void> deleteEntry(int id) async {
    await _entryDeletionController.deleteEntry(
      id,
      failureContext: 'Failed to delete entry from the entry list.',
    );
  }

  static List<Entry> sortEntriesNewestFirst(List<Entry> entries) {
    final sortedEntries = entries.toList();
    sortedEntries.sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );
    return sortedEntries;
  }
}
