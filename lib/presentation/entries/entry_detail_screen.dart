import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/design_tokens.dart';
import 'entry_delete_confirmation.dart';
import 'entry_detail_controller.dart';
import 'entry_detail_formatters.dart';

class EntryDetailScreen extends ConsumerStatefulWidget {
  const EntryDetailScreen({required this.entryId, super.key});

  final int entryId;

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleEditorChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_handleEditorChanged);
    _textController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(entryDetailEntryProvider(widget.entryId));
    final detailState = ref.watch(
      entryDetailControllerProvider(widget.entryId),
    );
    final detailController = ref.read(
      entryDetailControllerProvider(widget.entryId).notifier,
    );

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_handleBackNavigation(detailController));
      },
      child: Scaffold(
        body: SafeArea(
          child: entryAsync.when(
            loading: _buildLoadingState,
            error: (error, stackTrace) => _buildErrorState(),
            data: (entry) {
              if (!entryDetailIsReadable(entry)) {
                _scheduleRedirectToEntries();
                return _buildLoadingState();
              }

              final displayText = entryDetailDisplayText(entry!);
              _scheduleSyncFromEntry(
                detailController,
                displayText,
                detailState,
              );
              _syncTextController(detailState.draftText, detailState.isEditing);

              final dateLabel = formatEntryDetailDate(
                createdAt: entry.createdAt,
                locale: Localizations.localeOf(context),
              );
              final saveMessage = detailState.isSaving
                  ? 'Saving changes...'
                  : detailState.saveFailed
                  ? 'Could not save your changes.'
                  : null;

              return Padding(
                padding: WraitDesignTokens.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EntryDetailHeader(
                      isEditing: detailState.isEditing,
                      onBackPressed: () async {
                        await _handleBackNavigation(detailController);
                      },
                      onEditPressed: () async {
                        await _handleEditToggle(
                          detailController,
                          detailState,
                          displayText,
                        );
                      },
                      onSharePressed: () async {
                        await _handleShare(
                          detailController,
                          detailState,
                          displayText,
                        );
                      },
                      onDeletePressed: () async {
                        await _handleDelete(detailController);
                      },
                    ),
                    const SizedBox(height: WraitSpacingTokens.lg),
                    Text(
                      dateLabel.weekday,
                      key: const ValueKey('entryDetailWeekday'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: WraitSpacingTokens.xs),
                    Text(
                      dateLabel.date,
                      key: const ValueKey('entryDetailDate'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: WraitSpacingTokens.md),
                    Text(
                      formatEntryWordCount(entry.wordCount),
                      key: const ValueKey('entryDetailWordCount'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (saveMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: WraitSpacingTokens.sm,
                        ),
                        child: Text(
                          saveMessage,
                          key: const ValueKey('entryDetailSaveMessage'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: detailState.saveFailed
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                      ),
                    const SizedBox(height: WraitSpacingTokens.lg),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const ValueKey('entryDetailScrollView'),
                        child: detailState.isEditing
                            ? Semantics(
                                label: 'Edit entry text',
                                textField: true,
                                child: TextField(
                                  key: const ValueKey('entryDetailEditor'),
                                  controller: _textController,
                                  focusNode: _editorFocusNode,
                                  maxLines: null,
                                  minLines: 12,
                                  textInputAction: TextInputAction.newline,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Edit your entry',
                                  ),
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              )
                            : SelectableText(
                                displayText,
                                key: const ValueKey('entryDetailReadText'),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator.adaptive(
        key: ValueKey('entryDetailLoading'),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: WraitDesignTokens.screenPadding,
        child: Text(
          'Could not load this entry.',
          key: const ValueKey('entryDetailError'),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _handleEditorChanged() {
    final detailState = ref.read(entryDetailControllerProvider(widget.entryId));
    if (!detailState.isEditing) {
      return;
    }

    ref
        .read(entryDetailControllerProvider(widget.entryId).notifier)
        .updateDraftText(_textController.text);
  }

  void _syncTextController(String text, bool isEditing) {
    if (!isEditing) {
      return;
    }

    if (_textController.text == text) {
      return;
    }

    final selectionOffset = math.min(
      text.length,
      _textController.selection.baseOffset,
    );
    final safeSelectionOffset = selectionOffset.isNegative
        ? text.length
        : selectionOffset;
    _withSuspendedEditorListener(() {
      _textController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: safeSelectionOffset),
      );
    });
  }

  void _withSuspendedEditorListener(VoidCallback updateController) {
    _textController.removeListener(_handleEditorChanged);
    try {
      updateController();
    } finally {
      _textController.addListener(_handleEditorChanged);
    }
  }

  void _scheduleRedirectToEntries() {
    if (_redirectScheduled) {
      return;
    }

    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.go('/entries');
    });
  }

  void _scheduleSyncFromEntry(
    EntryDetailController detailController,
    String displayText,
    EntryDetailControllerState detailState,
  ) {
    if (detailState.isEditing || detailState.isSaving) {
      return;
    }
    if (detailState.draftText == displayText && !_redirectScheduled) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      detailController.syncFromEntry(displayText);
    });
  }

  Future<void> _handleEditToggle(
    EntryDetailController detailController,
    EntryDetailControllerState detailState,
    String displayText,
  ) async {
    if (!detailState.isEditing) {
      detailController.startEditing(displayText);
      _syncTextController(
        ref.read(entryDetailControllerProvider(widget.entryId)).draftText,
        true,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _editorFocusNode.requestFocus();
        }
      });
      return;
    }

    final didFinish = await detailController.finishEditing();
    if (!mounted) {
      return;
    }
    if (!didFinish) {
      _showMessage('Could not save your changes.');
      return;
    }
    _editorFocusNode.unfocus();
  }

  Future<void> _handleShare(
    EntryDetailController detailController,
    EntryDetailControllerState detailState,
    String displayText,
  ) async {
    final textToShare = detailState.isEditing
        ? detailState.draftText
        : displayText;
    final didShare = await detailController.shareDisplayedText(textToShare);
    if (!mounted || didShare) {
      return;
    }

    _showMessage('Could not share this entry.');
  }

  Future<void> _handleDelete(EntryDetailController detailController) async {
    final shouldDelete = await showEntryDeleteConfirmationDialog(context);
    if (!mounted || !shouldDelete) {
      return;
    }

    final didDelete = await detailController.deleteEntry();
    if (!mounted) {
      return;
    }
    if (!didDelete) {
      return;
    }

    context.go('/entries');
  }

  Future<bool> _handleBackNavigation(
    EntryDetailController detailController,
  ) async {
    final didFlush = await detailController.flushPendingEdits();
    if (!mounted) {
      return false;
    }
    if (!didFlush) {
      _showMessage('Could not save your changes.');
      return false;
    }

    _editorFocusNode.unfocus();
    context.go('/entries');
    return false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EntryDetailHeader extends StatelessWidget {
  const _EntryDetailHeader({
    required this.isEditing,
    required this.onBackPressed,
    required this.onEditPressed,
    required this.onSharePressed,
    required this.onDeletePressed,
  });

  final bool isEditing;
  final Future<void> Function() onBackPressed;
  final Future<void> Function() onEditPressed;
  final Future<void> Function() onSharePressed;
  final Future<void> Function() onDeletePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Back to entries',
          child: IconButton(
            key: const ValueKey('entryDetailBackButton'),
            onPressed: () {
              unawaited(onBackPressed());
            },
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
        ),
        const Spacer(),
        Semantics(
          button: true,
          label: isEditing ? 'Finish editing' : 'Edit entry',
          child: IconButton(
            key: ValueKey(
              isEditing ? 'entryDetailDoneButton' : 'entryDetailEditButton',
            ),
            onPressed: () {
              unawaited(onEditPressed());
            },
            icon: Icon(isEditing ? Icons.check_rounded : Icons.edit_outlined),
            tooltip: isEditing ? 'Done' : 'Edit',
          ),
        ),
        Semantics(
          button: true,
          label: 'Share entry',
          child: IconButton(
            key: const ValueKey('entryDetailShareButton'),
            onPressed: () {
              unawaited(onSharePressed());
            },
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Share',
          ),
        ),
        Semantics(
          button: true,
          label: 'Delete entry',
          child: IconButton(
            key: const ValueKey('entryDetailDeleteButton'),
            onPressed: () {
              unawaited(onDeletePressed());
            },
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
          ),
        ),
      ],
    );
  }
}
