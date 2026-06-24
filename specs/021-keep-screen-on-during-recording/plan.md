# Implementation Plan: Keep Screen On During Recording

> **Feature number:** 021
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-23

---

## Approach summary

Implement keep-awake as an app-owned display service driven only by foreground
`RecordingListening` state. The main recording surface will observe recording
state, lifecycle changes, app-lock state, and disposal, then request display
awake while listening is visible and release it for upload, processing, idle,
saved, error, deleted, background, locked, and disposal states. The platform
call will stay behind a small Riverpod-injected abstraction backed by the
existing `wakelock_plus` dependency, keeping idempotency and cleanup testable
without changing recording, transcription, cleanup, persistence, app-lock,
capture-prevention, quota, or navigation behavior.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Keep-awake scope | Treat only `RecordingListening` on the foreground main screen as keep-awake eligible | The clarified spec explicitly excludes upload, processing, cleanup, background, and app-lock states. Existing `RecordingControllerState.isActive` includes uploading and processing, so reusing it would violate the spec. |
| State owner | Add a small `RecordingDisplayAwakeCoordinator` owned by `MainScreen` | `MainScreen` already observes lifecycle and owns listening timer visibility, so it has the required foreground/listening context without pushing UI lifecycle concerns into the recording controller. |
| Platform boundary | Create an injectable `DisplayAwakeService` backed by `WakelockPlus.toggle(enable: ...)` | `wakelock_plus` is already present in `pubspec.yaml`, supports Android and iOS, and its toggle API matches the desired boolean contract. Reusing the existing dependency avoids expanding the runtime surface for a simple platform toggle. An app-owned interface keeps tests deterministic and prevents static plugin calls from leaking through UI code. |
| Idempotency | Track the last requested keep-awake state in the coordinator and call the service only when the desired state changes | The plugin is documented as tolerant of redundant calls, but app-level idempotency directly satisfies the spec and makes duplicate transition behavior testable. |
| Cleanup | Release keep-awake from coordinator disposal and from lifecycle/app-lock transitions | This handles normal state transitions plus widget disposal, app close, background, and app-lock cleanup paths without relying on a final recording-state emission. |
| App-lock interaction | Watch `appLockControllerProvider`; any locked state makes desired keep-awake false | US-019 may preserve in-progress work while locked, but the clarified US-021 scope treats app-lock as inactive for display-awake behavior. |
| Lifecycle interaction | Treat non-`resumed` lifecycle states as inactive for keep-awake | Foreground listening is the only eligible state. Backgrounding, pausing, hidden, detached, and inactive states should release keep-awake; resume recomputes from current recording and lock state. If the initial lifecycle state is unknown, start from a conservative non-resumed assumption until Flutter provides a definitive lifecycle callback. |
| Failure handling | Log service errors, return success/failure from the display-awake service, and let the coordinator track desired state separately from applied state | Keep-awake failure should not break recording or expose user-visible errors. Tracking applied state separately avoids desynchronizing the coordinator when a platform call fails or when disposal races an in-flight toggle. |
| User messaging | Add no visible UI for keep-awake state | The feature should preserve the current minimal recording UI and only affect ordinary screen timeout behavior. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/data/display/display_awake_service.dart` | Create | Define `DisplayAwakeService`, warning logger, production `WakelockDisplayAwakeService`, and Riverpod provider. |
| `lib/presentation/main/recording_display_awake_coordinator.dart` | Create | Manage idempotent acquire/release based on listening, lifecycle, app-lock, and disposal inputs. |
| `lib/presentation/main/main_screen.dart` | Modify | Instantiate/dispose the coordinator, feed it controller transitions, lifecycle changes, and app-lock changes while preserving existing countdown and permission-resume behavior. |
| `test/data/display/display_awake_service_test.dart` | Create | Unit coverage for production service delegating to an injectable wakelock client and logging failures without throwing into UI code. |
| `test/presentation/main/recording_display_awake_coordinator_test.dart` | Create | Unit coverage for listening acquisition, upload/processing/inactive release, app-lock release, lifecycle release/resume recompute, duplicate transition idempotency, and disposal cleanup. |
| `test/presentation/main/main_screen_test.dart` | Modify | Add or adjust widget coverage proving `MainScreen` wires listening transitions, app lifecycle changes, app-lock changes, and disposal into the display-awake service. |
| `integration_test/main_screen_display_awake_flow_test.dart` | Create | Add main-screen integration coverage with fake recording/app-lock state and a fake display-awake service proving UI wiring enables keep-awake while listening and releases on upload/processing/saved/error/background/lock transitions. |
| `specs/021-keep-screen-on-during-recording/tasks.md` | Modify later | Filled in during the Tasks phase after plan approval. |
| `specs/021-keep-screen-on-during-recording/implementation.md` | Create later | Implementation details and validation evidence. |

## API contract details

No backend HTTP endpoints are introduced or modified.

Internal display-awake contract:

```text
DisplayAwakeService
- Future<void> setAwake(bool enabled)

RecordingDisplayAwakeCoordinator inputs
- recordingState: RecordingState
- lifecycleState: AppLifecycleState
- appLockState: AppLockState
- dispose()

Desired keep-awake state
- true only when:
  - lifecycle is resumed
  - app lock is not locked
  - recordingState is RecordingListening
- false for all other states
```

Production service behavior:

- `setAwake(true)` calls `WakelockPlus.toggle(enable: true)` and returns
  whether the platform request succeeded.
- `setAwake(false)` calls `WakelockPlus.toggle(enable: false)` and returns
  whether the platform request succeeded.
- Failures are logged for developer diagnostics, reported back to the
  coordinator as an unsuccessful apply, and do not surface user-facing errors
  or mutate recording state.

Coordinator behavior:

- Recomputes desired keep-awake state whenever recording, lifecycle, or app-lock
  state changes.
- Calls the service only when desired state differs from the last applied
  state.
- Serializes platform calls so overlapping lifecycle/recording transitions do
  not race each other.
- Releases keep-awake on disposal if it had been requested.
- Does not modify recording state, app-lock state, navigation, persistence, or
  backend state.

## Data model changes

No persisted data model changes are planned.

### Before

```text
No display-awake state is persisted.
RecordingControllerState.isActive is true for listening, uploading, and
processing.
MainScreen observes lifecycle only to refresh microphone permission on resume.
```

### After

```text
No display-awake state is persisted.
Ephemeral coordinator state tracks only the last requested display-awake value.
MainScreen keeps existing microphone resume behavior and additionally releases
or reacquires display-awake based on foreground listening eligibility.
```

### Migration

No migration is required.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Production display-awake service enables and disables through the wakelock boundary | Unit | `test/data/display/display_awake_service_test.dart` |
| Display-awake service logs plugin failures without throwing user-visible errors | Unit | `test/data/display/display_awake_service_test.dart` |
| Coordinator enables keep-awake for `RecordingListening` while resumed and unlocked | Unit | `test/presentation/main/recording_display_awake_coordinator_test.dart` |
| Coordinator releases keep-awake when listening transitions to uploading | Unit | `test/presentation/main/recording_display_awake_coordinator_test.dart` |
| Coordinator keeps keep-awake released for processing, idle, saved, error, and deleted states | Unit | `test/presentation/main/recording_display_awake_coordinator_test.dart` |
| Coordinator releases keep-awake when lifecycle leaves `resumed` and reacquires on resume only if still listening and unlocked | Unit | `test/presentation/main/recording_display_awake_coordinator_test.dart` |
| Coordinator releases keep-awake when app-lock becomes locked and reacquires only after unlock while still listening and foregrounded | Unit | `test/presentation/main/recording_display_awake_coordinator_test.dart` |
| Duplicate active and inactive updates do not call the display service redundantly | Unit | `test/presentation/main/recording_display_awake_coordinator_test.dart` |
| Coordinator disposal releases keep-awake after an active request and is idempotent when already released | Unit | `test/presentation/main/recording_display_awake_coordinator_test.dart` |
| `MainScreen` sends recording transitions and lifecycle events to the coordinator without breaking existing countdown or permission-resume behavior | Widget | `test/presentation/main/main_screen_test.dart` |
| `MainScreen` releases keep-awake when app-lock overlay activates | Widget | `test/presentation/main/main_screen_test.dart` |
| Main-screen recording flow enables keep-awake during listening and releases when uploading/processing/saved begins | Integration | `integration_test/main_screen_display_awake_flow_test.dart` |
| Main-screen failure flow enables keep-awake during listening and releases when upload/error begins | Integration | `integration_test/main_screen_display_awake_flow_test.dart` |
| Main-screen lifecycle/app-lock flow releases keep-awake when backgrounded or locked while listening | Integration | `integration_test/main_screen_display_awake_flow_test.dart` |

Planned focused command set:

```sh
/opt/homebrew/bin/flutter test test/data/display/display_awake_service_test.dart test/presentation/main/recording_display_awake_coordinator_test.dart test/presentation/main/main_screen_test.dart
/opt/homebrew/bin/flutter test integration_test/main_screen_display_awake_flow_test.dart
```

If the generated backend API package is missing locally, run `npm run build`
before Flutter tests as required by the backend generation guidance.

### Android emulator verification

1. Run the focused unit/widget tests.
2. Run the updated main-screen display-awake integration test on an Android
   emulator:
   `/opt/homebrew/bin/flutter test -d <android-emulator-id> integration_test/main_screen_display_awake_flow_test.dart`.
3. Launch Wrait on the Android emulator with the debug/profile package identity
   under validation.
4. Temporarily set a short Android screen timeout on the emulator where
   practical, start recording, and verify the listening timer and stop control
   remain visible beyond the ordinary timeout window.
5. Stop recording and verify Wrait transitions to upload/processing/saved or
   error while normal timeout behavior is no longer intentionally held by
   Wrait.
6. Background Wrait or trigger app-lock while listening and verify keep-awake is
   released and Wrait does not stay awake solely because recording was active.
7. Restore any emulator timeout setting changed during validation and record
   evidence in `implementation.md`.

### iOS simulator verification

1. Run the focused unit/widget tests.
2. Run the updated main-screen display-awake integration test on an iOS
   simulator:
   `/opt/homebrew/bin/flutter test -d <ios-simulator-id> integration_test/main_screen_display_awake_flow_test.dart`.
3. Launch Wrait on the iOS simulator.
4. Start recording and verify the listening timer and stop control remain
   visible while recording is active for longer than the simulator's ordinary
   idle dim/lock behavior can demonstrate.
5. Stop recording and verify Wrait transitions away from listening and no
   longer intentionally holds display-awake behavior during upload/processing.
6. Background Wrait or trigger app-lock while listening and verify keep-awake is
   released from the app's state contract.
7. Record simulator observations and any simulator-specific auto-lock limits in
   `implementation.md`.

### Validation exception request

Request approval for this validation exception as part of plan approval:

- Flutter `integration_test` can verify the app's display-awake contract through
  an injected fake service, but it cannot reliably prove that the operating
  system would have dimmed or locked the emulator/simulator absent the keep-awake
  request.
- Android emulator and iOS simulator runtime checks will still be performed and
  documented, including short-timeout/manual observation where practical. If a
  simulator does not expose reliable idle-lock behavior, validation evidence may
  document that limitation while relying on the automated state-contract tests
  plus platform launch/runtime smoke.

No exception is requested for integration coverage of the in-scope recording
flow, Android emulator execution, iOS simulator execution, or automated
idempotency/cleanup coverage.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After implementation, stop and wait for `review.md` unless the user explicitly
  skips review.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature may require a durable update to `docs/application-description.md`
  after final approval to mention that Wrait keeps the display awake only while
  foreground recording is active.
- `docs/agent-findings.md` may need validation guidance if emulator or
  simulator auto-lock behavior has important limitations.
- `AGENTS.md` likely does not need an update unless final validation uncovers a
  repeatable device/runtime command worth preserving.

## Integration notes

- `wakelock_plus: ^1.6.1` is already declared in `pubspec.yaml`; no new package
  dependency is planned.
- The existing startup and bootstrap behavior remains unchanged. Keep-awake
  wiring starts only when the main recording surface is mounted.
- `MainRecordingController` should continue to own recording, upload,
  processing, saved/error/deleted state, hard-cap stop timing, permission
  recovery, draft persistence, and cleanup orchestration.
- `MainScreen` should keep its existing resume behavior for microphone
  permission refresh while also treating non-resumed lifecycle states as
  keep-awake inactive.
- US-019 app-lock behavior remains responsible for privacy blocking. US-021 only
  reacts to lock state by releasing keep-awake.
- US-020 capture prevention remains unchanged.
- Manual power-button/device lock behavior remains outside app control by spec.

## Rollout & migration

This is an always-on runtime behavior for Android and iOS. It requires no
feature flag, backend migration, data migration, or user setting.

Existing installs receive the behavior on app update. No local journal data,
drafts, retained audio files, preferences, backend registration state, or quota
state are read, rewritten, or deleted as part of rollout.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Keep-awake accidentally remains enabled after recording stops | Medium | High | Centralize desired-state computation, release on every non-listening state, add disposal/lifecycle/app-lock tests. |
| Uploading or processing incorrectly keeps the screen awake because existing `isActive` is reused | Medium | Medium | Do not use `RecordingControllerState.isActive` for this feature; explicitly match `RecordingListening`. |
| App-lock and main-screen lifecycle observers race during background/foreground transitions | Medium | Medium | Coordinator recomputes from both lifecycle and app-lock state and releases on either inactive input; tests cover lifecycle and lock transitions. |
| Static plugin calls make tests brittle | Medium | Medium | Wrap `wakelock_plus` in an injectable service/client and test the coordinator with fakes. |
| Wakelock plugin failure interrupts recording | Low | High | Log failures and do not propagate them into recording state or UI. |
| Simulator auto-lock behavior is difficult to observe consistently | Medium | Low | Use automated fake-service integration for the app contract and document emulator/simulator runtime observations and limitations. |
| MainScreen disposal misses release when navigating away while listening | Low | High | Release from coordinator disposal and add widget/unit coverage for disposal cleanup. |

## Open items from spec

None. The plan carries forward the clarified choices:

- keep-awake only while foreground listening/recording
- upload, processing, cleanup, background, and app-lock states are inactive
- manual lock/power-button/system power behavior may override keep-awake
