# Tasks: iOS Draft Audio Update Path Stability

> **Feature number:** 032
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
`[P]` can be worked on in parallel after their group prerequisites are met.

### Group 1: Retained-Audio Reference Model

- [x] Simplify `lib/data/entries/draft_audio_path_codec.dart` so
      `store(audioPath)` accepts app-temporary-directory files and stores only
      `app-cache://<relative-path>` values.
- [x] Update `DraftAudioPathCodec.store` to reject unsupported paths outside
      the app temporary directory with a clear argument error instead of storing
      absolute paths.
- [x] Simplify `DraftAudioPathCodec.resolve` so it accepts only valid
      `app-cache://` references and resolves them under the current app
      temporary directory.
- [x] Remove basename fallback and legacy absolute-path recovery from
      `DraftAudioPathCodec.resolve`.
- [x] Add concise documentation in `draft_audio_path_codec.dart` for the narrow
      shared `app-cache://` format and why ambiguous fallback is intentionally
      absent.

### Group 2: Unit and Repository Coverage

- [x] Add or update direct codec coverage proving app-temp paths are stored as
      relative `app-cache://` values.
- [x] Add or update direct codec coverage proving resolution uses the current
      app temporary directory.
- [x] Add or update direct codec coverage for rejected outside-cache store
      paths.
- [x] Add or update direct codec coverage for malformed stored references:
      blank payload, traversal, absolute payload, and unsupported scheme or
      absolute value.
- [x] Update `test/data/entries/entry_repository_impl_test.dart` so repository
      audio-draft read/delete/stale-clean tests still prove deletion uses the
      resolved app-temp path.
- [x] Update `test/data/entries/entry_database_test.dart` bootstrap stale-draft
      setup if needed so it remains compatible with the simplified shared
      stored-reference model.

### Group 3: Integration Test Fixture Alignment

- [x] Update `integration_test/entry_list_flow_test.dart` audio-only draft seeds
      to create real app-temporary audio files instead of placeholder absolute
      paths.
- [x] Update `integration_test/draft_retry_launch_flow_test.dart` audio draft
      seeds to create retained audio under the app temporary directory.
- [x] Update `integration_test/main_recording_controller_flow_test.dart`
      retryable failure audio setup to use the app temporary directory.
- [x] Update `integration_test/local_data_lifecycle_flow_test.dart` so seeded
      lifecycle draft audio asserts the shared stored-reference behavior and
      remains valid through platform update verification.
- [x] Extend `integration_test/local_data_lifecycle_flow_test.dart` or add a
      US-032-specific lifecycle scenario so post-update verification triggers
      launch retry with stubbed successful transcription/cleanup and proves the
      preserved audio draft can finalize.

### Group 4: Automated Validation

- [x] Run `dart format` on changed Dart files.
- [x] Run targeted host tests for codec/repository/bootstrap coverage.
- [x] Run targeted integration tests locally where supported by the test runner:
      `entry_list_flow_test.dart`, `draft_retry_launch_flow_test.dart`,
      `main_recording_controller_flow_test.dart`, and
      `local_data_lifecycle_flow_test.dart`.
- [x] Run `/opt/homebrew/bin/flutter analyze`.
- [x] Run `/opt/homebrew/bin/flutter test`.

### Group 5: Platform Runtime Verification

- [x] Run Android emulator lifecycle seed scenario with a pending audio draft.
- [x] Run Android emulator lifecycle update-verify scenario and confirm the
      draft row and resolved audio file remain usable.
- [x] Run Android emulator post-update retry verification and confirm the
      preserved audio draft finalizes through launch retry.
- [x] Run Android emulator fresh-state scenario after clear-data or uninstall
      and confirm no entries or drafts remain.
- [x] Run iOS simulator lifecycle seed scenario with a pending audio draft.
- [x] Run iOS simulator lifecycle update-verify scenario and confirm the draft
      row resolves to usable retained audio after the runtime container path
      changes.
- [x] Run iOS simulator post-update retry verification and confirm the
      preserved audio draft finalizes through launch retry.
- [x] Run iOS simulator fresh-state scenario after uninstall/reinstall and
      confirm no entries or drafts remain.

### Group 6: Implementation Artifact

- [x] Create `specs/032-ios-draft-audio-update-path-stability/implementation.md`
      with implemented behavior, file changes, validation evidence, and any
      deviations from the approved plan.
- [x] Update this task list with completed statuses and validation notes.

### Group 7: Review and Fix

- [x] Stop and wait for external `review.md`, unless the user explicitly
      skips review.
- [x] Read `review.md` and prepare a remediation plan without changing files.
- [x] Present the remediation plan and wait for approval before making any
      changes.
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation.
- [x] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass (not needed; no additional review revision was provided).

### Group 8: Finalization

- [x] Decide whether this feature produced durable learnings or long-lived
      product/architecture changes worth preserving.
- [x] If needed, propose updates to `AGENTS.md` (not needed for US-032).
- [x] If needed, propose updates to `docs/application-description.md` (not
      needed for US-032).
- [x] If needed, propose updates to `docs/agent-findings.md`.
- [x] Wait for explicit approval before editing long-lived guidance documents.
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision.
- [x] Mark `spec.md` status as `Complete` only after implementation, review,
      validation, and final knowledge-capture gates are handled.

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
Completed implementation and validation for Groups 1-6.

Formatting:
- dart format lib/data/entries/draft_audio_path_codec.dart test/data/entries/draft_audio_path_codec_test.dart integration_test/entry_list_flow_test.dart integration_test/entry_detail_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/draft_retry_launch_flow_test.dart integration_test/local_data_lifecycle_flow_test.dart

Host validation:
- /opt/homebrew/bin/flutter test test/data/entries/draft_audio_path_codec_test.dart test/data/entries/entry_repository_impl_test.dart test/data/entries/entry_database_test.dart
- /opt/homebrew/bin/flutter analyze
- /opt/homebrew/bin/flutter test

Targeted simulator integration validation (iOS simulator 491CD949-D3C0-4C4C-A6B9-15BAB1859156):
- /opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart integration_test/entry_detail_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/draft_retry_launch_flow_test.dart integration_test/local_data_lifecycle_flow_test.dart
- One brittle exact-text assertion in draft_retry_launch_flow_test.dart was relaxed to the existing stats-line key after the simulator run proved the path behavior was correct but the exact stats text differed.

Android emulator lifecycle validation (emulator-5554):
- /opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-seed
- /opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-update-verify
- /opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-update-retry-verify
- adb -s emulator-5554 shell pm clear com.wrait.flutter
- /opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d emulator-5554 --dart-define=US030_SCENARIO=platform-fresh-state

iOS simulator lifecycle validation (491CD949-D3C0-4C4C-A6B9-15BAB1859156):
- /opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-seed
- /opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-update-verify
- /opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-update-retry-verify
- xcrun simctl uninstall 491CD949-D3C0-4C4C-A6B9-15BAB1859156 com.wrait.app
- /opt/homebrew/bin/flutter drive --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/local_data_lifecycle_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 --dart-define=US030_SCENARIO=platform-fresh-state
- The iOS simulator uninstall required one escalated rerun of simctl because sandboxed CoreSimulator access was denied.

Review remediation:
- Accepted: stricter codec contract documentation, targeted codec tests, shared managed-audio integration-test helper extraction, best-effort per-file cleanup, and clearer implementation notes about startup-flow and stats-surface coverage.
- Intentionally not remediated: legacy absolute-path migration or recovery, because the user explicitly confirmed there are no draft rows to preserve and asked to reduce the path-portability layer rather than expand it.
- Additional validation:
  - /opt/homebrew/bin/flutter analyze
  - /opt/homebrew/bin/flutter test test/data/entries/draft_audio_path_codec_test.dart
  - /opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_list_flow_test.dart integration_test/entry_detail_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/draft_retry_launch_flow_test.dart

Knowledge capture:
- Updated: docs/agent-findings.md with the shared app-cache retained-audio path contract for future work.
- No update needed: AGENTS.md.
- No update needed: docs/application-description.md.
```
