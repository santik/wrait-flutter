# Implementation Notes: Cloud Transcription Service

> **Feature number:** 008
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-12

---

## Summary

US-007 is implemented as a new app-facing cloud transcription layer under
`lib/data/transcription/` that composes the existing recording service and
backend client.

Implemented behavior:

- live best-mode flow with explicit `RecordingStarted` and `Uploading` status
  callbacks
- sequential live/draft transcription gating with typed misuse failures
- shared session quota propagation from both transcription success and
  quota-bearing failure responses
- detected-language normalization to supported canonical codes with success
  preserved when transcript text is usable but language resolution fails
- immediate deletion of successful live recording files
- retention of failed live recording files as `audioDraftPath`
- draft-transcription behavior that leaves caller-owned audio files untouched
- review hardening that consolidates language normalization, uses one explicit
  internal transcription state model, validates local draft files before
  upload, and avoids mutating shared quota on malformed success payloads

## Key implementation details

- Added `TranscriptionService` and the service-facing result/status/failure
  types in `lib/data/transcription/transcription_service.dart`.
- Added `CloudTranscriptionService` in
  `lib/data/transcription/cloud_transcription_service.dart`.
  - review remediation replaced boolean-heavy state tracking with one explicit
    internal state enum covering live start, recording, stop, and upload
  - draft uploads now fail fast with warning logs when the caller supplies a
    blank, missing, unreadable, or zero-byte file path
  - quota propagation now happens only after the success payload has a usable
    non-blank transcript
- Added `transcriptionServiceProvider` and supporting providers for temp-path
  generation, logging, and upload callback wiring in
  `lib/data/transcription/transcription_providers.dart`.
  - live temp-file names now include a random nonce in addition to the
    timestamp to reduce collision risk
- Generalized the session quota owner in
  `lib/data/api/backend_providers.dart` to
  `sessionRecordQuotaStateProvider`, while keeping
  `registrationQuotaStateProvider` as a deprecated alias for compatibility.
- Updated the lower-level backend transcription result to allow nullable
  `detectedLanguage`, which lets the cloud transcription layer preserve usable
  transcript success when backend language data is blank or unsupported.
- Moved locale-shape sanitization and normalization helpers into
  `lib/domain/model/supported_language.dart` so the supported-language module
  remains the single source of truth for transcription language resolution.
- Added Dartdoc to the public transcription service API and expanded unit plus
  integration coverage for the review edge cases.

## Validation evidence

### Static and unit validation

```text
$ /opt/homebrew/bin/flutter analyze
No issues found!

$ /opt/homebrew/bin/flutter test --no-pub
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub test/data/transcription/cloud_transcription_service_test.dart \
    test/data/api/backend_client_test.dart \
    test/domain/model/supported_language_test.dart \
    test/data/api/register_device_on_launch_use_case_test.dart
All tests passed.
```

### Provider-graph integration validation

```text
$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/cloud_transcription_service_flow_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/device_registration_launch_flow_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/cloud_transcription_service_flow_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/device_registration_launch_flow_test.dart
All tests passed.
```

The post-review test reruns used `--no-pub` because plain `flutter test`
attempted iOS ephemeral package cleanup in this environment and failed before
executing the Dart tests.

### Real recording runtime verification

Ad hoc runtime verification was performed with the real recording plugin and a
stubbed transcription callback outside the committed test suite:

- Android emulator `emulator-5554`:
  - initial probe stalled until microphone permission was granted to the
    installed test app with
    `adb -s emulator-5554 shell pm grant com.wrait.app android.permission.RECORD_AUDIO`
  - after the permission grant, a live 6-second capture succeeded
  - the stubbed upload observed a non-empty file
  - the live audio file was deleted immediately after successful transcription
- iOS simulator `491CD949-D3C0-4C4C-A6B9-15BAB1859156`:
  - live 6-second capture succeeded
  - the stubbed upload observed a non-empty file
  - the live audio file was deleted immediately after successful transcription

## Follow-up notes

- Branch creation could not be completed in this sandbox because `.git` refs
  are read-only in the current environment.
