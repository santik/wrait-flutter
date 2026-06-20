# Implementation: Draft Retry System

> **Feature number:** 015
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-19

## Summary

US-015 is implemented as launch-only background work for the app's single
cloud-backed recording flow. On launch, device registration now returns an
explicit success/failure result, and a new launch-work coordinator retries
pending drafts only after successful registration. Retryable launch work stays
fire-and-forget from the UI's perspective, so startup remains non-blocking and
successful retries surface only through the existing entry list, detail, and
stats views.

## Implemented behavior

- Added `LaunchDeviceRegistrationResult` so launch registration can signal
  success or failure without changing the existing swallowed-error and quota
  update behavior.
- Added `AppLaunchWorkUseCase` to sequence registration and retry once per
  launch with a single-flight guard.
- Added `RetryPendingDraftsUseCase` to:
  - delete stale drafts before retry
  - load pending drafts newest-first
  - validate retained audio files before retrying audio drafts
  - delete malformed audio drafts whose retained files are blank, missing,
    unreadable, or empty
  - retry audio drafts through transcription, then retry cleanup with the same
    draft id
  - preserve audio drafts on transcription failure, including quota and proxy
    authentication failures
  - promote successfully transcribed audio drafts to text drafts when cleanup
    fails, then delete the retained audio file best-effort
  - finalize text or audio drafts into normal entries on cleanup success
  - log per-draft failures without stopping later drafts in the same run
- Added launch providers for retry logging, file validation, retained-audio
  deletion, `RetryPendingDraftsUseCase`, and `AppLaunchWorkUseCase`.
- Updated launch startup wiring in `lib/main.dart` to call the new launch-work
  use case instead of invoking registration directly.
- Added unit coverage for launch registration results, launch-work sequencing,
  and draft retry success/failure paths.
- Added launch-level integration coverage for:
  - registration success triggering retry
  - registration failure skipping retry
  - audio draft finalization
  - text draft finalization
  - retry failure preservation
  - stale draft cleanup
  - malformed audio draft deletion
  - finalized retry results appearing through the existing entry surfaces

## File-change summary

### Production code

- `lib/domain/usecase/register_device_on_launch_use_case.dart`
- `lib/domain/usecase/app_launch_work_use_case.dart`
- `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- `lib/data/launch/app_launch_providers.dart`
- `lib/main.dart`

### Tests

- `test/data/api/register_device_on_launch_use_case_test.dart`
- `test/domain/usecase/app_launch_work_use_case_test.dart`
- `test/domain/usecase/retry_pending_drafts_use_case_test.dart`
- `integration_test/device_registration_launch_flow_test.dart`
- `integration_test/draft_retry_launch_flow_test.dart`

### Existing coverage verified without source edits

- `test/bootstrap_app_test.dart`
- `test/presentation/main/main_recording_controller_test.dart`
- `integration_test/main_recording_controller_flow_test.dart`
- `integration_test/cleanup_transcript_use_case_flow_test.dart`
- `lib/data/api/backend_providers.dart`

## Review remediation

The approved `review.md` pass resulted in these concrete changes:

- explicit handling for thrown `TranscriptionServiceFailure` values during
  launch retry so drafts are preserved with targeted warning logs
- a blank-transcript guard for transcription retry success payloads before
  cleanup is attempted
- a named `launchRetryStaleDraftDays` constant instead of relying on the
  implicit repository default at the retry call site
- `try/finally` handle cleanup in the launch draft-audio validator
- matching `try/finally` handle cleanup in
  `CloudTranscriptionService._validateDraftAudioPath(...)`
- unit coverage for thrown transcription-service failures and blank
  transcription success payloads

## Notable implementation notes

- No new app mode or retry UI was introduced. The feature applies to the
  existing single flow and intentionally keeps retry success silent in the
  foreground.
- Retry remains launch-only. If registration fails on launch and later recovers
  in the same session, draft retry still waits for a future launch.
- Retained-audio deletion is best-effort and happens only after the audio is no
  longer needed.
- Cleanup still owns final entry creation, draft preservation on cleanup
  failure, language canonicalization, and quota propagation.

## Validation

The following validation completed successfully:

- `dart format` on changed Dart files
- `/opt/homebrew/bin/flutter analyze`
- Focused tests:
  `/opt/homebrew/bin/flutter test test/data/api/register_device_on_launch_use_case_test.dart test/domain/usecase/app_launch_work_use_case_test.dart test/domain/usecase/retry_pending_drafts_use_case_test.dart test/bootstrap_app_test.dart test/presentation/main/main_recording_controller_test.dart`
- Full test suite:
  `/opt/homebrew/bin/flutter test`
- Android emulator launch:
  `/Users/alexander/Library/Android/sdk/emulator/emulator -avd Pixel_8_emulator -no-snapshot-load`
- Android emulator launch/retry coverage:
  `/opt/homebrew/bin/flutter test integration_test/device_registration_launch_flow_test.dart integration_test/draft_retry_launch_flow_test.dart -d emulator-5554`
- Android device launch/retry coverage:
  `/opt/homebrew/bin/flutter test integration_test/device_registration_launch_flow_test.dart integration_test/draft_retry_launch_flow_test.dart -d 4A181FDJH0030G`
- iOS simulator launch/retry coverage:
  `/opt/homebrew/bin/flutter test integration_test/device_registration_launch_flow_test.dart integration_test/draft_retry_launch_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
- iOS simulator alignment coverage:
  `/opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart integration_test/cleanup_transcript_use_case_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`

Android validation now passes on both:

- the Android emulator target (`emulator-5554`)
- the connected physical Android device (`4A181FDJH0030G`)

## Review status

The approved review remediation has been implemented and validated on Android
emulator, Android device, and iOS simulator targets. The next workflow gate is
the durable knowledge-capture proposal before any edits to long-lived docs.
