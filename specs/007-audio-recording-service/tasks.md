# Tasks: Audio Recording Service

> **Feature number:** 007
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-10

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel.

### Group 1: Foundation

Set up the shared contracts, time abstraction, and dependency wiring needed for
the recording service.

- [x] Create the monotonic time abstraction and default implementation — `lib/core/time/monotonic_clock.dart`
- [x] Create the app-facing recording service contract and typed failure types — `lib/data/audio/audio_recording_service.dart`
- [x] Create Riverpod providers for the monotonic clock and recording service wiring — `lib/data/audio/audio_recording_providers.dart`

### Group 2: Core implementation

Implement the plugin-backed recording service behavior and its deterministic
test doubles.

- [x] Implement the `record`-backed recording service with active-session state, caller-supplied output paths, and hard-cap deadline bookkeeping — `lib/data/audio/record_audio_recording_service.dart`
  - Depends on: Group 1
- [x] Implement too-short invalidation, invalid-stop failures, and cleanup of rejected output files — `lib/data/audio/record_audio_recording_service.dart`
  - Depends on: Group 1
- [x] Create the deterministic fake monotonic clock used by tests — `test/test_doubles/fake_monotonic_clock.dart`
  - Depends on: Group 1

### Group 3: Automated validation

Add the planned automated coverage for the service contract and orchestrator
handoff behavior.

- [x] Add unit coverage for blank-path rejection, concurrent-start rejection, recorder config requests, valid stop success, no-active-session stop failure, too-short cleanup, and deadline math — `test/data/audio/audio_recording_service_test.dart`
  - Depends on: Group 2
- [x] Add fake-driven `integration_test` coverage for start/stop, cap-driven orchestrator stop, and invalid short-recording behavior through the real provider graph — `integration_test/audio_recording_service_flow_test.dart`
  - Depends on: Group 2
- [x] Implement `integration_test` coverage for every in-scope user flow from the plan, or record the approved exception
  - Depends on: Group 3 automated test files
- [x] Add or update lower-level automated tests from the plan
  - Depends on: Group 3 automated test files
- [x] Verify the project build succeeds with no errors
  - Depends on: Group 3 automated test files

### Group 4: Runtime verification

Validate the real cross-platform recording behavior required for final
approval.

- [x] Verify the feature on an Android emulator by recording one valid manual capture stopped before the cap and confirming the produced file is playable, or record the approved exception
  - Depends on: Group 2
- [x] Verify the feature on an Android emulator with a cap-driven stop orchestrated from the temporary validation harness, or record the approved exception
  - Depends on: Group 2
- [x] Verify the feature on an iOS simulator by recording one valid manual capture stopped before the cap and confirming the produced file is playable, or record the approved exception
  - Depends on: Group 2
- [x] Verify the feature on an iOS simulator with a cap-driven stop orchestrated from the temporary validation harness, or record the approved exception
  - Depends on: Group 2

### Group 5: Review and fix

Handle implementation notes and the external review gate after coding.

- [x] Create `implementation.md` with implementation notes and validation evidence
- [x] Stop and wait for external `review.md`, unless the user explicitly skips review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`, `tasks.md`, `implementation.md`, code, and tests when review changes scope, approach, or validation
- [x] Repeat the review/fix loop if the same `review.md` file is updated for another pass (not needed for this story; no additional review update was provided)

### Group 6: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether the feature produced durable learnings or long-lived product/architecture changes worth preserving
- [x] If needed, propose updates to `AGENTS.md`, `docs/application-description.md`, and `docs/agent-findings.md`
- [x] Wait for explicit approval before editing those long-lived guidance documents
- [x] Record whether the knowledge-capture gate resulted in updates or an explicit no-update decision

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
$ dart format lib/core/time/monotonic_clock.dart lib/data/audio/audio_recording_service.dart lib/data/audio/record_audio_recording_service.dart lib/data/audio/audio_recording_providers.dart test/test_doubles/fake_monotonic_clock.dart test/data/audio/audio_recording_service_test.dart integration_test/audio_recording_service_flow_test.dart
Formatted files successfully.

$ /opt/homebrew/bin/flutter analyze
No issues found! (ran in 3.7s)

$ /opt/homebrew/bin/flutter test --no-pub
All tests passed! (84 tests)

$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/audio_recording_service_flow_test.dart
All tests passed! (Android emulator)

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/audio_recording_service_flow_test.dart
All tests passed! (iOS simulator)

$ adb -s emulator-5554 install -r -g build/app/outputs/flutter-apk/app-debug.apk
Success

$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/audio_recording_runtime_probe_test.dart
Passed. Produced `/data/user/0/com.wrait.app/cache/runtime-probe-1781092815274.m4a`.

$ adb -s emulator-5554 shell run-as com.wrait.app ls -l cache/runtime-probe-1781092815274.m4a
-rw------- 1 u0_a232 u0_a232_cache 76960 2026-06-10 14:00 cache/runtime-probe-1781092815274.m4a

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/audio_recording_runtime_probe_test.dart
Passed. Produced `/Users/alexander/Library/Developer/CoreSimulator/.../Library/Caches/runtime-probe-1781092664546.m4a`.

$ /opt/homebrew/bin/flutter analyze
No issues found! (ran in 3.4s) after review-fix remediation.

$ /opt/homebrew/bin/flutter test --no-pub
All tests passed! (88 tests) after review-fix remediation.

$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/audio_recording_service_flow_test.dart
All tests passed! (Android emulator) after review-fix remediation.

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/audio_recording_service_flow_test.dart
All tests passed! (iOS simulator) after review-fix remediation.

$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/audio_recording_runtime_probe_test.dart
Passed after review-fix remediation. Produced `/data/user/0/com.wrait.app/cache/runtime-probe-1781120490839.m4a`.

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/audio_recording_runtime_probe_test.dart
Passed after review-fix remediation. Produced `/Users/alexander/Library/Developer/CoreSimulator/.../Library/Caches/runtime-probe-1781120502542.m4a`.
```

## Notes

- The future process orchestrator, not this service, owns the timer that stops
  recording at the hard cap and receives the completed file path.
- Too-short user-visible copy and shake behavior remain for later UI and
  state-machine stories; this story only provides the typed failure signal.
- A temporary `integration_test/audio_recording_runtime_probe_test.dart`
  validation harness was created only for runtime verification and removed
  afterward; the evidence above captures its results.
- The first external review pass has been applied; if `review.md` changes
  again, the story re-enters the review/fix loop from Group 5.
- Final knowledge capture result:
  - `docs/application-description.md` updated
  - `docs/agent-findings.md` updated
  - no `AGENTS.md` change needed for this story
