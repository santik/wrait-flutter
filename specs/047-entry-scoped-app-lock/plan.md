# Implementation Plan: Entry-scoped privacy lock

> **Feature number:** 047
> **Spec:** [spec.md](spec.md)
> **Author:** Codex
> **Date:** 2026-09-08

---

## Approach summary

Move the existing privacy gate from the whole application shell to one shared
route shell that owns both the entries list and individual entry views. The
route shell will create a controller scope for one protected visit and reuse
the existing lock gate, screen, authenticator, recovery states, and lifecycle
handling. The main recording route will no longer instantiate or react to the
privacy-lock state, so it can launch and resume without an authentication
prompt. Leaving the shared entries shell disposes its controller scope; the
next entry visit therefore starts locked and prompts again.

This plan satisfies every approved acceptance criterion without changing the
device-authentication policy, entry storage, backend API, or native
capture-protection boundaries.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Protected navigation boundary | Add one router shell around the entries list and entry-detail routes | Both views form one protected area. A shared shell preserves one unlocked visit during list-to-detail navigation, unlike wrapping each screen independently. |
| Lock-state lifetime | Create EntryLockScope, which uses a nested provider scope that overrides the existing app-lock controller provider, then places AppLockGate around the shell child | The override gives the protected shell its own controller state while inheriting the existing authenticator and settings dependencies. Disposing the shell cancels any pending authentication and discards unlocked state, so re-entry naturally starts locked without global reset logic. |
| Main application shell | Remove AppLockGate from the MaterialApp builder and retain the existing feedback wrapper around the router | The main route and its feedback entry point are non-entry surfaces under the approved specification. Keeping the feedback wrapper in its current app-shell position preserves its configuration and lifecycle behavior without putting it behind the entry lock. |
| Existing lock mechanics | Reuse AppLockGate, AppLockController, AppLockScreen, and LocalAuth behavior unchanged | They already provide blurred and non-interactive protected content, automatic foreground prompting, single-flight authentication/settings recovery, cancellation handling, and the required no-inactive-relock behavior. Reuse avoids changing authentication policy or native behavior. |
| Direct and invalid routes | Keep the existing detail validation and place both detail and entries routes inside the protected shell | A valid direct entry route cannot bypass authentication. An invalid detail route still redirects to the entries list, which remains inside the same protected shell. |
| Display-awake behavior | Remove the app-lock state dependency from the main-screen display-awake coordinator | The main recording surface is no longer lockable. Keeping a global lock-state dependency would create a hidden locked state that could incorrectly suppress keep-awake while recording on the accessible main screen. Display-awake will depend only on recording state and app lifecycle. |
| Capture privacy | Leave Android secure-window behavior and the iOS scene privacy cover unchanged | The specification narrows only in-app authentication scope. The existing operating-system capture protections stay app-wide and native. |
| Authentication configuration | Retain APP_LOCK_ENABLED as the existing app-wide enable/disable control, applied when the entry shell mounts | This preserves the established test and manual-validation escape hatch without adding a persisted user setting or a new rollout mechanism. |

### Route and state boundary

~~~text
Application shell
  feedback wrapper
    router
      /                         -> main recording screen, no lock gate
      entries route shell
        EntryLockScope
          route-local app-lock controller
          existing AppLockGate
            /entries            -> entry list
            /entry/:id          -> entry detail
~~~

The route-local provider scope must explicitly override the controller provider.
A nested provider scope without that override would inherit the parent
container's controller state and would not guarantee a fresh locked visit on
re-entry.

## File changes

| File | Action | Description |
| --- | --- | --- |
| lib/app.dart | Modify | Remove the root AppLockGate while keeping the configured feedback wrapper around the router and preserving theme, localization, and bootstrap behavior. |
| lib/core/router/app_router.dart | Modify | Add one shell route containing the existing entries-list and entry-detail routes; wrap its child in EntryLockScope and preserve direct-route parsing and redirects. |
| lib/presentation/app_lock/entry_lock_scope.dart | Create | Define the small presentation boundary that creates a route-local controller override and composes the existing AppLockGate around a protected child. |
| lib/presentation/main/main_screen.dart | Modify | Remove reads/listeners for app-lock state from the main recording surface and initialize display-awake behavior as unlocked. |
| lib/presentation/main/recording_display_awake_coordinator.dart | Modify | Remove the now-invalid app-lock constructor/state/update contract so keep-awake is determined only by active recording and resumed lifecycle state. |
| test/core/router/app_router_test.dart | Modify | Keep direct entry-list/detail and invalid-detail coverage under the new shell structure, with app lock explicitly disabled for router-only assertions. |
| test/presentation/main/main_screen_test.dart | Modify | Remove the obsolete assertion that a global app lock releases main-screen keep-awake behavior; retain main-to-entry navigation with the lock disabled where that is not the subject under test. |
| test/presentation/main/recording_display_awake_coordinator_test.dart | Modify | Update the coordinator contract and retain lifecycle/recording state coverage without a global lock-state input. |
| integration_test/app_lock_flow_test.dart | Modify | Replace whole-app-lock expectations with deterministic entry-scoped flows using the existing fake authenticator and synthetic entry data. |
| integration_test/main_screen_display_awake_flow_test.dart | Modify | Remove the no-longer-possible global-lock release case and prove an enabled entry-lock configuration does not prevent the accessible main screen from managing keep-awake correctly. |
| specs/047-entry-scoped-app-lock/implementation.md | Create during implementation | Record completed tasks, automated results, Android/iOS validation evidence, and any limitation discovered during verification. |

No changes are planned for the authentication implementation, lock UI,
authentication providers, native Android/iOS capture sources, entry repository,
database schema, OpenAPI contract, import/export format, or deployment scripts.

## API contract details

No HTTP endpoint, request, response, or backend error contract changes.

### Internal route contract

The application continues to expose the same user-facing navigation targets:

~~~text
/           main recording screen
/entries    entry list
/entry/:id  validated entry detail
~~~

Only the ownership changes:

- The main route is not inside a lock gate and must not initiate device
  authentication at launch or after a foreground exit.
- Both entries routes are descendants of one protected shell. The first frame
  of a protected visit is covered by the existing lock overlay, which schedules
  the existing device-authentication flow.
- An authenticated entries list and its detail view share the same controller
  state while the shell remains active.
- Navigating out of that shell disposes the route-local controller. Its
  existing disposal behavior cancels any pending authentication; a later visit
  receives a new locked controller.
- The existing no-security, unavailable, retry, settings, and supported bypass
  outcomes remain unchanged and apply only while the user is entering the
  protected area.

The internal display-awake contract becomes:

~~~text
keep display awake = recording is actively listening
                     AND application lifecycle is resumed
~~~

It no longer consumes app-lock state because the main screen is not covered by
the entry-scoped gate.

## Data model changes

No persisted data model or migration is required.

### Before

~~~text
One application-wide app-lock controller and gate cover the router,
feedback surface, main recording screen, entry list, and entry detail.

The main-screen display-awake coordinator receives app-lock state.
~~~

### After

~~~text
The application shell exposes the main recording screen without a lock gate.

One entries route shell owns a temporary controller scope and the existing
gate for the entry list and entry detail. The controller state exists only for
that protected visit.

The main-screen display-awake coordinator receives recording and lifecycle
state only.
~~~

### Migration

None. No entry values, encrypted-database artifacts, preferences,
authentication secrets, or authentication settings are added, removed, or
rewritten. Existing installs adopt the new route scope on their next launch.

## Test strategy

Every in-scope user flow receives deterministic integration coverage. Existing
entry-list and entry-detail integration suites continue to exercise editing,
deletion, imports, exports, drafts, and sharing with the lock disabled so they
remain focused on their own behavior; the entry-lock integration suite will
add a post-unlock list-to-detail assertion to prove that the new boundary does
not block normal entry review.

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Main cold launch renders the recording action without authenticating | Integration | integration_test/app_lock_flow_test.dart |
| Main foreground exit and resume do not invoke entry authentication or display a lock overlay | Integration | integration_test/app_lock_flow_test.dart |
| Entering the entries list displays the protected overlay, blocks underlying entry interaction, then exposes synthetic list content after successful authentication | Integration | integration_test/app_lock_flow_test.dart |
| Opening a valid direct entry-detail route is protected before its synthetic entry content can be used | Integration | integration_test/app_lock_flow_test.dart |
| Invalid direct detail routes redirect to the protected entries list and do not bypass authentication | Widget/router and integration | test/core/router/app_router_test.dart; integration_test/app_lock_flow_test.dart |
| One successful authentication permits entries-list to entry-detail navigation without a second prompt | Integration | integration_test/app_lock_flow_test.dart |
| Leaving entries for main and entering entries again starts a new locked visit and requests authentication again | Integration | integration_test/app_lock_flow_test.dart |
| A true foreground exit while in entries relocks and prompts on resume; inactive-only lifecycle churn does not restart a pending request | Integration | integration_test/app_lock_flow_test.dart |
| Cancelled, unavailable, and no-security outcomes keep entries unavailable and retain the existing retry/settings/bypass interactions | Integration plus existing widget regression | integration_test/app_lock_flow_test.dart; test/presentation/app_lock/app_lock_gate_test.dart |
| Existing lock blur, interaction blocking, and accessibility semantics remain intact | Widget regression | test/presentation/app_lock/app_lock_gate_test.dart |
| Existing controller single-flight, cancellation, timeout, and settings guards remain intact | Unit regression | test/presentation/app_lock/app_lock_controller_test.dart; test/data/auth/app_lock_authenticator_test.dart |
| Main-screen keep-awake behavior still follows recording and lifecycle state when entry locking is enabled | Widget and integration | test/presentation/main/main_screen_test.dart; test/presentation/main/recording_display_awake_coordinator_test.dart; integration_test/main_screen_display_awake_flow_test.dart |
| Existing entry operations remain usable after the lock boundary is crossed, and their focused regressions remain stable with lock disabled | Integration regression | integration_test/entry_list_flow_test.dart; integration_test/entry_detail_flow_test.dart |
| Existing main recording/navigation behavior and capture-prevention navigation remain available | Integration regression | integration_test/main_screen_flow_test.dart; integration_test/capture_prevention_flow_test.dart |
| The feature adds no backend or diagnostic path for entry content, authentication secrets, or authentication results | Source and diff privacy audit | Changed feature files, existing authentication boundary, and implementation.md evidence |

Before device validation, run the affected widget/unit suites, the route suite,
the entry-scoped lock integration suite, display-awake integration coverage,
and the listed main/entry/capture regressions. Format changed Dart files with
dart format and run flutter analyze. Complete a source/diff privacy audit that
confirms the feature adds no backend call, entry-content logging, secret
logging, or authentication-result logging; record that audit in
implementation.md.

### Android emulator verification

1. Run the deterministic entry-scoped app-lock integration suite on the
   configured Android emulator with synthetic data and fake authentication.
   Record the test output for main launch, direct entry access, re-entry,
   lifecycle relock, and recovery-state coverage.
2. Build and launch the intended Android validation artifact with the existing
   lock setting enabled. Perform a launcher-style cold start of the installed
   target, using the release identity command when validating that artifact:

   ~~~text
   adb shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity
   ~~~

3. Confirm that the main screen is usable without a device-authentication
   prompt. Navigate to the entries area and confirm that the native
   authentication prompt, or the existing supported unavailable/no-security
   recovery surface, appears before entry content is usable.
4. Use an enrolled emulator authentication method where available, or exercise
   the existing supported recovery path. Verify list-to-detail navigation after
   success, navigation back to main, and a second prompt after returning to
   entries.
5. While entries are visible, perform a true background/foreground cycle and
   verify relock. Repeat the cycle from main and verify it returns without an
   entry lock prompt. Do not treat inactive alone as a relock trigger.
6. Run the existing capture-prevention regression and inspect the secure-window
   state after the main-to-entries navigation. Existing native capture privacy
   must still be present; do not alter it to simplify screenshots.

Expected evidence: passing integration output, launcher cold-start result,
screenshots or test captures of unlocked main and locked/unlocked entries
states using only synthetic content, a second-entry prompt result, lifecycle
observations, and a secure-window inspection.

### iOS simulator verification

1. Run the deterministic entry-scoped app-lock integration suite on the booted
   iOS simulator with synthetic data and fake authentication. Record the same
   route, re-entry, lifecycle, and recovery-state assertions as Android.
2. Launch the normal app with locking enabled. Verify the main recording screen
   appears without a device-authentication prompt, then navigate to entries
   and observe the existing native authentication prompt or supported recovery
   surface before entry content is usable.
3. Use the simulator's available enrolled authentication method or the
   existing supported recovery path. Verify list-to-detail navigation after
   access, return to main, a new prompt on entries re-entry, and relock after
   background/resume while in entries.
4. Repeat a background/resume cycle from main and verify no entry lock prompt
   appears there. Keep the current generic iOS privacy cover intact and use
   only synthetic content in screenshots.
5. Run the capture-prevention navigation regression. If app-switcher
   automation is unavailable, inspect the stored SplashBoard snapshot using
   the established validation method rather than weakening the native cover.

Expected evidence: passing iOS integration output, simulator observations for
main and entries states, re-entry and resume results, and confirmation that the
native privacy cover remains unchanged.

### Validation exception request

No exception is requested. Android emulator and iOS simulator validation,
including entry-scoped integration coverage and runtime checks, are required
before final approval.

## Review and finalization

- Implementation will create implementation.md with task completion and
  Android/iOS evidence, then stop for an externally authored review.md unless
  the user explicitly skips review.
- After review.md is read, each finding will be assessed individually and a
  remediation plan will be presented for explicit approval before any files
  change.
- This approved feature intentionally supersedes the current root-only
  app-lock guidance. After final approved implementation and review handling,
  propose durable updates to AGENTS.md, docs/application-description.md, and
  docs/agent-findings.md. Those documents must not be edited until the user
  explicitly approves the proposed wording at the final knowledge-capture
  gate.

## Integration notes

- EntryLockScope inherits the existing production authenticator, warning
  logger, and device-security settings opener. It overrides only the lock
  controller lifetime for the protected route shell.
- The current APP_LOCK_ENABLED define continues to disable the lock gate for
  tests and focused manual validation. It does not become a user preference and
  it does not change which routes are protected when enabled.
- Wiredash remains configured at the application level, but it is no longer
  inside the entry-only lock boundary. The current single feedback entry point
  on the main screen remains available without authentication, as required by
  the approved scope.
- The existing entry list/detail harnesses should continue to override locking
  off unless a test is specifically validating the entry-authentication
  boundary. This keeps unrelated entry-data tests deterministic and focused.
- Android FLAG_SECURE and the iOS scene cover remain native, application-wide
  protections. No platform manifest, activity, app delegate, or scene delegate
  changes are planned.

## Rollout & migration

Ship with the next normal Android and iOS application build. No feature flag,
backend rollout, database migration, application-identity change, or secret is
needed.

Existing users will see the main recording screen without the previous
application-wide prompt after updating. Their entry data remains protected when
they enter the entries area and remains covered by the existing native capture
privacy protections. The existing build-time lock disable define remains
available only for its established testing/validation purpose.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| The protected shell is recreated during list-to-detail navigation and prompts twice | Medium | High | Use one shared shell rather than screen-level gates and assert exactly one authentication call across list-to-detail navigation. |
| An unlocked controller leaks from a prior visit into a later entries visit | Medium | High | Give the shell an explicit controller-provider override whose container is disposed when leaving the route; test exit/re-entry authentication count. |
| A direct detail URL or invalid-detail redirect bypasses the gate | Low | High | Nest both detail and entries routes under the protected shell and cover valid/invalid direct navigation in router and integration tests. |
| Main recording remains coupled to a hidden locked controller and fails to keep the display awake | Medium | Medium | Remove the lock-state contract from the main display-awake path and add focused widget/integration coverage with locking enabled. |
| Native authentication emits inactive lifecycle events and creates a repeated prompt loop | Low | High | Reuse the existing AppLockGate and controller unchanged; retain inactive-churn regression coverage and do not relock on inactive. |
| Feedback or other main-screen content is unexpectedly blocked after backgrounding | Medium | Medium | Remove the root gate, explicitly test main resume with no authentication, and update the old whole-app feedback-lock expectation. |
| Existing platform capture privacy is accidentally weakened while altering app-shell composition | Low | High | Do not modify native capture code; run capture-prevention regression and inspect Android secure-window/iOS cover evidence during device verification. |
| Existing entry workflows regress after unlocking | Low | Medium | Assert post-unlock list-to-detail behavior and run the established entry list/detail integration suites with their targeted lock-disabled harnesses. |

## Open items from spec

None.
