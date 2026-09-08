import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_controller.dart';
import 'app_lock_gate.dart';

/// Owns one lock-controller lifetime for the protected entries route shell.
///
/// The explicit override is required: a nested provider scope without one
/// inherits its parent's controller state and would leave a prior visit
/// unlocked when the user returns to entries.
class EntryLockScope extends StatelessWidget {
  const EntryLockScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        appLockControllerProvider.overrideWith(AppLockController.new),
      ],
      child: AppLockGate(child: child),
    );
  }
}
