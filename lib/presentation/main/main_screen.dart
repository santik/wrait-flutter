import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../data/api/backend_providers.dart';
import '../../data/audio/audio_recording_providers.dart';
import '../../data/preferences/preferences_providers.dart';
import '../theme/design_tokens.dart';
import 'button_area.dart';
import 'main_recording_controller.dart';
import 'main_screen_stats.dart';
import 'main_screen_status.dart';
import 'recording_state.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  Timer? _savedAutoClearTimer;
  Timer? _countdownTicker;
  final ValueNotifier<double?> _countdownProgress = ValueNotifier<double?>(
    null,
  );
  bool? _storedHasEverRecorded;
  bool _hasRecordedThisSession = false;
  int _savedAutoClearGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadHasEverRecorded();
  }

  @override
  void dispose() {
    _savedAutoClearTimer?.cancel();
    _countdownTicker?.cancel();
    _countdownProgress.dispose();
    super.dispose();
  }

  Future<void> _loadHasEverRecorded() async {
    try {
      final hasEverRecorded = await ref
          .read(preferencesRepositoryProvider)
          .getHasEverRecorded();
      if (!mounted) {
        return;
      }
      setState(() {
        _storedHasEverRecorded = hasEverRecorded;
      });
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load hasEverRecorded for MainScreen.',
        name: 'MainScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _storedHasEverRecorded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RecordingControllerState>(mainRecordingControllerProvider, (
      previous,
      next,
    ) {
      _handleControllerTransition(
        previous?.recordingState,
        next.recordingState,
      );
    });

    final controllerState = ref.watch(mainRecordingControllerProvider);
    final quota = ref.watch(sessionRecordQuotaStateProvider);
    final stats =
        ref.watch(mainScreenStatsProvider).value ??
        const MainScreenStatsData(entryCount: 0, activeDays: 0);
    final hasEverRecorded =
        _hasRecordedThisSession || (_storedHasEverRecorded ?? false);
    final status = resolveMainScreenStatus(
      controllerState: controllerState,
      hasEverRecorded: hasEverRecorded,
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              Color.alphaBlend(
                colorScheme.primary.withValues(alpha: 0.06),
                colorScheme.surface,
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: WraitDesignTokens.screenPadding,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              key: const ValueKey('quotaLineSlot'),
                              height: WraitQuotaLineTokens.reservedHeight,
                              child: Center(
                                child: quota == null
                                    ? const SizedBox.shrink()
                                    : Semantics(
                                        container: true,
                                        label:
                                            'Recording quota ${quota.limit} total and ${quota.remaining} left.',
                                        child: Text(
                                          '${quota.limit} total / ${quota.remaining} left',
                                          key: const ValueKey('quotaLineText'),
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                color: colorScheme.secondary,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(
                              height: WraitQuotaLineTokens.gapBelow,
                            ),
                            ValueListenableBuilder<double?>(
                              valueListenable: _countdownProgress,
                              builder: (context, countdownProgress, _) {
                                return ButtonArea(
                                  recordingState:
                                      controllerState.recordingState,
                                  shakeErrorKey: controllerState.shakeErrorKey,
                                  buttonLabel: status.buttonLabel,
                                  countdownProgress: countdownProgress,
                                  onPressed: () {
                                    ref
                                        .read(
                                          mainRecordingControllerProvider
                                              .notifier,
                                        )
                                        .onMainButtonTapped();
                                  },
                                );
                              },
                            ),
                            const SizedBox(
                              height: WraitStatusLineTokens.gapAbove,
                            ),
                            SizedBox(
                              key: const ValueKey('statusLineSlot'),
                              height: WraitStatusLineTokens.reservedHeight,
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: WraitAnimationTokens.fade,
                                  child: _StatusLine(
                                    key: ValueKey(
                                      '${status.statusText}-${status.action}-${status.savedEntryId}',
                                    ),
                                    presentation: status,
                                    onTap: () => _handleStatusAction(status),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: WraitStatsLineTokens.gapAbove,
                            ),
                            SizedBox(
                              key: const ValueKey('statsLineSlot'),
                              height: WraitStatsLineTokens.reservedHeight,
                              child: Center(
                                child: Semantics(
                                  button: true,
                                  label:
                                      'Entry stats ${stats.displayText}. Opens the entry list.',
                                  child: InkWell(
                                    key: const ValueKey('statsLineButton'),
                                    borderRadius: BorderRadius.circular(
                                      WraitRadiusTokens.card,
                                    ),
                                    onTap: () => context.go('/entries'),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: WraitSpacingTokens.md,
                                        vertical: WraitSpacingTokens.sm,
                                      ),
                                      child: Text(
                                        stats.displayText,
                                        key: const ValueKey('statsLineText'),
                                        style: theme.textTheme.labelLarge,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleControllerTransition(
    RecordingState? previous,
    RecordingState next,
  ) {
    if (next is RecordingSaved) {
      _hasRecordedThisSession = true;
      if (previous != next) {
        _savedAutoClearTimer?.cancel();
        _savedAutoClearGeneration += 1;
        final generation = _savedAutoClearGeneration;
        final delay = ref
            .read(recordingFeedbackDelaysProvider)
            .savedDisplayWindow;
        _savedAutoClearTimer = Timer(delay, () {
          if (!mounted || generation != _savedAutoClearGeneration) {
            return;
          }
          ref.read(mainRecordingControllerProvider.notifier).clearSaved();
        });
      }
    } else {
      _savedAutoClearTimer?.cancel();
      _savedAutoClearTimer = null;
      _savedAutoClearGeneration += 1;
    }

    if (next is RecordingListening) {
      _startCountdownTicker(next);
    } else {
      _stopCountdownTicker();
    }
  }

  void _startCountdownTicker(RecordingListening listeningState) {
    _countdownTicker?.cancel();
    _updateCountdownProgress(listeningState);
    _countdownTicker = Timer.periodic(WraitAnimationTokens.countdownRefresh, (
      _,
    ) {
      if (!mounted) {
        return;
      }
      final currentState = ref
          .read(mainRecordingControllerProvider)
          .recordingState;
      if (currentState case RecordingListening()) {
        _updateCountdownProgress(currentState);
        return;
      }
      _stopCountdownTicker();
    });
  }

  void _stopCountdownTicker() {
    _countdownTicker?.cancel();
    _countdownTicker = null;
    if (_countdownProgress.value != null) {
      _countdownProgress.value = null;
    }
  }

  void _updateCountdownProgress(RecordingListening state) {
    final hardCapMs = ref.read(appConfigProvider).recordingHardCapMs;
    if (hardCapMs <= 0) {
      if (_countdownProgress.value != null) {
        _countdownProgress.value = null;
      }
      return;
    }
    final now = ref.read(monotonicClockProvider).now();
    final remaining = state.hardCapDeadlineElapsedRealtime - now;
    final clampedRemaining = remaining.clamp(0, hardCapMs);
    _countdownProgress.value = clampedRemaining / hardCapMs;
  }

  void _handleStatusAction(MainScreenStatusPresentation status) {
    switch (status.action) {
      case MainScreenStatusAction.startRecording:
        ref.read(mainRecordingControllerProvider.notifier).onMainButtonTapped();
        return;
      case MainScreenStatusAction.openSavedEntry:
        final entryId = status.savedEntryId;
        if (entryId == null) {
          return;
        }
        context.go('/entry/$entryId');
        return;
      case null:
        return;
    }
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.presentation,
    required this.onTap,
    super.key,
  });

  final MainScreenStatusPresentation presentation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      presentation.statusText,
      key: const ValueKey('statusLineText'),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyLarge,
    );

    if (!presentation.isStatusTappable) {
      return Semantics(
        container: true,
        label: 'Status message ${presentation.statusText}.',
        child: text,
      );
    }

    return Semantics(
      button: true,
      label: 'Status message ${presentation.statusText}.',
      child: InkWell(
        key: const ValueKey('statusLineButton'),
        borderRadius: BorderRadius.circular(WraitRadiusTokens.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WraitSpacingTokens.md,
            vertical: WraitSpacingTokens.sm,
          ),
          child: text,
        ),
      ),
    );
  }
}
