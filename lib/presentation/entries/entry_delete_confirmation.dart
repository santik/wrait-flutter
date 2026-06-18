import 'package:flutter/material.dart';

const entryDeleteDialogTitle = 'Delete entry?';
const entryDeleteDialogBody = 'This entry will be permanently removed.';
const entryDeleteCancelLabel = 'Cancel';
const entryDeleteConfirmLabel = 'Delete';
const entryDeleteCancelSemanticsLabel = 'Cancel deletion';
const entryDeleteCancelSemanticsHint = 'Keeps this entry in the list.';
const entryDeleteConfirmSemanticsLabel = 'Delete entry permanently';
const entryDeleteConfirmSemanticsHint = 'Removes this entry from the list.';

Future<bool> showEntryDeleteConfirmationDialog(BuildContext context) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text(entryDeleteDialogTitle),
        content: const Text(entryDeleteDialogBody),
        actions: [
          Semantics(
            button: true,
            label: entryDeleteCancelSemanticsLabel,
            hint: entryDeleteCancelSemanticsHint,
            child: TextButton(
              key: const ValueKey('entryDeleteCancelButton'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const ExcludeSemantics(
                child: Text(entryDeleteCancelLabel),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: entryDeleteConfirmSemanticsLabel,
            hint: entryDeleteConfirmSemanticsHint,
            child: TextButton(
              key: const ValueKey('entryDeleteConfirmButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const ExcludeSemantics(
                child: Text(entryDeleteConfirmLabel),
              ),
            ),
          ),
        ],
      );
    },
  );

  return shouldDelete ?? false;
}
