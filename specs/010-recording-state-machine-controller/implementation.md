# Implementation Notes: Recording State Machine and Controller

> **Feature number:** 010
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-12

---

## Summary

US-009 is implemented as a new app-facing Best-mode recording controller layered
over the existing cloud transcription service, transcript cleanup use case,
entry repository, preferences repository, and Riverpod provider graph.

Implemented behavior:

- app-facing recording state model with `Idle`, `Listening`, `Uploading`,
  `Processing`, `Saved(entryId, detectedLanguage?)`, `Error(error)`, and
  `Deleted(count)`
- derived `isActive` surface that is true only for `Listening`, `Uploading`,
  and `Processing`
- single-button controller transitions for Idle, Listening, Uploading,
  Processing, Saved, Deleted, and Error states
- TooShort and NoMatch shake-trigger support through `shakeErrorKey`
- three-second controller-owned auto-clear for Error and Deleted states
- UI-owned Saved clearing through explicit `clearSaved()`
- Best-mode orchestration from live transcription start/stop through cleanup
  finalization and Saved state publication
- retryable audio-draft persistence when live transcription fails after audio
  capture
- `hasEverRecorded` persistence after successful saved-entry finalization

## Key implementation details

- Added [recording_state.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/main/recording_state.dart:1).
  - defines the app-facing recording state union
  - defines `RecordingError`
  - defines `RecordingControllerState` with `shakeErrorKey` and `isActive`
- Added [main_recording_controller.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/main/main_recording_controller.dart:1).
  - defines `mainRecordingControllerProvider`
  - composes `transcriptionServiceProvider`, `cleanupTranscriptUseCaseProvider`,
    `entryRepositoryProvider`, `preferencesRepositoryProvider`, and
    `monotonicClockProvider`
  - implements button-tap transitions, deletion feedback, Saved clearing, and
    timer cancellation rules
  - maps transcription and cleanup failures into UI-facing
    `RecordingError` values
  - persists retryable audio drafts with the existing supported fallback
    language when cloud transcription returns an `audioDraftPath`
- Updated [transcription_service.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/transcription/transcription_service.dart:1).
  - adds `tooShort`, `nothingCaught`, and `micBlocked` to
    `TranscriptionFailureReason`
  - adds `MicBlockedTranscriptionServiceFailure` for future start-time
    permission mapping
- Updated [cloud_transcription_service.dart](/Users/alexander/projects/wrait/write-flutter/lib/data/transcription/cloud_transcription_service.dart:1).
  - converts `RecordingTooShortFailure` from the audio layer into
    `TranscriptionFailureReason.tooShort`
  - converts nominal transcription successes with blank transcript text into
    `TranscriptionFailureReason.nothingCaught`
  - preserves retryable live audio on that blank-transcript failure path
- Added [main_recording_controller_test.dart](/Users/alexander/projects/wrait/write-flutter/test/presentation/main/main_recording_controller_test.dart:1).
  - covers button transitions, active-state rules, timer behavior,
    failure mapping, audio-draft persistence, cleanup success/failure, and
    `hasEverRecorded`
- Updated [cloud_transcription_service_test.dart](/Users/alexander/projects/wrait/write-flutter/test/data/transcription/cloud_transcription_service_test.dart:1).
  - covers typed too-short live-stop failures
  - covers `nothingCaught` mapping for blank live/draft transcription results
- Added [main_recording_controller_flow_test.dart](/Users/alexander/projects/wrait/write-flutter/integration_test/main_recording_controller_flow_test.dart:1).
  - uses the real encrypted local database, real preferences store, real
    cleanup use case wiring, and a fake transcription service
  - validates success, audio-draft failure, text-draft cleanup failure, and
    second-recording-after-Saved behavior on Android and iOS

## Validation evidence

### Static and unit validation

```text
$ /opt/homebrew/bin/flutter analyze
No issues found!

$ /opt/homebrew/bin/flutter test
All tests passed.
```

### Provider-graph integration validation

```text
$ /opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart -d emulator-5554
All tests passed.

$ /opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156
All tests passed.
```

## Follow-up notes

- Android integration builds still emit the previously known Kotlin Gradle
  plugin warnings for third-party plugins; they did not block validation.
- US-010 network preflight remains intentionally out of scope and was not
  implemented here.
- Offline-mode routing remains intentionally out of scope and was not
  implemented here.

## Review remediation

An external review pass requested tighter controller hardening around invalid
Saved-state identifiers, retryable audio-draft path validation, and
rapid-transition timer/button races. The approved remediation was implemented
without expanding the story scope.

Remediation changes:

- Updated [recording_state.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/main/recording_state.dart:1)
  so `RecordingSaved` rejects non-positive `entryId` values at runtime.
- Updated [main_recording_controller.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/main/main_recording_controller.dart:1)
  so cleanup success with a missing or non-positive `entryId` logs a warning,
  emits `RecordingError.apiFailed`, and does not set `hasEverRecorded`.
- Updated [main_recording_controller.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/main/main_recording_controller.dart:1)
  so retryable `audioDraftPath` values are trimmed and verified as existing
  files before draft persistence; invalid paths are ignored without masking the
  original transcription error.
- Expanded [main_recording_controller_test.dart](/Users/alexander/projects/wrait/write-flutter/test/presentation/main/main_recording_controller_test.dart:1)
  with coverage for invalid cleanup entry ids, invalid/missing retryable audio
  paths, rapid repeated start taps, and stale Error/Deleted auto-clear timer
  cancellation.
- Updated [main_recording_controller_flow_test.dart](/Users/alexander/projects/wrait/write-flutter/integration_test/main_recording_controller_flow_test.dart:1)
  to create a real retryable audio file before verifying audio-draft
  persistence, aligning the integration harness with the stricter controller
  validation.

### Review-remediation validation evidence

```text
$ /opt/homebrew/bin/flutter analyze
No issues found! (ran in 2.5s)

$ /opt/homebrew/bin/flutter test
All tests passed! (137 tests)

$ /opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart -d emulator-5554
All tests passed on Android emulator sdk gphone16k arm64 (emulator-5554).

$ /opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156
All tests passed on iOS simulator iPhone 17 (491CD949-D3C0-4C4C-A6B9-15BAB1859156).
```
