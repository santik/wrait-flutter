import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/app_lock_providers.dart';
import 'app_lock_controller.dart';
import 'app_lock_screen.dart';
import 'app_lock_test_keys.dart';

const double _lockedContentBlurSigma = 20;

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _shouldLockForLifecycleExit(AppLifecycleState state) {
    return switch (state) {
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => true,
      AppLifecycleState.inactive || AppLifecycleState.resumed => false,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handleForegroundReady();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(appLockEnabledProvider)) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _handleForegroundReady();
      });
      return;
    }

    if (_shouldLockForLifecycleExit(state)) {
      ref.read(appLockControllerProvider.notifier).lockForForegroundExit();
    }
  }

  Future<void> _handleForegroundReady() async {
    await ref.read(appLockControllerProvider.notifier).onForegroundReady();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(appLockEnabledProvider);
    if (!isEnabled) {
      return widget.child;
    }

    final state = ref.watch(appLockControllerProvider);
    final child = state.isLocked
        ? ExcludeSemantics(
            child: IgnorePointer(
              child: ImageFiltered(
                key: appLockBlurKey,
                imageFilter: ImageFilter.blur(
                  sigmaX: _lockedContentBlurSigma,
                  sigmaY: _lockedContentBlurSigma,
                ),
                child: widget.child,
              ),
            ),
          )
        : widget.child;

    return Stack(
      children: [
        child,
        if (state.isLocked)
          Positioned.fill(
            child: AppLockScreen(
              key: appLockOverlayKey,
              state: state,
              onUnlock: () {
                unawaited(
                  ref.read(appLockControllerProvider.notifier).unlock(),
                );
              },
              onOpenSettings: () {
                unawaited(
                  ref
                      .read(appLockControllerProvider.notifier)
                      .openSecuritySettings(),
                );
              },
              onContinueWithoutLock: () {
                ref
                    .read(appLockControllerProvider.notifier)
                    .continueWithoutLock();
              },
            ),
          ),
      ],
    );
  }
}
