import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/design_tokens.dart';
import 'entry_delete_confirmation.dart';
import 'entry_list_controller.dart';
import 'entry_list_row.dart';
import '../../domain/model/entry.dart';

class EntryListScreen extends ConsumerWidget {
  const EntryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entryListEntriesProvider).value ?? const [];
    final controllerState = ref.watch(entryListControllerProvider);
    final theme = Theme.of(context);
    final canPopRoute = Navigator.of(context).canPop();

    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _navigateBack(context);
      },
      child: Scaffold(
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
                    onPressed: () => _navigateBack(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
                ),
              ),
              Positioned(
                top: WraitSpacingTokens.sm,
                right: WraitSpacingTokens.sm,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: !controllerState.isImporting,
                      enabled: !controllerState.isImporting,
                      label: controllerState.isImporting
                          ? 'Importing entries'
                          : 'Import entries',
                      liveRegion: controllerState.isImporting,
                      child: IconButton(
                        key: const ValueKey('entryListImportButton'),
                        onPressed: controllerState.isImporting
                            ? null
                            : () => _importEntries(context, ref),
                        icon: controllerState.isImporting
                            ? Semantics(
                                label: 'Importing entries',
                                child: const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : const Icon(Icons.file_upload_outlined),
                        tooltip: controllerState.isImporting
                            ? 'Importing CSV'
                            : 'Import CSV',
                      ),
                    ),
                    Semantics(
                      button: !controllerState.isExporting,
                      enabled: !controllerState.isExporting,
                      label: controllerState.isExporting
                          ? 'Exporting entries'
                          : 'Export entries',
                      liveRegion: controllerState.isExporting,
                      child: IconButton(
                        key: const ValueKey('entryListExportButton'),
                        onPressed: controllerState.isExporting
                            ? null
                            : () => _exportEntries(context, ref, entries),
                        icon: controllerState.isExporting
                            ? Semantics(
                                label: 'Exporting entries',
                                child: const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : const Icon(Icons.file_download_outlined),
                        tooltip: controllerState.isExporting
                            ? 'Exporting CSV'
                            : 'Export CSV',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    context.go('/');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int entryId,
  ) async {
    final shouldDelete = await showEntryDeleteConfirmationDialog(context);
    if (!shouldDelete) {
      return;
    }

    await ref.read(entryListControllerProvider.notifier).deleteEntry(entryId);
  }

  Future<void> _exportEntries(
    BuildContext context,
    WidgetRef ref,
    List<Entry> entries,
  ) async {
    final result = await ref
        .read(entryListControllerProvider.notifier)
        .exportEntries(entries);
    if (!context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (result.didExport) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Exported ${result.fileName} to ${result.pathLabel}.'),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Could not export entries.')),
    );
  }

  Future<void> _importEntries(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(entryListControllerProvider.notifier)
        .importEntries();
    if (!context.mounted || result.wasCancelled) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (result.didImport) {
      final recordLabel = result.importedCount == 1 ? 'record' : 'records';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.importedCount} $recordLabel from ${result.fileName}.',
          ),
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(result.failureMessage ?? 'Could not import entries.'),
      ),
    );
  }
}
