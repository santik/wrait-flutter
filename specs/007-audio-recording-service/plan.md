# Implementation Plan: Audio Recording Service

> **Feature number:** 007
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-10

---

## Approach summary

Implement US-006 as a reusable app-facing recording service layered over the
existing `record` dependency. The service will own recorder lifecycle,
active-session state, minimum-duration validation, and exposure of a monotonic
hard-cap deadline, but it will not own the later process orchestration that
transcribes, cleans up, saves drafts, or decides when to delete completed
files. Instead, the service will expose enough signal for a future process
orchestrator to start capture with a caller-chosen temp-file path, stop on a
UI command before the cap, and also stop automatically when the exposed
deadline is reached so the orchestrator receives the completed file path
itself.

This approach satisfies the approved spec by centralizing capture behavior,
preventing competing sessions, enforcing the 5-second minimum before any file
is handed downstream, and keeping audio file lifecycle ownership with the
later success/retry flows that already need it. Validation will combine unit
tests, fake-driven `integration_test` coverage for all in-scope service flows,
and explicit Android emulator plus iOS simulator runtime verification with
real recording output.

Within the broader product flow in `plan/functionality.md`, this story
establishes the reusable capture layer for the Best-mode "record audio file ->
transcribe -> cleanup" path. User-visible TooShort messaging, countdown-ring
rendering, and the Offline-mode speech-recognition path remain outside this
story and will be handled by later orchestration and UI stories.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| App-facing boundary | Add one recording-service contract for `startRecording`, `stopRecording`, `isRecording`, and `hardCapDeadlineElapsedRealtime` | Later orchestration stories need one reusable capture surface instead of plugin calls spread across controllers or UI. |
| Layer placement | Keep the plugin-backed implementation in `lib/data/audio/` and expose only an app-facing abstraction upward | This follows the repo guidance to keep plugin-specific code in `data` while still giving later use cases a stable contract. |
| Recorder implementation | Use the existing `record` package with AAC-in-M4A output configured for mono, 16 kHz speech capture | The package is already in the project, is cross-platform, and AAC/M4A is a standard playable format with a lower integration cost than introducing a second recording stack. |
| Output-path ownership | Keep `startRecording(outputPath)` caller-supplied and let the future process orchestrator choose the temp-file path | This matches the story reference contract and keeps file naming/lifecycle decisions with the higher-level flow that later transcribes or preserves drafts. |
| Hard-cap enforcement | The service computes and exposes a monotonic deadline, while the future process orchestrator owns the timer that calls `stopRecording()` at the cap | This matches the clarified requirement that the orchestrator should receive the completed file when the cap is reached. |
| Monotonic time source | Add a lightweight monotonic clock abstraction in `lib/core/time/` backed by an in-process stopwatch | The spec requires an elapsed-realtime-style deadline for countdown behavior, and a monotonic abstraction keeps deadline math deterministic without relying on wall-clock time. |
| Session bookkeeping | Store the active output path, active-session start time, and active hard-cap deadline inside the service | These are the minimum state pieces needed to reject concurrent starts, validate minimum duration, and stop cleanly. |
| Minimum-duration handling | Treat recordings shorter than 5 seconds as a typed invalid-stop outcome and delete the too-short file before returning control | The approved spec says sub-5-second captures are invalid and must not enter downstream processing. |
| Inactive-stop handling | Treat `stopRecording()` with no active session as a typed failure | The clarified spec explicitly requires stop to fail when no recording is active, including after a cap-driven stop already happened. |
| File lifecycle ownership after stop | The recording service stops owning the file once it returns a successful path; later consumers delete it on downstream success or keep it for retry drafts | This aligns the story’s lifecycle rules with later transcription/draft stories and avoids duplicating cleanup policy inside the capture layer. |
| Test seam | Introduce a small recorder-adapter seam around the plugin for unit and fake-driven integration coverage | The real plugin cannot be exercised deterministically in unit tests, and the repo requires integration coverage for in-scope flows. |
| Validation approach | Cover service flows with fake-driven integration tests plus focused unit tests, then prove real microphone capture on Android and iOS manually | This provides deterministic automation for behavior while still satisfying the story’s real cross-platform recording acceptance criteria. |
| Validation exception | None requested | The story can satisfy the default `integration_test` requirement and dual-platform runtime verification without an exception. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/core/time/monotonic_clock.dart` | Create | Add the app-facing monotonic clock abstraction and default stopwatch-backed implementation used for deadline math |
| `lib/data/audio/audio_recording_service.dart` | Create | Define the app-facing recording contract and typed failure surface for invalid start/stop conditions |
| `lib/data/audio/record_audio_recording_service.dart` | Create | Implement the recording service with the `record` package, session bookkeeping, min-duration validation, and too-short file cleanup |
| `lib/data/audio/audio_recording_providers.dart` | Create | Wire Riverpod providers for the monotonic clock, the recorder adapter, and the app-facing recording service |
| `test/data/audio/audio_recording_service_test.dart` | Create | Unit coverage for concurrent-start rejection, deadline generation, successful stop, too-short invalidation, inactive-stop failure, and file handling |
| `test/test_doubles/fake_monotonic_clock.dart` | Create | Deterministic fake monotonic clock for deadline and elapsed-duration tests |
| `integration_test/audio_recording_service_flow_test.dart` | Create | Fake-driven integration coverage for start/stop, cap-driven orchestrator stop, and invalid short-recording behavior through the real provider graph |
| `specs/007-audio-recording-service/implementation.md` | Create later | Record implementation details and validation evidence during the implementation phase |

## API contract details

Implementation-specific rules on top of the approved spec:

- The app-facing service will expose the story reference methods:
  - `Future<void> startRecording(String outputPath)`
  - `Future<String> stopRecording()`
  - `bool get isRecording`
  - `int? get hardCapDeadlineElapsedRealtime`
- `startRecording(outputPath)` will:
  - reject blank output paths
  - reject requests when a recording session is already active
  - configure the recorder for one audio channel and 16 kHz speech-oriented
    capture
  - store the caller-supplied output path, current monotonic start time, and
    `hardCapDeadlineElapsedRealtime = monotonicNow + recordingHardCapMs`
- `stopRecording()` will:
  - fail when no recording session is active
  - stop the underlying recorder
  - compute the recorded duration from the stored monotonic start time
  - delete the produced file and fail if the duration is under 5 seconds
  - return the completed file path only for a valid recording
- The service itself will not create timers for the hard cap. Later
  orchestration is expected to observe `hardCapDeadlineElapsedRealtime` and
  call `stopRecording()` when that deadline is reached.
- Once `stopRecording()` returns a valid path, the service will clear all
  active-session state and leave future deletion/retention decisions to later
  consumers.
- Detailed categorization of start failures caused by permissions or hardware
  availability remains intentionally narrow in this story and can be expanded
  by later permission/orchestration stories if needed.
- The typed too-short failure from this service is the signal that later UI
  and state-machine stories will map to the product copy
  `"too short · keep talking"` and shake behavior described in
  `plan/functionality.md`.

## Data model changes

This story adds transient in-memory capture state only. It does not change the
entry database or preferences schema.

### Before

```dart
// No shared Flutter audio-recording service exists yet.
// The app has recording-related config and placeholder UI, but no reusable
// capture contract or monotonic hard-cap deadline surface.
```

### After

```dart
abstract interface class AudioRecordingService {
  bool get isRecording;
  int? get hardCapDeadlineElapsedRealtime;

  Future<void> startRecording(String outputPath);
  Future<String> stopRecording();
}

sealed class AudioRecordingFailure implements Exception {
  const AudioRecordingFailure();
}

final class RecordingAlreadyInProgressFailure extends AudioRecordingFailure {}
final class NoActiveRecordingFailure extends AudioRecordingFailure {}
final class RecordingTooShortFailure extends AudioRecordingFailure {}
```

### Migration

No migration is required.

## Test strategy

Validation will cover three levels:

- unit coverage for service state transitions, deadline math, invalid-stop
  behavior, and file handling through deterministic fakes
- fake-driven `integration_test` coverage through the real provider graph,
  including an orchestrator-style timer harness that stops at the hard cap
- Android emulator and iOS simulator runtime verification with the real
  microphone and actual output files to prove cross-platform capture works

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Starting a recording session marks the service active and exposes a hard-cap deadline derived from the configured max duration | Integration | `integration_test/audio_recording_service_flow_test.dart` |
| A caller can stop an active recording after 5 seconds and receive a completed file path | Integration | `integration_test/audio_recording_service_flow_test.dart` |
| An orchestrator-style cap timer can observe the deadline and stop the recording automatically at the hard cap, receiving the completed file path itself | Integration | `integration_test/audio_recording_service_flow_test.dart` |
| Stopping before 5 seconds produces an invalid-recording failure and prevents the file from entering downstream use | Integration | `integration_test/audio_recording_service_flow_test.dart` |
| `startRecording()` rejects a blank output path before touching the recorder | Unit | `test/data/audio/audio_recording_service_test.dart` |
| `startRecording()` rejects a second concurrent start request while leaving the first recording active | Unit | `test/data/audio/audio_recording_service_test.dart` |
| `startRecording()` requests mono 16 kHz AAC-in-M4A capture from the recorder adapter | Unit | `test/data/audio/audio_recording_service_test.dart` |
| `stopRecording()` clears active-session state and returns the file path for a valid recording | Unit | `test/data/audio/audio_recording_service_test.dart` |
| `stopRecording()` deletes the produced file and throws a too-short failure for recordings under 5 seconds | Unit | `test/data/audio/audio_recording_service_test.dart` |
| `stopRecording()` fails when no recording session is active | Unit | `test/data/audio/audio_recording_service_test.dart` |
| The configured hard cap drives the exposed monotonic deadline for each session | Unit | `test/data/audio/audio_recording_service_test.dart` |
| `flutter analyze` completes cleanly after the new audio service and provider wiring are added | Static analysis | Command evidence recorded in `tasks.md` |
| `flutter test` passes after the new audio-service unit coverage is added | Test suite | Command evidence recorded in `tasks.md` |

### Android emulator verification

1. Launch the app on an Android emulator and verify startup still succeeds with
   the new recording-service dependency wiring in place.
2. Run `integration_test/audio_recording_service_flow_test.dart` on the Android
   emulator to validate the in-scope service flows through the real provider
   graph.
3. Add a temporary manual verification harness during implementation, record
   one valid capture on the Android emulator, stop it before the cap, and
   confirm the produced file exists and is playable through standard Android
   media tooling or host inspection.
4. Repeat manual verification with a cap-driven stop to confirm the
   orchestrator-owned hard-cap flow yields a completed file.
5. Record the emulator target and passing command evidence in `tasks.md`.

### iOS simulator verification

1. Launch the app on an iOS simulator and verify startup still succeeds with
   the new recording-service dependency wiring in place.
2. Run `integration_test/audio_recording_service_flow_test.dart` on the iOS
   simulator to validate the in-scope service flows through the real provider
   graph.
3. Add a temporary manual verification harness during implementation, record
   one valid capture on the iOS simulator, stop it before the cap, and confirm
   the produced file exists and is playable through standard iOS or host media
   tooling.
4. Repeat manual verification with a cap-driven stop to confirm the
   orchestrator-owned hard-cap flow yields a completed file.
5. Record the simulator target and passing command evidence in `tasks.md`.

### Validation exception request

No exception requested.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This story is likely to produce durable follow-up for
  `docs/agent-findings.md` around the monotonic deadline pattern, recorder
  plugin boundaries, and file-lifecycle ownership between capture and later
  orchestration.

## Integration notes

- The new recording service will consume:
  - `AppConfig.recordingHardCapMs` from
    [lib/core/config/app_config.dart](/Users/alexander/projects/wrait/write-flutter/lib/core/config/app_config.dart)
  - the existing `record` package already declared in
    [pubspec.yaml](/Users/alexander/projects/wrait/write-flutter/pubspec.yaml)
  - temp-directory/file path choices supplied by higher-level callers
- Later stories such as the recording process orchestrator and cloud
  transcription should depend on the app-facing recording service instead of
  calling the plugin directly.
- Per `plan/functionality.md`, this service is the capture foundation for the
  Best-mode file-upload flow. Offline-mode speech recognition remains a later,
  separate path and is intentionally not coupled into this service contract.
- The orchestrator integration expected by the approved clarification is:
  - the orchestrator starts recording with a chosen temp-file path
  - the orchestrator watches `hardCapDeadlineElapsedRealtime`
  - the orchestrator stops on either user command or hard-cap timer expiry
  - the orchestrator then hands the successful file path to transcription and
    cleanup flows
- The entry repository’s existing best-effort audio-file deletion remains the
  right downstream cleanup mechanism for draft and entry lifecycle stories;
  this recording story should not duplicate that policy in the capture layer.

## Rollout & migration

This is an additive infrastructure story.

- No feature flag is needed.
- No local data migration is needed.
- The main rollout concern is accidental coupling between capture and later
  orchestration behavior; keeping the hard-cap timer outside the service
  contains that risk.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Real devices or simulators produce a file format or sample configuration that differs from the requested speech-oriented settings | Medium | High | Configure the plugin explicitly for mono 16 kHz AAC capture, add unit coverage around requested config values, and verify real output on both platforms during manual runtime checks |
| Deadline math becomes unstable if wall-clock time is used | Medium | High | Use a dedicated monotonic clock abstraction and deterministic fake clock coverage rather than `DateTime.now()` |
| Hard-cap ownership leaks into the recording service and makes later orchestration awkward | Medium | Medium | Keep the service limited to exposing the deadline and leave timer-driven stop orchestration to the later controller/use-case layer |
| Too-short recordings leave stray temporary files behind | Medium | Medium | Delete the file as part of the invalid-stop path and verify that behavior in unit tests |
| The fake test seam diverges from the real recorder plugin behavior | Low | Medium | Keep the seam as thin as possible, validate the requested recorder configuration in unit tests, and backstop it with Android/iOS manual runtime verification |
| Provider wiring makes future orchestration harder to compose | Low | Medium | Centralize service construction in one provider file and keep the app-facing contract small and dependency-light |

## Open items from spec

None.
