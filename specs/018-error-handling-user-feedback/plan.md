# Implementation Plan: Error Handling and User Feedback

> **Feature number:** 018
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-22

---

## Approach summary

US-018 will keep the existing Flutter feedback architecture and make the
smallest changes needed to satisfy the approved spec. The main status resolver
will continue to own user-facing copy, the recording controller will continue
to own error state and auto-clear timing, and the existing button animation will
continue to own shake feedback. The implementation will add category-specific
draft-preserved copy, keep the approved no-draft fallback copy, and remove the
special case that prevents blocked microphone errors from auto-clearing.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Status copy ownership | Keep status text in `resolveMainScreenStatus()` | The app already centralizes main-screen feedback there, so extending it avoids another mapping layer and keeps the change easy to test. |
| Draft-preserved feedback | Map preserved-draft errors by their existing `RecordingError` category | The controller already carries both the failure category and `preservedDraft`; using those fields satisfies the spec without adding state types. |
| No-draft fallback copy | Keep current strings: `no connection`, `service unavailable`, `server config error`, `something went wrong` | The user explicitly approved keeping existing fallback behavior when no draft was preserved. |
| Permission auto-clear | Schedule the same 3-second error auto-clear for `microphoneBlocked` as for other errors | The finalized spec requires every error message to auto-clear. After auto-clear, tapping the main button can re-check permission and surface the message again if still blocked. |
| Shake animation | Keep the existing shake-key and `ButtonArea` animation pattern | The current flow already limits shake triggers to too-short/no-match errors and the widget test covers that the button moves when the key changes. |
| Non-blocking messages | Do not add new settings/language snackbar behavior in this story | Language and new settings persistence are out of scope, and no current in-scope non-blocking failure needs a new surface for US-018. Existing snackbar behavior elsewhere remains unchanged. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `specs/018-error-handling-user-feedback/spec.md` | Modify | Already updated to approved status and clarified scope. |
| `specs/018-error-handling-user-feedback/plan.md` | Modify | This implementation plan. |
| `specs/018-error-handling-user-feedback/tasks.md` | Modify later | Replace copied template with approved task breakdown in the next phase. |
| `specs/018-error-handling-user-feedback/implementation.md` | Create later | Record implementation details and validation evidence during implementation. |
| `lib/presentation/main/main_screen_status.dart` | Modify | Show category-specific preserved-draft copy while retaining existing no-draft fallback copy and permission/action semantics. |
| `lib/presentation/main/main_recording_controller.dart` | Modify | Schedule auto-clear for blocked microphone errors using the existing feedback delay. |
| `test/presentation/main/main_screen_status_test.dart` | Modify | Cover preserved-draft copy for network/backend/proxy/API categories, fallback copy, and existing permission copy. |
| `test/presentation/main/main_recording_controller_test.dart` | Modify | Cover blocked microphone auto-clear and preserve existing settings/retry behavior expectations after auto-clear. |
| `test/presentation/main/button_area_test.dart` | Modify | Strengthen coverage that shake starts for too-short/no-match key changes and does not start when non-shake errors keep the same key, if current coverage is not sufficient during implementation. |
| `integration_test/main_recording_controller_flow_test.dart` | Modify | Assert preserved-draft controller states still carry the correct category and add status resolver expectations for the user-facing draft-preserved copy. |
| `integration_test/main_screen_flow_test.dart` | Modify | Verify a visible draft-preserved status message on the main screen and blocked microphone auto-clear behavior with shortened feedback delays. |
| `integration_test/main_screen_permission_flow_test.dart` | Modify if needed | Adjust blocked-permission expectations that currently assume the status remains indefinitely. |

## API contract details

No backend HTTP contract changes are required.

The app-facing feedback contract will be:

- `RecordingError.tooShort` -> `too short · keep talking`
- `RecordingError.noMatch` -> `nothing caught · too quiet?`
- `RecordingError.microphoneBlocked` -> `mic blocked · tap settings`
- `RecordingError.noInternet` with `preservedDraft=true` ->
  `no connection · saved as draft`
- `RecordingError.backendUnavailable` with `preservedDraft=true` ->
  `service unavailable · saved as draft`
- `RecordingError.proxyAuthFailed` with `preservedDraft=true` ->
  `server config error · saved as draft`
- `RecordingError.apiFailed` with `preservedDraft=true` ->
  `saved as draft · will retry`
- `RecordingError.noInternet` with `preservedDraft=false` -> `no connection`
- `RecordingError.backendUnavailable` with `preservedDraft=false` ->
  `service unavailable`
- `RecordingError.proxyAuthFailed` with `preservedDraft=false` ->
  `server config error`
- `RecordingError.apiFailed` with `preservedDraft=false` ->
  `something went wrong`

`RecordingError.microphoneDenied` will keep the existing retryable-denial copy
`mic needed · tap again` because the approved spec says to keep existing simple
behavior where it already supports the user flow.

All `RecordingErrorState` values will schedule the existing error auto-clear
delay, which defaults to 3 seconds.

## Data model changes

No data model changes are required.

### Before

```text
RecordingErrorState(error, preservedDraft)
```

### After

```text
RecordingErrorState(error, preservedDraft)
```

### Migration

No migration is required.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Status resolver maps all approved preserved-draft and no-draft error copy | Unit | `test/presentation/main/main_screen_status_test.dart` |
| Status resolver keeps permission action and accessibility semantics | Unit | `test/presentation/main/main_screen_status_test.dart` |
| Too-short and no-match increment the shake key; non-shake errors do not | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Blocked microphone error auto-clears after the configured error delay | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Starting a new recording cancels stale error auto-clear timers | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Button shake animation moves the primary action when shake key changes | Widget | `test/presentation/main/button_area_test.dart` |
| Button does not shake for non-shake errors without a shake-key change | Widget | `test/presentation/main/button_area_test.dart` |
| Provider graph preserves audio draft and exposes user-facing network draft copy | Integration | `integration_test/main_recording_controller_flow_test.dart` |
| Provider graph preserves text draft and exposes user-facing backend draft copy | Integration | `integration_test/main_recording_controller_flow_test.dart` |
| Main screen shows draft-preserved feedback and later auto-clears | Integration | `integration_test/main_screen_flow_test.dart` |
| Main screen blocked microphone feedback auto-clears and can be shown again by tapping | Integration | `integration_test/main_screen_flow_test.dart` or `integration_test/main_screen_permission_flow_test.dart` |

Planned validation commands:

```text
flutter test test/presentation/main/main_screen_status_test.dart test/presentation/main/main_recording_controller_test.dart test/presentation/main/button_area_test.dart
flutter test integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart integration_test/main_screen_permission_flow_test.dart
flutter analyze
```

If local project conventions or available devices make the integration command
preferable through `flutter test integration_test`, use the repo's existing
integration-test invocation during implementation and record the exact command
in `implementation.md`.

### Android emulator verification

1. Launch the app on an Android emulator with a shortened feedback delay test
   path or equivalent integration-test target.
2. Verify a preserved-draft network/backend failure shows the approved
   `· saved as draft` copy and returns to idle after the configured delay.
3. Verify blocked microphone feedback shows `mic blocked · tap settings`,
   returns to idle after the configured delay, and can be shown again by
   tapping the main button while permission remains blocked.
4. Record the emulator name/device id, command, and pass/fail evidence in
   `implementation.md`.

### iOS simulator verification

1. Launch the app on an iOS simulator with the same feedback scenarios covered
   by integration tests or an equivalent manual path.
2. Verify preserved-draft copy, blocked microphone auto-clear, and repeat-tap
   recovery behavior match the Android verification expectations.
3. Record the simulator name/device id, command, and pass/fail evidence in
   `implementation.md`.

### Validation exception request

None. This story should satisfy the default integration-test coverage plus
Android emulator and iOS simulator verification requirements.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This story may produce durable product guidance that error copy should stay
  simple, dot-separated, and scoped to the single Best mode. The final
  knowledge-capture gate will decide whether to propose updates to
  `AGENTS.md`, `docs/application-description.md`, or `docs/agent-findings.md`.

## Integration notes

This change integrates only with the existing main recording controller,
status resolver, and main-screen feedback surfaces. It does not change backend
registration, transcription, cleanup, draft creation, draft retry, local
persistence, or entry display behavior.

## Rollout & migration

No feature flag, rollout switch, or data migration is required. The change is
backward-compatible because it only adjusts transient UI feedback and timing.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Blocked microphone auto-clear hides the settings action before the user taps it | Medium | Medium | The approved UX says every error clears after 3 seconds and tapping the main button can re-surface the message; integration coverage will verify that loop. |
| Preserved-draft copy falsely implies a draft exists | Low | High | Only branch on the existing `preservedDraft=true` flag, and preserve no-draft fallback tests. |
| Existing permission tests assume blocked state persists indefinitely | High | Low | Update tests to the approved 3-second behavior while keeping settings action coverage before auto-clear. |
| Shake behavior regresses while touching error handling | Low | Medium | Keep shake-key logic unchanged and retain/strengthen focused tests. |

## Open items from spec

None.
