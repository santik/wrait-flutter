# Implementation: Terminal No-Speech Transcription Handling

> **Feature number:** 036
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-29

---

## Summary

US-036 is implemented in the Flutter app with two behavior changes kept tightly
scoped to the approved story:

- blank successful transcription results are now terminal no-word failures
  instead of retryable audio drafts
- quota publication now follows one rule: callers publish quota from failed
  transcription results, while cleanup publishes quota for successful
  transcription paths using transcription quota only as a fallback when cleanup
  has no quota of its own

This removes the stuck no-word draft loop and prevents the visible quota from
appearing to advance twice when a recording is preserved as a draft after the
cleanup step fails.

## Implemented behavior

- `CloudTranscriptionService` now:
  - deletes service-owned live temp audio when the backend returns a blank
    successful transcript payload
  - maps that blank live result to terminal `nothingCaught` without a retryable
    `audioDraftPath`
  - keeps caller-owned draft audio untouched for blank draft transcription
    results
  - never publishes quota directly; it only returns backend quota on the
    transcription result for callers to handle consistently
- `MainRecordingController` now ignores any `audioDraftPath` attached to
  `TranscriptionFailureReason.nothingCaught`, so no-word failures remain
  terminal even if a fake or future service implementation supplies a path,
  and it publishes failed-transcription quota once before any local
  draft-persistence work.
- `CleanupTranscriptUseCase` now accepts an optional `fallbackQuota` and uses
  it when cleanup exits without its own backend quota. This covers:
  - cleanup backend failures without quota
  - local cleanup failures before or after the backend call
  - launch retry cleanup after successful draft transcription
- `RetryPendingDraftsUseCase` now passes transcription quota into cleanup as
  that fallback when a draft transcription succeeds, and publishes failed
  draft-retry transcription quota once when launch retry preserves the draft.

## Changed files

| File | Change |
| --- | --- |
| `lib/data/transcription/cloud_transcription_service.dart` | Made blank live transcripts terminal, deleted owned temp audio on that path, and removed direct quota publication so the service now only returns quota to callers. |
| `lib/data/launch/app_launch_providers.dart` | Wired launch-retry quota publication through the shared session quota notifier. |
| `lib/domain/usecase/cleanup_transcript_use_case.dart` | Added `fallbackQuota` handling so cleanup owns quota publication for success-with-transcript flows while still preserving one backend-derived update when cleanup has no quota. |
| `lib/domain/usecase/retry_pending_drafts_use_case.dart` | Passed successful transcription quota into cleanup retry as the fallback quota and published failed draft-retry quota once. |
| `lib/presentation/main/main_recording_controller.dart` | Prevented `nothingCaught` failures from persisting audio drafts, published failed-transcription quota once, and passed transcription quota into cleanup as fallback quota. |
| `test/data/transcription/cloud_transcription_service_test.dart` | Updated service coverage for terminal blank live transcripts, owned-audio deletion, and caller-owned quota publication on failure and blank-transcript paths. |
| `test/domain/usecase/cleanup_transcript_use_case_test.dart` | Added fallback-quota coverage for cleanup failures, local cleanup persistence failures, and the null/null quota case. |
| `test/domain/usecase/retry_pending_drafts_use_case_test.dart` | Added launch-retry failed-transcription quota coverage while preserving the retryable draft. |
| `test/presentation/main/main_recording_controller_test.dart` | Added no-word draft-suppression coverage and verified the controller passes fallback quota into cleanup. |
| `integration_test/cloud_transcription_service_flow_test.dart` | Added provider-graph coverage for terminal blank live and blank draft transcripts while keeping quota publication caller-owned. |
| `integration_test/main_recording_controller_flow_test.dart` | Added provider-graph coverage for no-word terminal behavior, failed-transcription quota publication, and cleanup fallback quota preservation. |
| `lib/data/api/backend_client.dart` | Preserved blank backend success payloads so app-facing no-speech classification can happen in the transcription layer instead of becoming retryable `apiError` failures. |
| `test/data/api/backend_client_test.dart` | Added regression coverage that blank backend transcription success payloads stay successful for caller-side no-speech classification. |

## Reopened regression remediation

On 2026-06-30 the story was reopened after a user-reported regression: a live
recording with no speech could still upload, enter cleanup, and persist as a
draft. The root cause had two parts:

- `WraitBackendClient` rewrote blank backend success payloads to
  `BackendFailureReason.apiError`, which turned true no-speech results into
  retryable failures before the cloud transcription layer could classify them.
- `CloudTranscriptionService` only treated whitespace-empty success payloads as
  `nothingCaught`, so punctuation-only or otherwise non-usable success payloads
  could still reach cleanup.

The remediation keeps backend success payloads intact for caller
classification, classifies no usable transcript content as terminal
`nothingCaught`, and adds a defensive controller guard so punctuation-only
success payloads still cannot enter cleanup or create drafts.

### Reopened regression validation

```text
flutter test test/data/api/backend_client_test.dart test/data/transcription/cloud_transcription_service_test.dart test/presentation/main/main_recording_controller_test.dart
Result: passed

flutter analyze
Result: No issues found.

flutter test -d 4A181FDJH0030G integration_test/main_recording_controller_flow_test.dart
Result: passed on connected Pixel 8 device (Android 16)
Note: the planned emulator target `emulator-5554` was unavailable in this session.

flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_recording_controller_flow_test.dart
Result: passed on iPhone 17 simulator (iOS 26.5) after booting the simulator with `xcrun simctl boot 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
```

## Validation

### Automated

```text
flutter test test/data/transcription/cloud_transcription_service_test.dart test/domain/usecase/cleanup_transcript_use_case_test.dart test/presentation/main/main_recording_controller_test.dart
Result: passed

flutter analyze
Result: No issues found.
```

### Runtime verification

```text
flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_recording_controller_flow_test.dart
Result: passed on iPhone 17 simulator (iOS 26.5)
```

Observed runtime behaviors from the validated focused flow:

- no-word outcomes surface as terminal `noMatch` behavior and leave no pending
  draft behind
- retryable live transcription failures still preserve audio drafts
- cleanup-failure draft preservation keeps the backend-derived quota visible
  once instead of requiring a second local quota update path

### Review remediation validation

```text
flutter test test/data/transcription/cloud_transcription_service_test.dart test/domain/usecase/cleanup_transcript_use_case_test.dart test/domain/usecase/retry_pending_drafts_use_case_test.dart test/presentation/main/main_recording_controller_test.dart
Result: passed

flutter test -d emulator-5554 integration_test/cloud_transcription_service_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart
Result: passed on Pixel_8_emulator (emulator-5554)

flutter analyze
Result: No issues found.

flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_recording_controller_flow_test.dart
Result: passed on iPhone 17 simulator (iOS 26.5)
```

## Notes

- Existing no-word audio drafts created before US-036 remain out of scope.
- Backend quota accounting rules and response shapes remain out of scope; this
  implementation only changes how existing backend quota is surfaced locally.
- `integration_test/main_screen_flow_test.dart` did not require a new US-036
  scenario because existing provider-graph status assertions plus
  `main_screen_status` tests already covered the user-visible no-match copy.
- External review remediation is now applied. A new review/fix loop is only
  needed if the same `review.md` is updated again.
