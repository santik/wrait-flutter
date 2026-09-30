import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth/app_lock_providers.dart';
import '../../data/preferences/app_lock_preference_controller.dart';
import '../main/main_recording_controller.dart';
import '../theme/design_tokens.dart';
import 'settings_test_keys.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(appLockPreferenceControllerProvider);
    final buildAllowsLock = ref.watch(appLockBuildEnabledProvider);
    final recordingActive = ref.watch(
      mainRecordingControllerProvider.select((state) => state.isActive),
    );
    final canChange =
        buildAllowsLock &&
        preference.isReady &&
        !preference.isSaving &&
        !recordingActive;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: settingsBackButtonKey,
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: WraitDesignTokens.screenPadding,
          children: [
            Text('Privacy', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: WraitSpacingTokens.sm),
            SwitchListTile.adaptive(
              key: appLockSwitchKey,
              contentPadding: EdgeInsets.zero,
              title: const Text('App lock'),
              subtitle: const Text(
                "Use your device's screen lock when you open or return to Wrait.",
              ),
              value: preference.isReady && preference.enabled,
              onChanged: canChange
                  ? (value) {
                      unawaited(
                        ref
                            .read(appLockPreferenceControllerProvider.notifier)
                            .setEnabled(value),
                      );
                    }
                  : null,
            ),
            if (preference.isSaving) ...[
              const SizedBox(height: WraitSpacingTokens.sm),
              const LinearProgressIndicator(key: appLockSavingKey),
            ],
            if (!buildAllowsLock)
              const _Message(
                text: 'App lock is unavailable in this validation build.',
              )
            else if (recordingActive)
              const _Message(
                text: 'Finish the current recording before changing app lock.',
              )
            else if (preference.issue != null)
              _PreferenceIssue(issue: preference.issue!),
          ],
        ),
      ),
    );
  }
}

class _PreferenceIssue extends ConsumerWidget {
  const _PreferenceIssue({required this.issue});

  final AppLockPreferenceIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = switch (issue) {
      AppLockPreferenceIssue.noSecurity =>
        'Set up a device screen lock before enabling app lock.',
      AppLockPreferenceIssue.temporarilyUnavailable =>
        'Device authentication is temporarily unavailable. Try again.',
      AppLockPreferenceIssue.unavailable =>
        'Device authentication is unavailable on this device.',
      AppLockPreferenceIssue.saveFailed =>
        'Could not save the app-lock setting. Try again.',
      AppLockPreferenceIssue.settingsFailed =>
        'Could not open device security settings.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Message(text: message),
        if (issue == AppLockPreferenceIssue.noSecurity) ...[
          const SizedBox(height: WraitSpacingTokens.sm),
          OutlinedButton(
            key: appLockDeviceSettingsKey,
            onPressed: () {
              unawaited(
                ref
                    .read(appLockPreferenceControllerProvider.notifier)
                    .openDeviceSecuritySettings(),
              );
            },
            child: const Text('Open device settings'),
          ),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: appLockPreferenceErrorKey,
      padding: const EdgeInsets.only(top: WraitSpacingTokens.md),
      child: Text(text),
    );
  }
}
