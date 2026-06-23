import 'package:flutter/material.dart';

import 'app_lock_controller.dart';
import 'app_lock_test_keys.dart';

class AppLockScreen extends StatelessWidget {
  const AppLockScreen({
    required this.state,
    required this.onUnlock,
    required this.onOpenSettings,
    required this.onContinueWithoutLock,
    super.key,
  });

  final AppLockState state;
  final VoidCallback onUnlock;
  final VoidCallback onOpenSettings;
  final VoidCallback onContinueWithoutLock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ColoredBox(
      color: colorScheme.surface.withValues(alpha: 0.84),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Semantics(
              container: true,
              label: 'Wrait is locked.',
              hint: _semanticsHintFor(state),
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'wrait is locked',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _messageFor(state.status),
                    key: appLockMessageKey,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: appLockUnlockButtonKey,
                    onPressed: state.isPromptPending ? null : onUnlock,
                    child: const Text('Unlock'),
                  ),
                  if (state.isPromptPending) ...[
                    const SizedBox(height: 16),
                    const SizedBox(
                      key: appLockProgressKey,
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ],
                  if (state.canOpenSettings) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      key: appLockSettingsButtonKey,
                      onPressed: onOpenSettings,
                      child: const Text('Open settings'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your diary will be visible until you set up device security.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      key: appLockBypassButtonKey,
                      onPressed: onContinueWithoutLock,
                      child: const Text('Continue without lock'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _messageFor(AppLockStatus status) {
    return switch (status) {
      AppLockStatus.canceled => 'still locked',
      AppLockStatus.noSecurity => 'set up device security to protect Wrait',
      AppLockStatus.temporarilyUnavailable ||
      AppLockStatus.unavailable => 'unlock unavailable · try again',
      _ => 'Unlock Wrait to continue.',
    };
  }

  String _semanticsHintFor(AppLockState state) {
    if (state.canOpenSettings) {
      return 'Double tap Unlock to try again, or open settings to configure device security.';
    }

    if (state.isPromptPending) {
      return 'Authentication is in progress.';
    }

    return 'Double tap Unlock to authenticate and continue.';
  }
}
