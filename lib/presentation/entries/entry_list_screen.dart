import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/design_tokens.dart';
import 'entry_delete_confirmation.dart';
import 'entry_list_controller.dart';
import 'entry_list_row.dart';
import '../../domain/model/entry.dart';

class EntryListScreen extends ConsumerStatefulWidget {
  const EntryListScreen({super.key});

  @override
  ConsumerState<EntryListScreen> createState() => _EntryListScreenState();
}

class _EntryListScreenState extends ConsumerState<EntryListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = ref.watch(entryListEntriesProvider).value ?? const [];
    final filteredEntries = ref.watch(entryListFilteredEntriesProvider);
    final searchQuery = ref.watch(entryListSearchQueryProvider);
    final controllerState = ref.watch(entryListControllerProvider);
    final theme = Theme.of(context);
    final canPopRoute = Navigator.of(context).canPop();
    final hasActiveQuery = searchQuery.trim().isNotEmpty;

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
          child: Padding(
            padding: WraitDesignTokens.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Back to main screen',
                      child: IconButton(
                        key: const ValueKey('entryListBackButton'),
                        onPressed: () => _navigateBack(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Back',
                      ),
                    ),
                    const Spacer(),
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
                            : () => _importEntries(context),
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
                            : () => _exportEntries(context, allEntries),
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
                const SizedBox(height: WraitSpacingTokens.md),
                TextField(
                  key: const ValueKey('entryListSearchField'),
                  controller: _searchController,
                  autofocus: false,
                  onChanged: (query) {
                    ref
                        .read(entryListSearchQueryProvider.notifier)
                        .update(query);
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search entries',
                    hintText: 'Search entries',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchQuery.isEmpty
                        ? null
                        : Semantics(
                            button: true,
                            label: 'Clear search',
                            child: IconButton(
                              key: const ValueKey('entryListClearSearchButton'),
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Clear search',
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: WraitSpacingTokens.md),
                Expanded(
                  child: _buildEntriesContent(
                    context,
                    theme: theme,
                    allEntries: allEntries,
                    filteredEntries: filteredEntries,
                    hasActiveQuery: hasActiveQuery,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntriesContent(
    BuildContext context, {
    required ThemeData theme,
    required List<Entry> allEntries,
    required List<Entry> filteredEntries,
    required bool hasActiveQuery,
  }) {
    if (allEntries.isEmpty) {
      return Center(
        child: Text(
          'no entries yet',
          key: const ValueKey('entryListEmptyState'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.secondary,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (hasActiveQuery && filteredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No matching entries',
              key: const ValueKey('entryListNoSearchResults'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: WraitSpacingTokens.sm),
            TextButton(
              key: const ValueKey('entryListNoResultsClearButton'),
              onPressed: _clearSearch,
              child: const Text('Clear search'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey('entryListView'),
      padding: const EdgeInsets.only(bottom: WraitSpacingTokens.md),
      itemCount: filteredEntries.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: WraitSpacingTokens.sm),
      itemBuilder: (context, index) {
        final entry = filteredEntries[index];
        return EntryListRow(
          key: ValueKey('entryRow-${entry.id}'),
          entry: entry,
          onTap: (entryId) => context.go('/entry/$entryId'),
          onDeleteRequested: (entryId) => _confirmDelete(context, entryId),
        );
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(entryListSearchQueryProvider.notifier).clear();
  }

  void _navigateBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    context.go('/');
  }

  Future<void> _confirmDelete(BuildContext context, int entryId) async {
    final shouldDelete = await showEntryDeleteConfirmationDialog(context);
    if (!shouldDelete) {
      return;
    }

    await ref.read(entryListControllerProvider.notifier).deleteEntry(entryId);
  }

  Future<void> _exportEntries(BuildContext context, List<Entry> entries) async {
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

  Future<void> _importEntries(BuildContext context) async {
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
