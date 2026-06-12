# Implementation Plan: Recording State Machine and Controller

> **Feature number:** 010
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-12

---

## Approach summary

Implement US-009 as one app-facing main recording controller that composes the
existing Best-mode cloud transcription service, transcript cleanup use case,
entry repository, preferences repository, and monotonic clock. The controller
will expose a reactive state object for UI binding, own the accepted
single-button transition rules, prevent overlapping active pipelines, map
lower-level failures into the approved recording error categories, persist
audio drafts when live transcription fails after audio capture, call cleanup
for successful raw transcripts, set `hasEverRecorded` only after a fully
successful saved entry, and automatically clear Error/Deleted feedback after
three seconds. Saved feedback will stay visible until UI clears it or the user
starts another recording. Validation will combine deterministic controller
unit tests, fake-driven provider-graph `integration_test` coverage for every
in-scope flow, and Android emulator plus iOS simulator integration-test runs.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| App-facing boundary | Add a `MainRecordingController` under `lib/presentation/main/` with a Riverpod provider and public methods for `onMainButtonTapped`, `clearSaved`, `resetToIdle`, and `onEntriesDeleted` | The story is UI-facing orchestration, not a backend or persistence primitive. A presentation controller gives later main-screen UI one stable binding point while keeping the current data/domain services reusable. |
| State model | Add explicit `RecordingState`, `RecordingError`, and `RecordingControllerState` types under `lib/presentation/main/` | The approved spec needs a union-style state, derived `isActive`, and a shake counter. A small app-facing model avoids leaking backend, audio, or cleanup result types into UI code. |
| Reactivity | Use `NotifierProvider<MainRecordingController, RecordingControllerState>` | The repo already uses Riverpod providers, and a `Notifier` naturally exposes immutable state plus imperative user-action methods without introducing a second state-management style. |
| Active pipeline guard | Treat Listening, Uploading, and Processing as active states and ignore button taps during Uploading/Processing | This directly matches the spec and prevents duplicate transcription/cleanup jobs. |
| Start behavior | On Idle/Saved/Deleted/retryable Error, call `TranscriptionService.startLiveTranscription()` and enter Listening when the service emits `RecordingStarted` | US-010 owns network preflight and Offline is out of scope, so US-009 starts the Best-mode live service directly and leaves later stories to add preflight before this boundary. |
| Minimum duration | Store the monotonic start timestamp on `RecordingStarted`, check it on stop, and rely on the transcription service to clean up too-short audio when stopped | The audio service already owns hard minimum invalidation and file deletion. The controller still performs the transition decision and shake behavior while avoiding duplicated file handling. |
| Transcription failure expansion | Extend `TranscriptionFailureReason` with `tooShort`, `nothingCaught`, and `micBlocked`; map `RecordingTooShortFailure` to `tooShort` and blank cloud success transcripts to `nothingCaught` | The current Flutter service only exposes backend-shaped failures, but the controller spec needs Android-equivalent `TooShort`/`NoMatch`/permission categories without depending on thrown implementation errors. |
| Upload/processing phases | Map transcription `Uploading` status to RecordingState.Uploading and set RecordingState.Processing while cleanup/finalization is running | The existing transcription service emits upload status only. Cleanup is the next processing phase, so the controller owns that transition. |
| Cleanup integration | Call `CleanupTranscriptUseCase` with the raw transcript and detected language from successful transcription | The use case already persists/finalizes the text draft for Best mode, applies cleanup input limits, updates quota, and returns the affected entry id. |
| Successful save side effect | Call `PreferencesRepository.setHasEverRecorded(true)` after cleanup success and before publishing Saved; log and continue to Saved if the preference write fails | The feature requires setting the flag after success, but a preference write failure should not hide an already persisted entry from the user. |
| Audio draft persistence | If live transcription fails with an `audioDraftPath`, call `EntryRepository.saveAudioDraft(audioPath, 'en-US')` before publishing the mapped Error | The cloud transcription service retains the file but intentionally leaves draft ownership to callers. Best-mode failure has no reliable detected language, so the existing cleanup fallback language is the safest supported value until later retry work improves metadata. |
| Failure mapping | Map transcription `tooShort` to `RecordingError.tooShort`, `nothingCaught` to `noMatch`, `micBlocked` to `insufficientPermissions`, `network`/`timeout` to `noInternet`, `backendUnavailable` to `backendUnavailable`, `proxyAuthFailed` to `proxyAuthFailed`, and `apiError` to `apiFailed`; map cleanup `noInternet`/`timeout` to `noInternet`, `backendUnavailable` to `backendUnavailable`, `proxyAuthFailed` to `proxyAuthFailed`, and all other cleanup failures to `apiFailed` | This follows the approved Android-controller mapping while adapting to the existing Flutter backend result enums. |
| Shake behavior | Increment `shakeErrorKey` exactly when publishing `tooShort` or `noMatch` | A counter lets later UI retrigger shake even when repeated failures have the same visible state. |
| Auto-clear behavior | Schedule a cancellable controller-owned timer for Error and Deleted states using injectable `RecordingFeedbackDelays`; do not auto-clear Saved | Error/Deleted timers are in scope for the controller. Saved is explicitly UI-owned, and injectable durations make tests deterministic without waiting three real seconds. |
| Deletion feedback | Add `onEntriesDeleted(count)` that ignores non-positive counts, publishes Deleted(count), and schedules the three-second clear | Later list/detail stories can call this without needing to know timer behavior. |
| Countdown state | Do not introduce a countdown UI state in this story | The approved US-009 spec centers on recording pipeline state and active status. Countdown rendering belongs to US-011 main-screen UI and can read hard-cap behavior from the existing transcription/audio services when planned. |
| Storage migration | None | The story reuses existing entry/draft persistence and preferences fields. |
| Validation exception | None requested | The feature can satisfy provider-graph integration coverage and dual-platform verification. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/presentation/main/recording_state.dart` | Create | Define `RecordingState`, `RecordingError`, `RecordingControllerState`, active-state derivation, and equality-friendly value semantics for tests/UI |
| `lib/presentation/main/main_recording_controller.dart` | Create | Implement the Riverpod `MainRecordingController`, provider wiring, button/deletion/clear actions, Best-mode orchestration, failure mapping, shake counter, and feedback timers |
| `lib/data/transcription/transcription_service.dart` | Modify | Extend `TranscriptionFailureReason` with controller-relevant `tooShort`, `nothingCaught`, and `micBlocked` values |
| `lib/data/transcription/cloud_transcription_service.dart` | Modify | Convert too-short live stop and blank transcript success into typed transcription failures instead of leaking lower-level exceptions or generic API failure |
| `test/presentation/main/main_recording_controller_test.dart` | Create | Unit coverage for button transitions, active guards, timers, shake behavior, failure mapping, audio-draft persistence, cleanup success/failure, and has-ever-recorded behavior |
| `test/data/transcription/cloud_transcription_service_test.dart` | Modify | Add/adjust coverage for typed too-short and blank-transcript/NoMatch transcription failures |
| `integration_test/main_recording_controller_flow_test.dart` | Create | Provider-graph integration coverage for the in-scope Best-mode controller flows using fake transcription and cleanup callbacks plus real repository/preference wiring where practical |
| `specs/010-recording-state-machine-controller/implementation.md` | Create later | Record implementation details and validation evidence during the implementation phase |

## API contract details

No backend HTTP endpoint changes are planned.

The app-facing controller contract will expose:

```dart
final mainRecordingControllerProvider =
    NotifierProvider<MainRecordingController, RecordingControllerState>(...);

class RecordingControllerState {
  final RecordingState recordingState;
  final int shakeErrorKey;
  bool get isActive;
}

sealed class RecordingState {
  const RecordingState();
}

final class RecordingIdle extends RecordingState {}
final class RecordingListening extends RecordingState {}
final class RecordingUploading extends RecordingState {}
final class RecordingProcessing extends RecordingState {}
final class RecordingSaved extends RecordingState {
  final int entryId;
  final String? detectedLanguage;
}
final class RecordingErrorState extends RecordingState {
  final RecordingError error;
}
final class RecordingDeleted extends RecordingState {
  final int count;
}

enum RecordingError {
  tooShort,
  noMatch,
  insufficientPermissions,
  noInternet,
  backendUnavailable,
  proxyAuthFailed,
  apiFailed,
}
```

Controller methods:

- `Future<void> onMainButtonTapped()`
  - Idle/Saved/Deleted/retryable Error starts a new independent live
    Best-mode recording attempt.
  - Listening stops the current live attempt and continues the pipeline.
  - Uploading/Processing is ignored.
  - Insufficient-permissions Error resets to Idle.
- `void clearSaved()`
  - Clears Saved to Idle for the later UI-owned four-second timer.
  - Does nothing if the current state is not Saved.
- `void resetToIdle()`
  - Clears any pending timer and returns the observable state to Idle.
- `void onEntriesDeleted(int count)`
  - Emits Deleted(count) for positive counts and schedules three-second clear.

Failure-handling details:

- Transcription failures with audio draft paths will first attempt
  `EntryRepository.saveAudioDraft(path, cleanupTranscriptFallbackLanguage)`
  only after validating that the trimmed path points to an existing file;
  invalid paths and draft persistence errors will be logged but will not
  replace the original recording error.
- Cleanup success returns the entry id to publish through `RecordingSaved`;
  missing or non-positive ids are treated as `ApiFailed` and do not set
  `hasEverRecorded`.
- Cleanup failure preserves the draft through the existing cleanup use case and
  publishes the mapped Error state.
- `setHasEverRecorded(true)` runs only after cleanup success; failures while
  writing that preference are logged and do not prevent Saved from being
  published.
- Error and Deleted timers are cancelled when a newer state transition occurs
  so stale timers cannot reset an active or newer terminal state.

## Data model changes

No persistent database schema changes are planned.

### Before

```text
No app-facing recording controller state exists.

TranscriptionFailureReason:
  network
  timeout
  backendUnavailable
  proxyAuthFailed
  apiError
```

### After

```text
Runtime-only recording controller state:
  recordingState
  shakeErrorKey
  isActive

TranscriptionFailureReason:
  tooShort
  nothingCaught
  micBlocked
  network
  timeout
  backendUnavailable
  proxyAuthFailed
  apiError
```

### Migration

No migration is required.

The feature reuses:

- existing entry rows for finalized entries and drafts
- existing `hasEverRecorded` preference
- existing session quota updates performed by transcription and cleanup

## Test strategy

Validation will cover the controller at two levels:

- unit tests with fake transcription, cleanup, entry, preferences, clock, and
  timer durations for deterministic state-machine coverage
- fake-driven `integration_test` coverage through Riverpod providers, the real
  local entry repository/database, and SharedPreferences-backed preferences
  where practical

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Idle button tap starts Best-mode live recording and publishes Listening when recording starts | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Listening stop before five seconds publishes TooShort, increments `shakeErrorKey` exactly once, and auto-clears to Idle | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Listening stop after five seconds publishes Uploading, then Processing, then Saved with entry id and detected language after transcription and cleanup success | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Uploading and Processing button taps are ignored and do not start another pipeline | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Saved, Deleted, and retryable Error button taps start a new independent recording attempt without mutating a previously saved entry | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Insufficient-permissions Error button tap resets to Idle instead of starting immediately | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Transcription failure mapping covers TooShort, NoMatch, NoInternet, BackendUnavailable, ProxyAuthFailed, and ApiFailed | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Transcription failure with `audioDraftPath` persists an audio draft using the supported fallback language before publishing Error | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Transcription failure with a blank or invalid `audioDraftPath` preserves the original Error outcome and skips draft persistence | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Cleanup failure preserves the draft created by `CleanupTranscriptUseCase`, publishes the mapped Error, and does not set `hasEverRecorded` | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Cleanup success sets `hasEverRecorded` and publishes Saved even if the preference write logs a warning | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Cleanup success with a missing or non-positive entry id publishes `ApiFailed` and does not set `hasEverRecorded` | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Deleted feedback ignores non-positive counts, publishes positive counts, and auto-clears after the configured delay | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Saved feedback does not auto-clear from the controller but clears when `clearSaved()` is called | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Rapid repeated taps while start is still in flight trigger only one start attempt | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Starting a new recording cancels stale Error and Deleted auto-clear timers so they cannot reset newer states | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Blank cloud transcription success becomes `TranscriptionFailureReason.nothingCaught` and keeps retryable live audio when applicable | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Too-short live audio stop becomes `TranscriptionFailureReason.tooShort` without upload | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Provider graph completes the Best-mode success path from controller tap start/stop through transcription, cleanup, finalized entry persistence, session quota update, and `hasEverRecorded` | Integration | `integration_test/main_recording_controller_flow_test.dart` |
| Provider graph preserves an audio draft and emits mapped Error when live transcription fails after capture | Integration | `integration_test/main_recording_controller_flow_test.dart` |
| Provider graph preserves a text draft and emits mapped Error when cleanup fails after transcription success | Integration | `integration_test/main_recording_controller_flow_test.dart` |
| Provider graph supports starting another recording after Saved while the first saved entry remains persisted | Integration | `integration_test/main_recording_controller_flow_test.dart` |
| `flutter analyze` completes cleanly after controller wiring is added | Static analysis | Command evidence recorded in `tasks.md` |
| `flutter test` passes after controller coverage is added | Test suite | Command evidence recorded in `tasks.md` |

### Android emulator verification

1. Run `integration_test/main_recording_controller_flow_test.dart` on an
   Android emulator using fake transcription/cleanup callbacks and real local
   repository/preference wiring.
2. Verify the Android run covers:
   - Best-mode success through Saved and persisted finalized entry
   - transcription failure through audio-draft persistence and Error
   - cleanup failure through text-draft preservation and Error
   - second recording after Saved preserving the first entry
3. Record the emulator target and passing command evidence in `tasks.md`.

### iOS simulator verification

1. Run `integration_test/main_recording_controller_flow_test.dart` on an iOS
   simulator using fake transcription/cleanup callbacks and real local
   repository/preference wiring.
2. Verify the iOS run covers:
   - Best-mode success through Saved and persisted finalized entry
   - transcription failure through audio-draft persistence and Error
   - cleanup failure through text-draft preservation and Error
   - second recording after Saved preserving the first entry
3. Record the simulator target and passing command evidence in `tasks.md`.

### Validation exception request

No exception requested.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates to
  `docs/application-description.md` and `docs/agent-findings.md` after final
  approval because it introduces the main recording controller and app-facing
  recording state model.
- An `AGENTS.md` update is not expected unless implementation reveals new
  recurring guidance for future controller/UI stories.

## Integration notes

- US-010 will add concrete Best-mode network availability preflight before
  recording starts. The controller should stay easy to extend with that check
  without changing its public UI-facing state model.
- Later permission UI work can map platform permission outcomes into
  `RecordingError.insufficientPermissions` through the same controller state
  model.
- Later Offline-mode work can add a separate route through this controller or
  an adjacent controller branch, but US-009 deliberately keeps Offline out of
  scope.
- Later main-screen UI work will bind button labels, alpha, shake animation,
  status text, and Saved clear timing to `RecordingControllerState`.
- Later entry-list/detail work will call `onEntriesDeleted(count)` after
  successful deletion.

## Rollout & migration

No data migration or feature flag is required.

The new controller is additive until later UI work starts consuming it. Existing
placeholder screens and lower-level service tests should continue to behave as
they do today.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Controller and cloud transcription service both try to own too-short behavior | Medium | Medium | Let the controller decide the visible transition while the transcription/audio services continue to own stopping and deleting invalid audio; cover both with unit tests. |
| Stale auto-clear timers reset a newer active state | Medium | High | Cancel existing timers on every new transition and only clear when the current state still matches an auto-clearable terminal state. |
| Audio draft persistence failure hides the original transcription error | Low | Medium | Treat draft persistence as best-effort logging and publish the original mapped transcription error. |
| Preference persistence failure after cleanup success prevents Saved feedback | Low | Medium | Log preference failures and still publish Saved because the entry has already been persisted/finalized. |
| Provider-graph integration tests become too close to UI tests before UI exists | Low | Low | Keep integration tests provider-driven and fake service callbacks; US-011 will add actual UI interaction coverage. |
| Adding new transcription failure enum values regresses existing failure mappings | Medium | Medium | Update cloud transcription service tests and keep existing backend failure mappings unchanged. |

## Open items from spec

None.
