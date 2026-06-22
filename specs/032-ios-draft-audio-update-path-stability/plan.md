# Implementation Plan: iOS Draft Audio Update Path Stability

> **Feature number:** 032
> **Spec:** [`spec.md`](spec.md)
> **Status:** Approved
> **Author:** Codex
> **Date:** 2026-06-22

## Summary

Simplify retained draft-audio path handling to one shared app-managed reference
model for iOS and Android. New audio drafts will store a relative reference to
the file under the app temporary directory, resolve that reference against the
current temporary directory at runtime, and reject unsafe or unsupported paths
instead of falling back through legacy absolute or basename matching.

This keeps the iOS update path stable when the app container changes, preserves
Android behavior through the same stored-reference rule, and removes the current
portability-layer complexity that was deferred from US-030.

## Scope

### In scope

- [ ] Simplify retained audio reference storage and resolution for app-managed
      draft audio.
- [ ] Use the same stored-reference behavior on iOS and Android.
- [ ] Remove ambiguous fallback behavior that can resolve a missing draft audio
      reference to a different file with the same name.
- [ ] Validate and reject malformed retained-audio references that escape the
      app temporary directory.
- [ ] Update tests and lifecycle validation so seeded draft audio files use the
      same app-managed temporary directory rule as production recordings.
- [ ] Verify iOS update continuity, iOS uninstall/reinstall fresh state, and
      Android non-regression.

### Out of scope

- [ ] Migrating legacy draft-audio references or preserving existing draft rows.
- [ ] Supporting arbitrary external audio file locations as retryable drafts.
- [ ] Changing entry, transcription, cleanup, quota, or UI behavior beyond
      retaining and retrying draft audio correctly.
- [ ] Changing release signing, release distribution, or app-store deployment
      mechanics.

## Architecture / approach

Keep `DraftAudioPathCodec` as the single small boundary for translating between
stored database values and runtime file paths, but reduce it to strict behavior:

1. `store(audioPath)` normalizes and validates the path.
2. If the audio file is inside the current app temporary directory, store
   `app-cache://<relative-path>`.
3. If the audio file is outside the app temporary directory, throw a clear
   argument error rather than storing an absolute path.
4. `resolve(storedAudioPath)` accepts only valid `app-cache://` references,
   rejects empty or traversal relative paths, and returns the normalized path
   under the current app temporary directory.
5. `resolve(storedAudioPath)` does not check basename fallbacks and does not
   return arbitrary absolute paths.

The production live recording path already comes from `getTemporaryDirectory()`
via `liveRecordingPathFactoryProvider`, so normal retryable draft creation
continues to use app-managed temporary files. Tests that seed audio drafts from
other temp folders will be updated to either create files in the app temporary
directory when testing the real provider graph, or keep explicit injected
identity codecs only where a test is about repository behavior unrelated to
path portability.

## Detailed design

### Component / module changes

- **`lib/data/entries/draft_audio_path_codec.dart`** — Simplify store/resolve
  rules, remove absolute-path and basename fallback behavior, validate scheme
  contents, and document the narrow `app-cache://` format.
- **`test/data/entries/entry_repository_impl_test.dart`** — Replace the
  old fallback-oriented coverage with focused tests for app-cache storage,
  current-cache-root resolution, deletion through resolved paths, malformed
  reference rejection, traversal rejection, and outside-cache store rejection.
- **`integration_test/local_data_lifecycle_flow_test.dart`** — Keep the US-030
  lifecycle harness, but make the seeded draft audio path assert the shared
  app-temporary reference model across platform update verification. Extend the
  update verification flow, or add a US-032-specific lifecycle scenario, so it
  first confirms the pending audio draft is preserved after update and then
  exercises launch retry with stubbed successful transcription/cleanup.
- **`integration_test/draft_retry_launch_flow_test.dart`** — Seed real audio
  draft files under the app temporary directory when using the production
  repository provider so launch retry validates the same path model.
- **`integration_test/main_recording_controller_flow_test.dart`** — Seed
  preserved failure audio under the app temporary directory, matching production
  live recording output.
- **`integration_test/entry_list_flow_test.dart`** — Seed audio-only list
  drafts with real app-managed temporary files instead of placeholder absolute
  paths.
- **`specs/032-ios-draft-audio-update-path-stability/tasks.md`** — Replace the
  template with approved implementation tasks after this plan is approved.
- **`specs/032-ios-draft-audio-update-path-stability/implementation.md`** —
  Create during implementation with code-change details and validation evidence.

### Data flow

1. Live Best-mode recording creates an audio file in the app temporary
   directory.
2. If transcription fails with a retryable result, the main recording
   controller saves an audio draft through `EntryRepository.saveAudioDraft`.
3. The repository stores a validated `app-cache://` relative reference in
   `entries.audio_path`.
4. Repository reads resolve the stored reference against the current runtime app
   temporary directory before returning domain `Entry.audioPath`.
5. Launch retry validates the resolved runtime path, uploads the retained audio,
   and either finalizes the draft or keeps the draft for a later retry.
6. Entry deletion and stale-draft cleanup resolve the same stored reference and
   delete the retained audio file best-effort.

### Contracts and interfaces

No backend HTTP contracts change.

Local data shape before:

```text
entries.audio_path = null | absolute file path | app-cache://<relative path>
```

Local data shape after:

```text
entries.audio_path = null | app-cache://<relative path inside app temp dir>
```

There is no migration step because the user confirmed there are no existing
draft rows in the database. Unsupported absolute draft-audio paths are not part
of the post-story storage contract.

## Alternatives considered

- **Keep absolute paths and only special-case iOS:** Not chosen because it
  creates platform-specific stored data and leaves the iOS container-change
  failure mode in the model.
- **Keep the current basename fallback for old absolute paths:** Not chosen
  because it can bind a draft row to the wrong audio file and the spec forbids
  ambiguous recovery.
- **Move draft audio into documents storage:** Not chosen for this story
  because production recording already uses app temporary storage, uninstall
  should remove draft audio with app data, and the simpler relative temp
  reference satisfies the update requirement.
- **Add a schema migration for existing draft rows:** Not chosen because the
  user confirmed there are no existing database drafts to migrate.

## Test strategy

### Unit / integration coverage

| Area | Test type | Notes |
| --- | --- | --- |
| Draft audio codec stores app-temp files as relative app-cache references | Unit/widget test | Add direct coverage for same shared behavior on host tests. |
| Draft audio codec rejects paths outside app temp | Unit/widget test | Proves no arbitrary absolute path persistence. |
| Draft audio codec rejects malformed app-cache values | Unit/widget test | Cover empty relative paths, `..`, absolute relative payloads, and traversal. |
| Repository reads, deletes, and stale-cleans resolved draft audio | Unit test | Update existing repository tests so deletion still removes the resolved file. |
| Launch retry preserves and retries audio drafts using resolved paths | Integration test | Update `draft_retry_launch_flow_test.dart` seeded files to app temp. |
| Entry list audio-only draft display/delete remains correct | Integration test | Update seeded files to app temp and keep current list assertions. |
| Recording failure preserves a retryable audio draft | Integration test | Update `main_recording_controller_flow_test.dart` to match app-temp behavior. |
| Local data lifecycle preserves draft audio through update, retries the preserved draft after update, and starts fresh after uninstall/reinstall | Integration test | Reuse or extend `local_data_lifecycle_flow_test.dart` platform scenarios with stubbed successful retry dependencies. |

### Runtime verification

#### Android

1. Run host tests that cover the simplified codec and repository behavior.
2. Run the relevant integration tests on an Android emulator:
   - `integration_test/draft_retry_launch_flow_test.dart`
   - `integration_test/local_data_lifecycle_flow_test.dart`
3. Run the platform lifecycle sequence on an Android emulator:
   - seed state with a pending audio draft
   - launch a same-identity update verification run
   - confirm the draft row and resolved audio file remain present
   - trigger launch retry with stubbed successful transcription/cleanup and
     confirm the preserved audio draft finalizes
   - clear data or uninstall/reinstall
   - confirm fresh local state with no entries or drafts

#### iOS

1. Run host tests that cover the simplified codec and repository behavior.
2. Run the relevant integration tests on an iOS simulator:
   - `integration_test/draft_retry_launch_flow_test.dart`
   - `integration_test/local_data_lifecycle_flow_test.dart`
3. Run the platform lifecycle sequence on an iOS simulator:
   - seed state with a pending audio draft
   - launch a same-bundle update verification run
   - confirm the draft row resolves to usable retained audio after the runtime
     app container path changes
   - trigger launch retry with stubbed successful transcription/cleanup and
     confirm the preserved audio draft finalizes
   - uninstall/reinstall
   - confirm fresh local state with no entries or drafts

No validation exception is requested. Final approval still requires Android
emulator and iOS simulator verification.

## Risks / mitigations

- **Risk:** Tests or debug-only seed paths may still create audio drafts outside
  the app temporary directory.
  **Mitigation:** Update those seeds to use `getTemporaryDirectory()` or
  explicit injected path callbacks when the test is not exercising the codec.
- **Risk:** Strict path rejection could surface unexpected production paths if a
  future recorder implementation changes output location.
  **Mitigation:** Production currently creates live recording paths through
  `liveRecordingPathFactoryProvider`; add tests around that app-temp contract.
- **Risk:** Resolving malformed stored references could fail during broad entry
  reads.
  **Mitigation:** Cover malformed values directly and keep launch retry/delete
  behavior explicit. Because there are no existing draft rows, no migration is
  needed for current users.

## Rollout / fallback

This is a local-only change with no backend rollout. If validation finds the
strict reference model does not satisfy iOS update continuity, the fallback is
to stop before implementation completion, update the plan with a narrower
approved adjustment, and rerun the SDD gates rather than reintroducing broad
fallback behavior silently.

## Open questions

- [ ] None at this stage.
