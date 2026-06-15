import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/design_tokens.dart';
import 'entry_list_controller.dart';
import 'entry_list_row.dart';

class EntryListScreen extends ConsumerWidget {
  const EntryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entryListEntriesProvider).value ?? const [];
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: WraitDesignTokens.screenPadding,
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        'no entries yet',
                        key: const ValueKey('entryListEmptyState'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      key: const ValueKey('entryListView'),
                      padding: const EdgeInsets.only(
                        top: WraitSpacingTokens.xxl + WraitSpacingTokens.md,
                      ),
                      itemCount: entries.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: WraitSpacingTokens.sm),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return EntryListRow(
                          key: ValueKey('entryRow-${entry.id}'),
                          entry: entry,
                          onTap: (entryId) => context.go('/entry/$entryId'),
                          onDeleteRequested: (entryId) =>
                              _confirmDelete(context, ref, entryId),
                        );
                      },
                    ),
            ),
            Positioned(
              top: WraitSpacingTokens.sm,
              left: WraitSpacingTokens.sm,
              child: Semantics(
                button: true,
                label: 'Back to main screen',
                child: IconButton(
                  key: const ValueKey('entryListBackButton'),
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int entryId,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete entry?'),
          content: const Text('This entry will be permanently removed.'),
          actions: [
            Semantics(
              button: true,
              label: 'Cancel deletion',
              hint: 'Keeps this entry in the list.',
              child: TextButton(
                key: const ValueKey('entryDeleteCancelButton'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const ExcludeSemantics(child: Text('Cancel')),
              ),
            ),
            Semantics(
              button: true,
              label: 'Delete entry permanently',
              hint: 'Removes this entry from the list.',
              child: TextButton(
                key: const ValueKey('entryDeleteConfirmButton'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const ExcludeSemantics(child: Text('Delete')),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await ref.read(entryListControllerProvider).deleteEntry(entryId);
  }
}
