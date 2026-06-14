# Implementation Plan: Main Screen UI

> **Feature number:** 011
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-13

---

## Approach summary

Replace the root placeholder screen with a focused main recording screen that
binds to the existing main recording controller, entry repository,
preferences repository, session quota state, and app config. The screen will
render the approved vertical stack, two-label circular action button,
status-line messages, pulse/shake/countdown animations, entry stats, quota
line, and saved-detail navigation. The plan keeps swipe gestures out of scope,
reuses existing theme tokens and routes, and adds only small presentation
helpers for stats and status mapping.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Root presentation | Replace `HomePlaceholderScreen` with `MainScreen` on `/` | US-011 is the first real root-screen UI story. Replacing the placeholder is the simplest way to make the app launch into the approved recording experience while keeping existing `/entries` and `/entry/:id` routes. |
| Component split | Add `MainScreen`, `ButtonArea`, `PulseRing`, and `CountdownRing` under `lib/presentation/main/` | The UI has distinct responsibilities: screen orchestration, button interaction, listening pulse, and countdown drawing. This keeps widget tests targeted and mirrors the Android reference structure without copying platform-specific implementation. |
| Status mapping | Add a pure presentation helper that maps `RecordingControllerState` plus `hasEverRecorded` into status text and tappable status actions | Status copy is UI policy, not recording-pipeline behavior. A helper gives deterministic tests for all states and keeps the widget tree readable. |
| Stats derivation | Add a pure helper/provider that derives `{count} entries - {days} days` from `watchAllEntries()` | Stats are derived runtime display data, not persisted state. A helper makes draft inclusion, fixed plural wording, and local-calendar active-day counting explicit and testable. |
| Local dates | Convert entry `createdAt` epoch milliseconds to the device local `DateTime` date before counting unique days | The spec requires unique local calendar dates. This matches what the user sees on device and avoids UTC day-boundary surprises. |
| Saved auto-clear | Schedule UI-owned `clearSaved()` after `RecordingFeedbackDelays.savedDisplayWindow` using a local generation token to invalidate stale timers | US-010 intentionally left Saved clearing to the UI. The generation token keeps the approved four-second behavior while preventing older timers from clearing a newer Saved presentation. |
| Countdown source | Add `hardCapDeadlineElapsedRealtime` to `RecordingListening` and set it from `RecordingStarted` | Countdown needs the hard-cap deadline that the controller already receives. Adding metadata to Listening does not change recording behavior and prevents the UI from reaching into the transcription service. |
| Countdown refresh | Keep countdown progress in local UI state and rebuild only the button area from a `ValueNotifier<double?>` on a relaxed refresh cadence | The countdown must stay visible during listening, but rebuilding the full screen every 100ms is wasteful. A local notifier keeps the repaint surface small and the refresh cadence sufficient for human perception. |
| Draft-preserved status | Add a `preservedDraft` flag to `RecordingErrorState` and set it when audio or text draft preservation succeeds | The UI must show `saved as draft` only when a draft was actually preserved. Error categories alone are insufficient, especially for generic API failures, so minimal state metadata is safer than guessing in UI. |
| Uploading/processing button | Keep button taps wired to the controller but render the button at 0.3 opacity while uploading/processing | The controller already ignores taps during active non-listening phases. The reduced opacity communicates unavailable state without duplicating business guards in the UI. |
| Navigation | Use existing GoRouter routes: `/entries` for stats tap and `/entry/:id` for saved status tap | The full list/detail experiences are later stories, but placeholder routes already exist and satisfy this story's navigation outcomes. |
| Accessibility | Add semantic labels/actions for quota, action button, status line, and stats line | The spec explicitly requires meaningful accessibility. Semantics will be verified in widget tests where practical. |
| Storage migration | None | This feature adds runtime UI state/helpers only and derives stats from existing entries. |
| Validation exception | None requested | The feature can satisfy widget tests, integration tests for in-scope user flows, and Android/iOS runtime verification. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/core/router/app_router.dart` | Modify | Route `/` to `MainScreen` instead of the home placeholder while keeping existing entry routes. |
| `lib/presentation/home/home_placeholder_screen.dart` | Delete or leave unused | Remove root placeholder usage; keep only if tests or future references still need it during implementation. |
| `lib/presentation/main/main_screen.dart` | Create | Compose quota line, button area, status line, stats line, saved clear timer, status actions, and navigation. |
| `lib/presentation/main/button_area.dart` | Create | Render the adaptive circular action button, button labels, disabled opacity, pulse ring, countdown ring, and shake trigger. |
| `lib/presentation/main/pulse_ring.dart` | Create | Render the listening pulse animation with approved scale, opacity, and timing. |
| `lib/presentation/main/countdown_ring.dart` | Create | Render countdown progress around the button while listening. |
| `lib/presentation/main/main_screen_status.dart` | Create | Pure helper for button labels, status text, tappable status actions, draft-preserved text, and first-time idle copy. |
| `lib/presentation/main/main_screen_stats.dart` | Create | Pure helper/provider for entry count and local active-day stats. |
| `lib/presentation/main/recording_state.dart` | Modify | Add listening hard-cap deadline metadata and draft-preserved metadata on error state. |
| `lib/presentation/main/main_recording_controller.dart` | Modify | Populate `RecordingListening.hardCapDeadlineElapsedRealtime`; set `RecordingErrorState.preservedDraft` when audio/text draft preservation succeeds; keep existing transition behavior. |
| `test/app_smoke_test.dart` | Modify | Update root-screen smoke expectations from placeholder content to the main screen. |
| `test/core/router/app_router_test.dart` | Modify | Update route-flow root assertions for the new main screen. |
| `test/presentation/main/main_recording_controller_test.dart` | Modify | Update existing recording-state expectations for new Listening/Error metadata and add draft-preserved assertions. |
| `test/presentation/main/main_screen_status_test.dart` | Create | Unit coverage for button label, status text, status actions, first-time copy, draft text, and deleted text. |
| `test/presentation/main/main_screen_stats_test.dart` | Create | Unit coverage for fixed stats formatting, draft inclusion, zero entries, and unique local calendar dates. |
| `test/presentation/main/button_area_test.dart` | Create | Widget coverage for adaptive sizing, labels, opacity, pulse visibility, countdown visibility, and shake retrigger. |
| `test/presentation/main/main_screen_test.dart` | Create | Widget coverage for screen layout, quota visibility, stats navigation, saved-detail navigation, saved auto-clear, and semantics. |
| `integration_test/main_screen_flow_test.dart` | Create | End-to-end widget/provider graph coverage for in-scope main-screen flows on device/simulator. |
| `specs/011-main-screen-ui/implementation.md` | Create later | Record implementation details and validation evidence during the implementation phase. |

## API contract details

No backend HTTP endpoint changes are planned.

The presentation contract will use these runtime inputs:

```text
RecordingControllerState
  recordingState
  shakeErrorKey
  isActive

RecordingListening
  hardCapDeadlineElapsedRealtime

RecordingErrorState
  error
  preservedDraft

Entry stream
  List<Entry>

Preferences
  hasEverRecorded

Quota
  RecordQuotaState?
```

UI actions:

- Action button tap calls `MainRecordingController.onMainButtonTapped()`.
- First-time idle status tap also calls `onMainButtonTapped()`.
- Saved status tap navigates to `/entry/<entryId>`.
- Stats tap navigates to `/entries`.
- Saved-state display starts a UI-owned timer that calls
  `MainRecordingController.clearSaved()` after the saved display window if the
  same Saved state is still visible.

Failure behavior:

- Missing saved-entry id should not occur because `RecordingSaved` validates
  positive ids. If it does, navigation is skipped and the app does not crash.
- Missing quota hides the quota line.
- Empty entries display `0 entries - 0 days`.

## Data model changes

No persistent data-model or database migration is planned.

### Before

```text
RecordingListening
  no fields

RecordingErrorState
  error
```

### After

```text
RecordingListening
  hardCapDeadlineElapsedRealtime: int

RecordingErrorState
  error: RecordingError
  preservedDraft: bool = false
```

### Migration

No migration is required. Both changes are runtime presentation-state metadata.

## Test strategy

Validation will combine pure unit tests, widget tests, provider-graph
integration tests, static analysis, and Android/iOS runtime verification. Every
in-scope user flow has planned `integration_test` coverage; no validation
exception is requested.

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Button label maps to `wrait` outside listening and `stop` while listening | Unit | `test/presentation/main/main_screen_status_test.dart` |
| First-time idle status is `tap button to write`; returning idle status is `wrait` | Unit | `test/presentation/main/main_screen_status_test.dart` |
| Listening/uploading/processing/saved/deleted/error states map to approved status copy | Unit | `test/presentation/main/main_screen_status_test.dart` |
| Draft-preserved errors map to `saved as draft` and non-draft errors keep their specific message | Unit | `test/presentation/main/main_screen_status_test.dart` |
| Stats formatting uses `{count} entries - {days} days` without singular special casing | Unit | `test/presentation/main/main_screen_stats_test.dart` |
| Stats include draft and finalized entries | Unit | `test/presentation/main/main_screen_stats_test.dart` |
| Active days count unique local calendar dates with at least one entry | Unit | `test/presentation/main/main_screen_stats_test.dart` |
| Action button renders approved adaptive diameter across narrow, normal, wide, and landscape constraints | Widget | `test/presentation/main/button_area_test.dart` |
| Button opacity is 0.3 during uploading/processing and full opacity otherwise | Widget | `test/presentation/main/button_area_test.dart` |
| Pulse ring is visible only while listening | Widget | `test/presentation/main/button_area_test.dart` |
| Countdown ring is visible throughout listening and hidden otherwise | Widget | `test/presentation/main/button_area_test.dart` |
| Shake animation retriggers when `shakeErrorKey` changes for repeated errors | Widget | `test/presentation/main/button_area_test.dart` |
| Root screen renders quota, button, status, and stats in the approved order with reserved regions | Widget | `test/presentation/main/main_screen_test.dart` |
| First-time status tap starts recording through the controller | Widget | `test/presentation/main/main_screen_test.dart` |
| Action button starts recording from idle and stops while listening | Widget | `test/presentation/main/main_screen_test.dart` |
| Saved status tap navigates to `/entry/<id>` | Widget | `test/presentation/main/main_screen_test.dart` |
| Stats tap navigates to `/entries` | Widget | `test/presentation/main/main_screen_test.dart` |
| Saved feedback auto-clears after the saved display window | Widget | `test/presentation/main/main_screen_test.dart` |
| Quota line is visible with valid quota, including while active | Widget | `test/presentation/main/main_screen_test.dart` |
| Quota line is hidden with no quota | Widget | `test/presentation/main/main_screen_test.dart` |
| Main-screen semantics expose meaningful button, status, stats, and quota labels/actions | Widget | `test/presentation/main/main_screen_test.dart` |
| Listening button semantics expose countdown-aware accessibility copy | Widget | `test/presentation/main/button_area_test.dart` |
| Saved auto-clear ignores stale timers after a newer Saved state replaces the prior one | Widget | `test/presentation/main/main_screen_test.dart` |
| Preference loading failure falls back to first-time idle copy instead of leaving the screen indeterminate | Widget | `test/presentation/main/main_screen_test.dart` |
| Disposing the screen while listening cancels countdown updates without exceptions | Widget | `test/presentation/main/main_screen_test.dart` |
| Non-positive recording hard-cap configuration hides the countdown ring gracefully | Widget | `test/presentation/main/main_screen_test.dart` |
| Existing controller tests cover Listening deadline metadata and draft-preserved error metadata | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| App smoke test launches to the real main screen | Widget | `test/app_smoke_test.dart` |
| Router test preserves `/`, `/entries`, and `/entry/:id` route behavior with the new root screen | Widget | `test/core/router/app_router_test.dart` |
| Provider graph shows first-time status, taps into Listening, stops into Saved, displays saved status, auto-clears, and navigates to saved detail | Integration | `integration_test/main_screen_flow_test.dart` |
| Provider graph displays stats from persisted finalized and draft entries and navigates to the entry list | Integration | `integration_test/main_screen_flow_test.dart` |
| Provider graph displays quota while idle and while listening | Integration | `integration_test/main_screen_flow_test.dart` |
| Provider graph displays microphone-blocked status | Integration | `integration_test/main_screen_flow_test.dart` |
| `flutter analyze` completes cleanly | Static analysis | Command evidence recorded in `tasks.md` |
| `flutter test` passes | Test suite | Command evidence recorded in `tasks.md` |

### Android emulator verification

1. Run `integration_test/main_screen_flow_test.dart` on an Android emulator.
2. Verify the Android run covers:
   - first-time status tap into listening
   - button stop into saved status and saved-detail navigation
   - stats display/navigation with draft inclusion
   - quota visible during idle and listening
   - microphone-blocked status display
3. Manually launch the app on Android and visually confirm:
   - root screen shows the main UI, not the placeholder
   - button diameter is visually correct on the emulator viewport
   - pulse and countdown appear while listening in the test/fake flow or a
     debug-injected flow
4. Record emulator target and passing command evidence in `tasks.md`.

### iOS simulator verification

1. Run `integration_test/main_screen_flow_test.dart` on an iOS simulator.
2. Verify the iOS run covers:
   - first-time status tap into listening
   - button stop into saved status and saved-detail navigation
   - stats display/navigation with draft inclusion
   - quota visible during idle and listening
   - microphone-blocked status display
3. Manually launch the app on iOS and visually confirm:
   - root screen shows the main UI, not the placeholder
   - button diameter is visually correct on the simulator viewport
   - pulse and countdown appear while listening in the test/fake flow or a
     debug-injected flow
4. Record simulator target and passing command evidence in `tasks.md`.

### Validation exception request

No exception requested.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates to:
  - `docs/application-description.md`, because the app will now have the real
    main recording UI instead of a placeholder root.
  - `docs/agent-findings.md`, because future UI stories should know about the
    main-screen component split, status mapping, and countdown metadata.
- `AGENTS.md` probably does not need an update unless implementation reveals a
  lasting workflow or architecture rule.

## Integration notes

- The root router will import `MainScreen`; existing entry placeholder routes
  remain valid until later stories replace them.
- `RecordingListening` equality and existing controller tests must be updated
  for the new hard-cap deadline field.
- `RecordingErrorState` equality and existing controller tests must be updated
  for the new `preservedDraft` field.
- The draft-preserved metadata should be set only after successful audio-draft
  persistence or after cleanup failure paths where the cleanup use case has
  preserved a text draft.

## Rollout & migration

No feature flag or migration is required. The root route changes from a
placeholder to the main UI when this feature lands. Existing persisted entries,
drafts, preferences, quota state, and route paths remain compatible.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Animation tests become flaky | Medium | Medium | Keep animation assertions focused on visibility, state changes, and retrigger keys; test pure countdown math separately instead of relying on exact frame pixels. |
| Draft-preserved status is shown incorrectly | Medium | High | Add explicit `preservedDraft` metadata and unit/integration tests for audio-draft, text-draft, and non-draft error paths. |
| Saved auto-clear timer clears a newer state | Low | High | Invalidate stale timers with a Saved-state generation token and cover stale-timer behavior in widget tests. |
| Local active-day count is wrong near date boundaries | Medium | Medium | Use local date keys derived from each entry timestamp and add tests with same-day/different-day entries. |
| Root route provider tests need more dependencies than placeholder tests | Medium | Medium | Override repositories, preferences, quota, and controller in widget/integration harnesses. |

## Open items from spec

None.
