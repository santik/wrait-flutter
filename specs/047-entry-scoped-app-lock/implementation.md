# Implementation Record: Entry-scoped privacy lock

> **Feature number:** 047  
> **Branch:** `codex/feat/entry-scoped-app-lock`  
> **Status:** Awaiting external review  
> **Date:** 2026-09-08

## Outcome

The main recording route is now available without device authentication. The
entries list and validated entry-detail routes share one protected route shell:
one successful authentication unlocks list-to-detail navigation, while leaving
that shell disposes its controller so any return to Entries starts locked.

The existing authentication policy, recovery UI, inactive-lifecycle handling,
and native Android/iOS capture protections were reused unchanged.

## Implementation

```text
Application shell
  feedback wrapper
    router
      /                         main recording, no lock gate
      entries shell
        EntryLockScope
          route-local AppLockController
          AppLockGate
            /entries            entry list
            /entry/:id          entry detail
```

`EntryLockScope` creates a nested `ProviderScope` and explicitly overrides
`appLockControllerProvider` with a new `AppLockController`. This is important:
a nested scope without that override would inherit an unlocked controller from
outside the entries visit. The override keeps existing authenticator and
device-security-settings dependencies inherited from the parent scope.

The main screen no longer reads lock state. Its display-awake coordinator now
uses only recording state and lifecycle state, so an enabled entries lock
cannot suppress keep-awake while recording from the available main screen.

## Files changed

| File | Change |
| --- | --- |
| `lib/app.dart` | Removed the root `AppLockGate`; retained router, feedback wrapper, theme, localization, and bootstrap behavior. |
| `lib/core/router/app_router.dart` | Added one `ShellRoute` for `/entries` and `/entry/:id`. |
| `lib/presentation/app_lock/entry_lock_scope.dart` | Added the route-local controller scope and gate composition. |
| `lib/presentation/main/main_screen.dart` | Removed global lock reads/listeners. |
| `lib/presentation/main/recording_display_awake_coordinator.dart` | Removed the app-lock state dependency. |
| `integration_test/app_lock_flow_test.dart` | Replaced whole-app expectations with entry-scoped route, recovery, re-entry, and lifecycle coverage using synthetic data. |
| `integration_test/main_screen_display_awake_flow_test.dart` | Proved an enabled entries lock does not affect main-screen keep-awake behavior. |
| `test/presentation/main/main_screen_test.dart` | Removed the obsolete global-lock keep-awake seam; retained lock-disabled main-to-entry coverage. |
| `test/presentation/main/recording_display_awake_coordinator_test.dart` | Updated the coordinator contract tests. |

The existing router test already explicitly disables the lock and exercises
direct list/detail plus invalid-detail routes; it ran unchanged against the
new shell structure.

## Data, API, and privacy boundary audit

No database, migration, entry repository, preference, API, backend contract,
authentication provider, lock controller, lock UI, Android activity/manifest,
or iOS app/scene delegate was changed.

Audit performed:

- `git diff --check` completed with no whitespace errors.
- `git diff -U0` for production changes showed only root-gate removal, router
  shell placement, and removal of the obsolete main-screen lock dependency.
- The new `EntryLockScope` contains only Flutter/Riverpod and existing
  app-lock imports; a targeted search found no HTTP, backend, logger, or print
  calls.
- No changed feature file adds a backend call or diagnostic path for entry
  content, authentication secrets, or authentication results.

Android `FLAG_SECURE` and iOS `SceneDelegate` privacy-cover sources remain
unchanged and application-wide.

## Automated validation

| Command | Result |
| --- | --- |
| `dart format` over all changed production, test, and integration Dart files | Passed. |
| `flutter test test/core/router/app_router_test.dart test/presentation/app_lock test/data/auth/app_lock_authenticator_test.dart test/presentation/main/main_screen_test.dart test/presentation/main/recording_display_awake_coordinator_test.dart` | Passed: 66 tests. |
| `flutter analyze` | Passed: no issues found. |
| `flutter test -d emulator-5554 integration_test/app_lock_flow_test.dart integration_test/main_screen_display_awake_flow_test.dart` | Passed: 14 tests. |
| `flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/app_lock_flow_test.dart integration_test/main_screen_display_awake_flow_test.dart` | Passed: 14 tests. |
| Android emulator: `entry_list_flow_test.dart` | Passed: 16 tests. |
| Android emulator: `entry_detail_flow_test.dart` | Passed: 7 tests. |
| Android emulator: `main_screen_flow_test.dart` | First combined-suite run hit an existing timing-sensitive saved-state assertion; its focused rerun passed. The other 8 tests passed in the original run. |
| Android emulator: `capture_prevention_flow_test.dart` | Passed: 1 test. |
| iOS simulator: `entry_list_flow_test.dart` | Passed: 16 tests. |
| iOS simulator: `entry_detail_flow_test.dart` | Passed: 7 tests. |
| iOS simulator: `main_screen_flow_test.dart` | Passed: 9 tests. |
| iOS simulator: `capture_prevention_flow_test.dart` | Passed: 1 test. |

The first Android attempt to run all four unrelated regression files in one
`flutter test` command hit an emulator package-install/activity-launch race
after the entry-list test had started; rerunning each suite individually passed.
No source change was made for that runner issue.

## Runtime validation

### Android emulator (`emulator-5554`)

- A normal enabled-lock debug launch via `flutter run -d emulator-5554` showed
  the recording action and entry stats immediately, with no lock overlay.
- Tapping entry stats displayed the existing no-security recovery surface
  before the empty entry list was usable: `Unlock`, `Open settings`, and
  `Continue without lock`.
- Using the supported bypass exposed the empty list. Returning to main and
  entering Entries again displayed a fresh lock surface.
- After bypassing Entries, sending Home, waiting for lifecycle delivery, and
  bringing `com.wrait.flutter.dev/com.wrait.flutter.MainActivity` to the
  foreground displayed the locked recovery surface again.
- `adb -s emulator-5554 shell dumpsys window windows` reported the Wrait
  activity with `fl=... SECURE ...`, confirming capture protection persisted
  after main-to-entries navigation.

### iOS simulator (`491CD949-D3C0-4C4C-A6B9-15BAB1859156`)

- A normal enabled-lock launch via `flutter run -d
  491CD949-D3C0-4C4C-A6B9-15BAB1859156` displayed the main recording screen
  without an authentication prompt; a simulator screenshot captured only the
  ordinary main UI.
- The full deterministic entry-scoped route, re-entry, lifecycle, recovery,
  and display-awake suite passed on the simulator (14 tests), along with the
  focused entry/main/capture regressions above.
- Direct manual tapping into Entries could not be automated because macOS
  denied assistive access to the approved Simulator AppleScript attempt
  (`System Events` error `-1719`). This did not change app code or settings.
  The unchanged native authenticator is therefore covered on iOS by the
  existing simulator build/integration path, while the Android runtime run
  exercised the real supported no-security recovery surface.
- The current app data container's SplashBoard snapshots were inspected with
  Quick Look. The observed privacy snapshot thumbnail was black and contained
  no entry content. The existing iOS capture-prevention regression also passed.

## Acceptance-criteria traceability

| Criterion | Evidence |
| --- | --- |
| Main launches without authentication | Android/iOS normal launches; `app_lock_flow_test` main cold-launch test on both targets. |
| List and direct detail are protected | Entry-scoped integration tests cover list, direct detail, invalid route, blur, and blocked interaction on both targets. |
| One unlock covers list-to-detail | `entries stay locked until auth succeeds and share one visit`. |
| Main remains available and re-entry relocks | Main-resume and return-to-Entries integration tests; Android real recovery-path run. |
| Foreground exit relocks entries, not main; inactive does not loop | Entry lifecycle and in-flight inactive-churn integration tests on both targets; Android runtime background/resume run. |
| Existing recovery behavior remains entries-only | Cancel/retry, temporary-unavailable, no-security settings, and bypass integration coverage; Android no-security runtime surface. |
| Underlying entries stay obscured/non-interactive | Existing gate regression plus entry-scoped interaction-blocking integration test. |
| Existing entry workflows remain available | Passing entry-list/detail regressions on Android and iOS. |
| Capture privacy is unchanged | Passing capture-prevention regression on both targets, Android secure-window inspection, and iOS SplashBoard inspection. |
| No sensitive data reaches backend/logs | Source/diff privacy audit above. |

## Review gate

Implementation is complete and awaits an externally authored `review.md` in
this feature folder. No review file has been created or pre-filled by Codex.
No long-lived documentation has been changed; the post-review documentation
proposal gate remains pending.
