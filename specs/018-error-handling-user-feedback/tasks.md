# Tasks: Error Handling and User Feedback

> **Feature number:** 018
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-22

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Foundation

Confirm the current feedback contracts and pin the expected behavior in tests
before changing implementation.

- [x] [P] Update status resolver unit coverage for approved preserved-draft
      copy per error category and current no-draft fallback copy —
      `test/presentation/main/main_screen_status_test.dart`
- [x] [P] Update recording controller unit coverage for blocked microphone
      auto-clear after the configured error delay —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] [P] Confirm or strengthen shake coverage for too-short/no-match only —
      `test/presentation/main/main_recording_controller_test.dart`,
      `test/presentation/main/button_area_test.dart`
- [x] [P] Identify integration-test assertions that need updates for
      preserved-draft copy and blocked microphone auto-clear —
      `integration_test/main_recording_controller_flow_test.dart`,
      `integration_test/main_screen_flow_test.dart`,
      `integration_test/main_screen_permission_flow_test.dart`

### Group 2: Core implementation

Implement the smallest user-flow-preserving changes from the approved plan.

- [x] Map preserved-draft error states to category-specific approved copy while
      keeping non-draft fallback copy unchanged —
      `lib/presentation/main/main_screen_status.dart`
  - Depends on: Group 1
- [x] Schedule the standard error auto-clear for blocked microphone errors —
      `lib/presentation/main/main_recording_controller.dart`
  - Depends on: Group 1
- [x] Keep retryable microphone denial copy and action unchanged unless a test
      exposes a mismatch with the approved spec —
      `lib/presentation/main/main_screen_status.dart`,
      `lib/presentation/main/main_recording_controller.dart`
  - Depends on: Group 1
- [x] Update affected permission/settings recovery tests so they validate the
      settings action before auto-clear and repeat-tap behavior after auto-clear
      — `test/presentation/main/main_recording_controller_test.dart`,
      `integration_test/main_screen_permission_flow_test.dart`,
      `integration_test/main_screen_flow_test.dart`
  - Depends on: Group 1

### Group 3: Integration coverage

Validate the in-scope user flows through existing provider and main-screen
integration paths.

- [x] Add or update provider-graph integration assertions for audio draft
      preservation with `no connection · saved as draft` feedback —
      `integration_test/main_recording_controller_flow_test.dart`
  - Depends on: Group 2
- [x] Add or update provider-graph integration assertions for text draft
      preservation with `service unavailable · saved as draft` feedback —
      `integration_test/main_recording_controller_flow_test.dart`
  - Depends on: Group 2
- [x] Add or update main-screen integration coverage for visible
      draft-preserved feedback and auto-clear —
      `integration_test/main_screen_flow_test.dart`
  - Depends on: Group 2
- [x] Add or update main-screen integration coverage for blocked microphone
      feedback, 3-second auto-clear, and re-surfacing the message by tapping
      again while permission remains blocked —
      `integration_test/main_screen_flow_test.dart` or
      `integration_test/main_screen_permission_flow_test.dart`
  - Depends on: Group 2

### Group 4: Validation

Run the planned automated tests and runtime verification.

- [x] Run focused unit/widget tests:
      `flutter test test/presentation/main/main_screen_status_test.dart test/presentation/main/main_recording_controller_test.dart test/presentation/main/button_area_test.dart`
- [x] Run focused integration tests:
      `flutter test integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart integration_test/main_screen_permission_flow_test.dart`
- [x] Run `flutter analyze`
- [x] Verify preserved-draft feedback and blocked microphone auto-clear on an
      Android emulator, recording the emulator name/device id and evidence
- [x] Verify preserved-draft feedback and blocked microphone auto-clear on an
      iOS simulator, recording the simulator name/device id and evidence
- [x] If required Android emulator or iOS simulator verification cannot be
      completed, stop and request an explicit user-approved validation
      exception before final approval

### Group 5: Implementation record

Document what changed and the validation evidence for review.

- [x] Create `implementation.md` with implementation summary, changed files,
      validation commands, runtime verification evidence, and any deviations —
      `specs/018-error-handling-user-feedback/implementation.md`
- [x] Update task statuses and validation evidence in this file as work is
      completed — `specs/018-error-handling-user-feedback/tasks.md`
- [x] Confirm `spec.md` and `plan.md` still match the implemented behavior —
      `specs/018-error-handling-user-feedback/spec.md`,
      `specs/018-error-handling-user-feedback/plan.md`

### Group 6: Review and fix

Handle external review after implementation.

- [x] Stop and wait for external `review.md`, unless the user explicitly skips
      review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any
      changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 7: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether the feature produced durable learnings or long-lived
      product/architecture changes worth preserving
- [x] If needed, propose updates to `AGENTS.md`,
      `docs/application-description.md`, and `docs/agent-findings.md`
- [x] Wait for explicit approval before editing those long-lived guidance
      documents
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [x] Mark `spec.md` status `Complete` only after implementation, validation,
      review/fix handling, and knowledge capture are complete

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
2026-06-22

Focused unit/widget tests:
flutter test test/presentation/main/main_screen_status_test.dart test/presentation/main/main_recording_controller_test.dart test/presentation/main/button_area_test.dart
Result: passed

Focused integration tests on Android physical device Pixel 8 (4A181FDJH0030G):
flutter test integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart integration_test/main_screen_permission_flow_test.dart
Result: passed

Static analysis:
flutter analyze
Result: No issues found.

iOS simulator validation on iPhone 17 simulator (491CD949-D3C0-4C4C-A6B9-15BAB1859156):
flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart
Result: passed

Android emulator validation:
flutter test -d emulator-5554 integration_test/main_screen_flow_test.dart
Result: passed on sdk gphone16k arm64 emulator (emulator-5554, Android 17 / API 37)

Knowledge capture:
No durable documentation update was needed for AGENTS.md, docs/application-description.md, or docs/agent-findings.md.
```

## Notes

- Language settings, offline-model messaging, and additional app modes are out
  of scope for US-018.
- Current no-draft fallback copy is intentionally preserved:
  `no connection`, `service unavailable`, `server config error`,
  `something went wrong`.
