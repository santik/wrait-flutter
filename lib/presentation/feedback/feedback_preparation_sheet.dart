import 'package:flutter/material.dart';

import '../../presentation/theme/design_tokens.dart';
import 'feedback_model.dart';

const feedbackPrivacyCopy =
    'Do not include private journal content unless you choose to type it into your message.';
const feedbackContactFieldKey = ValueKey<String>('feedbackContactField');
const feedbackPrivacyCopyKey = ValueKey<String>('feedbackPrivacyCopy');
const feedbackContinueButtonKey = ValueKey<String>('feedbackContinueButton');
const feedbackPreparationPanelKey = ValueKey<String>(
  'feedbackPreparationPanel',
);

Future<FeedbackDraft?> showFeedbackPreparationDialog(
  BuildContext context, {
  FeedbackDraft? initialDraft,
}) {
  return showGeneralDialog<FeedbackDraft>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss feedback',
    pageBuilder: (context, animation, secondaryAnimation) {
      final mediaQuery = MediaQuery.of(context);
      final maxHeight = (mediaQuery.size.height - mediaQuery.padding.top)
          .clamp(0.0, double.infinity)
          .toDouble();

      return MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: _FeedbackPreparationDialog(
          initialDraft: initialDraft,
          maxHeight: maxHeight,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
      return SlideTransition(position: offset, child: child);
    },
  );
}

class _FeedbackPreparationDialog extends StatefulWidget {
  const _FeedbackPreparationDialog({
    required this.initialDraft,
    required this.maxHeight,
  });

  final FeedbackDraft? initialDraft;
  final double maxHeight;

  @override
  State<_FeedbackPreparationDialog> createState() =>
      _FeedbackPreparationDialogState();
}

class _FeedbackPreparationDialogState
    extends State<_FeedbackPreparationDialog> {
  final _panelKey = GlobalKey();
  late final double _maxHeight;
  double? _initialPanelHeight;

  @override
  void initState() {
    super.initState();
    _maxHeight = widget.maxHeight;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialPanelHeight != null) {
        return;
      }

      final renderObject = _panelKey.currentContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        setState(() => _initialPanelHeight = renderObject.size.height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final preparationSheet = FeedbackPreparationSheet(
      initialDraft: widget.initialDraft,
    );
    final panelContent = _initialPanelHeight == null
        ? ConstrainedBox(
            constraints: BoxConstraints(maxHeight: _maxHeight),
            child: preparationSheet,
          )
        : SizedBox(height: _initialPanelHeight, child: preparationSheet);

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: KeyedSubtree(
          key: feedbackPreparationPanelKey,
          child: Material(
            key: _panelKey,
            color: Theme.of(context).colorScheme.surface,
            elevation: 8,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(WraitRadiusTokens.card),
            ),
            child: panelContent,
          ),
        ),
      ),
    );
  }
}

class FeedbackPreparationSheet extends StatefulWidget {
  const FeedbackPreparationSheet({this.initialDraft, super.key});

  final FeedbackDraft? initialDraft;

  @override
  State<FeedbackPreparationSheet> createState() =>
      _FeedbackPreparationSheetState();
}

class _FeedbackPreparationSheetState extends State<FeedbackPreparationSheet> {
  late final TextEditingController _contactController;
  FeedbackCategory? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialDraft?.category;
    _contactController = TextEditingController(
      text: widget.initialDraft?.replyContact ?? '',
    );
  }

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _category;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        WraitSpacingTokens.lg,
        WraitSpacingTokens.md,
        WraitSpacingTokens.lg,
        WraitSpacingTokens.xs,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('send feedback', style: theme.textTheme.titleLarge),
            const SizedBox(height: WraitSpacingTokens.sm),
            Text(
              'What would you like to share?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: WraitSpacingTokens.sm),
            Wrap(
              spacing: WraitSpacingTokens.sm,
              runSpacing: WraitSpacingTokens.sm,
              children: [
                for (final option in FeedbackCategory.values)
                  ChoiceChip(
                    label: Text(option.label),
                    selected: category == option,
                    onSelected: (_) => setState(() => _category = option),
                  ),
              ],
            ),
            const SizedBox(height: WraitSpacingTokens.sm),
            TextField(
              key: feedbackContactFieldKey,
              controller: _contactController,
              maxLines: 1,
              scrollPadding: EdgeInsets.zero,
              decoration: const InputDecoration(
                labelText: 'reply contact (optional)',
                hintText: 'any contact information',
              ),
            ),
            const SizedBox(height: WraitSpacingTokens.md),
            Text(
              feedbackPrivacyCopy,
              key: feedbackPrivacyCopyKey,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: WraitSpacingTokens.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('cancel'),
                ),
                const SizedBox(width: WraitSpacingTokens.sm),
                FilledButton(
                  key: feedbackContinueButtonKey,
                  onPressed: category == null
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            FeedbackDraft(
                              category: category,
                              replyContact: _contactController.text,
                            ),
                          );
                        },
                  child: const Text('continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
