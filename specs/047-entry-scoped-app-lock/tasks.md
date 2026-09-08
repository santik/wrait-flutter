# Tasks: Entry-scoped privacy lock

> **Feature number:** 047
> **Plan:** [plan.md](plan.md)
> **Author:** Codex
> **Date:** 2026-09-08

---

## Legend

- [ ] — not started
- [x] — complete
- [P] — can be parallelized with other [P] tasks in the same group
- [B] — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
[P] can be worked on in parallel.

### Group 1: Implementation setup

Establish the approved implementation boundary without touching unrelated
user-owned worktree changes.

- [x] Inspect the dirty worktree immediately before implementation, preserve
      the existing untracked 043 and 046 feature artifacts, and create the
      feature branch codex/feat/entry-scoped-app-lock before modifying app
      code.
- [x] Change the feature status to In Progress when implementation begins and
      record the branch/implementation start in spec.md.
  - Depends on: feature branch creation
- [x] Confirm the existing lock gate, controller, authenticator, and native
      Android/iOS capture-protection sources remain reuse-only boundaries; do
      not change authentication policy, device-security recovery, inactive
      lifecycle handling, or native capture behavior.

### Group 2: Route and application-shell implementation

Create a shared protected entry visit while leaving main recording and feedback
outside the lock.

- [x] [P] Create EntryLockScope. It must create a nested provider scope that
      explicitly overrides appLockControllerProvider with a fresh controller,
      inherit the existing authenticator/settings dependencies, and wrap its
      child in the existing AppLockGate —
      lib/presentation/app_lock/entry_lock_scope.dart
  - Depends on: Group 1 implementation boundary confirmation
- [x] Move the existing entries list and validated entry-detail routes under
      one ShellRoute whose child is EntryLockScope. Preserve the existing root
      route, direct route behavior, and invalid-ID redirect to protected
      entries —
      lib/core/router/app_router.dart
  - Depends on: EntryLockScope creation
- [x] Remove only the root AppLockGate wrapper from the MaterialApp builder;
      retain the existing configured feedback wrapper, router, theme,
      localization, and non-blocking startup behavior —
      lib/app.dart
  - Depends on: protected entries shell routing
- [x] [P] Remove app-lock reads, listeners, and effective-lock-state handling
      from MainScreen so normal main recording never creates or reacts to a
      hidden global locked state —
      lib/presentation/main/main_screen.dart
  - Depends on: approved route-scope decision
- [x] [P] Simplify RecordingDisplayAwakeCoordinator to accept and recompute
      from recording state and lifecycle state only; remove its app-lock state
      field, constructor argument, and update method —
      lib/presentation/main/recording_display_awake_coordinator.dart
  - Depends on: approved route-scope decision
- [x] Format the changed Dart production files and confirm that no
      authentication, entry-storage, backend, native privacy, or feedback
      secret/configuration code was changed beyond the approved app-shell
      placement —
      lib/app.dart, lib/core/router/app_router.dart,
      lib/presentation/app_lock/entry_lock_scope.dart,
      lib/presentation/main/

### Group 3: Automated test implementation

Add deterministic coverage for all protected-area flows, then update focused
tests affected by the display-awake contract.

- [x] [P] Update router widget coverage to exercise direct entries/detail and
      invalid-detail routes under the new shared shell while explicitly
      disabling the lock for router-only assertions —
      test/core/router/app_router_test.dart
  - Depends on: Group 2 router implementation
- [x] [P] Update main-screen widget coverage to remove the obsolete
      global-lock/keep-awake expectation and retain normal main-to-entry
      navigation with a disabled lock —
      test/presentation/main/main_screen_test.dart
  - Depends on: Group 2 main-screen implementation
- [x] [P] Update RecordingDisplayAwakeCoordinator unit tests for the
      recording-plus-lifecycle-only contract; retain listening, upload/error,
      inactive/resume, retry, and disposal coverage —
      test/presentation/main/recording_display_awake_coordinator_test.dart
  - Depends on: Group 2 coordinator implementation
- [x] Rewrite the app-lock integration suite around the entry-scoped contract
      with synthetic entry data and the existing fake authenticator:
  - main cold launch performs zero authentication calls and remains usable;
  - main background/resume performs zero entry-authentication calls;
  - entry-list navigation and a valid direct detail route start locked, block
    underlying interaction, and expose content only after success;
  - an invalid direct detail route redirects to a still-protected entries list;
  - list-to-detail navigation after success uses one protected visit and does
    not prompt again;
  - exiting to main then returning to entries prompts again;
  - true foreground exit from entries relocks, while inactive-only churn does
    not restart a pending prompt;
  - cancelled, unavailable, and no-security outcomes retain retry, settings,
    and bypass behavior only for entries; and
  - the obsolete whole-app feedback-lock assertion is replaced with main-route
    availability coverage —
      integration_test/app_lock_flow_test.dart
  - Depends on: Group 2 route and app-shell implementation
- [x] Update main-screen display-awake integration coverage so the enabled
      entry-lock configuration cannot disable keep-awake on the accessible main
      recording screen; remove only the obsolete global-controller test seam —
      integration_test/main_screen_display_awake_flow_test.dart
  - Depends on: Group 2 main-screen and coordinator implementation
- [x] Keep unrelated entry list/detail integration harnesses lock-disabled and
      run a repository search to confirm all focused non-lock WraitApp tests
      retain that override. Do not broaden unrelated entry-data tests with
      device-authentication setup —
      integration_test/entry_list_flow_test.dart,
      integration_test/entry_detail_flow_test.dart, test/, integration_test/
  - Depends on: app-lock integration rewrite
- [x] Run dart format on all changed Dart test and integration files.

### Group 4: Automated validation and regression checks

Run focused tests before platform-specific manual verification. Record exact
commands and outcomes in the validation-evidence section below.

- [x] Run the focused route, app-lock gate/controller/authenticator, main
      screen, and display-awake unit/widget suites —
      test/core/router/app_router_test.dart,
      test/presentation/app_lock/,
      test/data/auth/app_lock_authenticator_test.dart,
      test/presentation/main/main_screen_test.dart,
      test/presentation/main/recording_display_awake_coordinator_test.dart
  - Depends on: Group 3 test implementation
- [x] Run flutter analyze and resolve all feature-caused diagnostics without
      weakening test coverage.
  - Depends on: Group 2 and Group 3
- [x] Complete a source/diff privacy audit. Confirm that changed feature files
      add no backend call or diagnostic logging path for entry content,
      authentication secrets, or authentication results, and record the
      unchanged existing authentication/data boundaries in implementation.md.
  - Depends on: Group 2 production implementation
- [x] Run the deterministic entry-scoped lock and display-awake integration
      suites on each available target before manual checks —
      integration_test/app_lock_flow_test.dart,
      integration_test/main_screen_display_awake_flow_test.dart
  - Depends on: Group 3 test implementation
- [x] Run focused entry-list, entry-detail, main-screen, and
      capture-prevention integration regressions using their existing
      lock-disabled harnesses, and record any known emulator limitation rather
      than treating it as a feature regression —
      integration_test/entry_list_flow_test.dart,
      integration_test/entry_detail_flow_test.dart,
      integration_test/main_screen_flow_test.dart,
      integration_test/capture_prevention_flow_test.dart
  - Depends on: focused app-lock integration success
- [x] Build the intended Android emulator artifact and iOS simulator artifact
      after automated tests pass, recording build output and preserving the
      existing app identities and configuration.
  - Depends on: flutter analyze success

### Group 5: Android emulator verification

Perform the required Android runtime checks with synthetic content and preserve
all existing native capture protection.

- [x] Launch the enabled-lock Android validation build using a launcher-style
      cold start. Confirm main recording is immediately usable without an
      authentication prompt, then navigate to entries and observe the native
      prompt or the existing supported recovery state before entry content is
      usable.
  - Depends on: Group 4 Android build and integration success
- [x] Complete available emulator authentication or the supported recovery
      path, verify list-to-detail access, return to main, then re-enter entries
      and verify a new authentication request.
  - Depends on: Android cold-launch verification
- [x] Verify a true background/foreground cycle relocks entries but not main;
      confirm inactive alone does not trigger a repeated prompt.
  - Depends on: Android entry access verification
- [x] Run capture-prevention regression and inspect Android secure-window state
      after main-to-entries navigation. Capture only synthetic-content evidence
      and do not alter FLAG_SECURE to make screenshots easier.
  - Depends on: Android lifecycle verification

### Group 6: iOS simulator verification

Perform the corresponding iOS runtime checks with synthetic content and retain
the existing generic privacy cover.

- [x] Launch the enabled-lock iOS simulator build. Confirm main recording is
      immediately usable without authentication, then navigate to entries and
      observe the native prompt or supported recovery state before entry
      content is usable.
  - Depends on: Group 4 iOS build and integration success
- [x] Complete available simulator authentication or the supported recovery
      path, verify list-to-detail access, return to main, then re-enter entries
      and verify a new authentication request.
  - Depends on: iOS cold-launch verification
- [x] Verify a true background/foreground cycle relocks entries but not main;
      confirm inactive-only lifecycle activity does not restart an in-flight
      prompt.
  - Depends on: iOS entry access verification
- [x] Run capture-prevention navigation regression and verify the existing iOS
      privacy-cover path. If app-switcher automation is unavailable, inspect
      the SplashBoard snapshot with the established method and document that
      evidence without weakening the cover.
  - Depends on: iOS lifecycle verification

### Group 7: Implementation record and review gate

Record evidence and stop for the externally authored review loop.

- [x] Cross-check every acceptance criterion against automated and Android/iOS
      evidence. Resolve any uncovered criterion before declaring implementation
      complete.
  - Depends on: Groups 4 through 6
- [x] Create implementation.md with the route-scope design, files changed,
      no-data/no-API confirmation, test commands/results, runtime evidence,
      and any documented validation limitation —
      specs/047-entry-scoped-app-lock/implementation.md
  - Depends on: acceptance-criterion evidence cross-check
- [ ] Stop and wait for an externally authored review.md unless the user
      explicitly skips review.
- [ ] Read review.md, assess every finding case by case, and prepare a
      remediation plan without changing files.
  - Depends on: externally provided review.md
- [ ] Present the remediation plan and wait for explicit approval before
      changing code, tests, or SDD artifacts.
  - Depends on: remediation plan completion
- [ ] Implement only approved review fixes; update spec.md, plan.md, tasks.md,
      implementation.md, source, and tests when review changes scope,
      approach, or validation.
  - Depends on: explicit remediation approval
- [ ] Repeat the review/fix loop if the same review.md receives another pass.

### Group 8: Final knowledge capture and closeout

Handle the durable guidance change caused by replacing the documented app-wide
lock with an entry-scoped one.

- [ ] Decide whether the finished feature requires long-lived documentation
      updates. The expected answer is yes because root-lock guidance and the
      product description will no longer match runtime behavior.
  - Depends on: completed review/fix loop or explicit review skip
- [ ] Propose precise updates to AGENTS.md, docs/application-description.md,
      and docs/agent-findings.md, including replacement of root/app-wide lock
      guidance with the approved entry-scoped behavior.
  - Depends on: durable-update decision
- [ ] Stop and wait for explicit user approval before editing any long-lived
      guidance documents.
  - Depends on: documentation proposal
- [ ] Apply only approved documentation updates, record the knowledge-capture
      decision, mark spec.md Complete, and add final status-history evidence.
  - Depends on: explicit documentation approval, or an explicit no-update
    decision

## Completion criteria

All implementation and validation tasks are checked, every acceptance criterion
has recorded evidence, Android emulator and iOS simulator verification have
passed with no unapproved exception, external review has been handled or
explicitly skipped, and the final knowledge-capture gate is complete.

## Validation evidence

- Focused unit/widget tests, formatter, and `flutter analyze` pass; see
  [implementation.md](implementation.md) for exact commands.
- The entry-scoped lock and display-awake integration suites pass on Android
  emulator `emulator-5554` and iOS simulator `491CD949-D3C0-4C4C-A6B9-15BAB1859156`.
- Existing entry-list/detail and capture-prevention integration regressions pass
  individually on both targets. The Android combined multi-file command had an
  emulator package-install race; individual reruns passed, and a first-run
  main-screen timing assertion also passed on its focused rerun.
- Android normal-runtime evidence confirmed unlocked main, locked entries,
  supported no-security recovery, fresh locking on re-entry and resume, and
  `FLAG_SECURE`. iOS normal runtime confirmed an unlocked main screen; iOS
  deterministic route/lifecycle/recovery coverage passed. Host accessibility
  permission prevented direct simulator tapping, which is documented in
  implementation.md; no source or privacy setting was weakened.

## Notes

- No validation exception is approved or requested.
- Existing untracked feature artifacts in specs/043-entry-inline-edit-autosave
  and specs/046-entry-search are user-owned worktree changes and must remain
  untouched.
- The current project guidance describing a root app lock is intentionally
  superseded by this approved feature only after the final knowledge-capture
  approval; do not edit long-lived guidance earlier.
