# Implementation Plan: Microphone Permission Handling

> **Feature number:** 012
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-18

---

## Approach summary

Complete the existing Flutter permission flow by extending the current
recording stack rather than adding a parallel permission layer. The
microphone permission service will expose prompt, status-check, and
settings-opening operations; the audio and transcription services will gain a
cancel path for permission revocation; and the main recording controller/UI
will distinguish retryable denial from blocked/restricted access. The main
screen will observe foreground resume so settings changes clear or preserve the
blocked state, and active recordings are canceled safely when permission is no
longer granted. The reviewed implementation also needs iOS-aware denied-state
mapping after the first prompt, serialized resume permission refresh with a
timeout fallback, and explicit accessibility semantics for permission states.
Validation will include automated tests, Android emulator runtime checks, real
Android device runtime checks, and iOS simulator runtime checks.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Permission ownership | Keep platform permission checks in `lib/data/audio/microphone_permission_service.dart` | The app already has this service and the dependency is already present. Extending it keeps plugin-specific behavior out of presentation code. |
| Settings navigation | Add settings opening to the microphone permission service | The settings action is part of permission recovery and can be faked in tests without platform channels. This avoids adding a second system-service abstraction for one operation. |
| Permission state model | Distinguish retryable denied, blocked/permanently denied, and restricted states before mapping to UI | The spec requires retryable denial to avoid blocked-settings UX while treating restricted access like blocked access. Carrying the state through the flow avoids guessing in the controller. |
| iOS denied-state handling | Keep first-launch `denied` retryable, but treat iOS `denied` as blocked after a prompt attempt has already occurred in the current app session | iOS may stop showing the microphone prompt after a denial. Session-aware mapping preserves the intended first-try prompt while avoiding a fake retryable state after the user already denied access. |
| Retryable denial UX | Add a retryable microphone-denied error state with non-settings copy such as `mic needed` | A silent reset after denial would be confusing. A short non-blocked status gives feedback while allowing the next tap to request again. |
| Blocked UX | Use `mic blocked · tap settings` for blocked, permanently denied, and restricted states | This is the clarified copy and fits the reserved status-line slot while making the action discoverable. |
| Primary button behavior while blocked | Route blocked-state main-button taps to app settings through the controller | This satisfies the clarified behavior and keeps button/status behavior consistent. |
| Lifecycle monitoring | Let `MainScreen` observe app lifecycle resume and call a controller resume handler | The main screen owns the recording UI and already listens to controller transitions. A local observer keeps startup non-blocking and avoids adding global app bootstrap work. |
| Resume refresh robustness | Serialize resume permission checks and bound them with a timeout | Rapid foreground/background churn should not start overlapping permission refreshes, and a hung plugin call should not wedge the resume path indefinitely. |
| Mid-recording revocation | Add cancel methods to `AudioRecordingService` and `TranscriptionService`; use cancel on permission loss | Stopping through the normal transcription path would upload and possibly save unusable audio. A cancel path keeps the app honest and avoids false successful entries. |
| Cancellation failure handling | Log cancellation errors and keep the transcription service state aligned with the recorder after a failed cancel attempt | The review surfaced the risk of returning to idle while the recorder still reports an active session. State recovery should reflect whether recording actually remains active. |
| Accessibility semantics | Add permission-specific status labels and hints for screen readers | The spec explicitly calls for meaningful assistive labels/actions, and the generic status-message semantics were too vague for blocked and retryable permission states. |
| Analytics | No implementation for US-012 | The finalized spec makes analytics out of scope and reserves it for US-022. |
| Offline speech recognition | No speech-recognition prompt or flow for US-012 | Offline mode is out of scope; existing iOS usage text can remain because it is already present. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `specs/012-microphone-permission-handling/plan.md` | Modify | Approved implementation plan for US-012. |
| `specs/012-microphone-permission-handling/tasks.md` | Modify later | Actionable task checklist after plan approval. |
| `specs/012-microphone-permission-handling/implementation.md` | Create later | Implementation and validation evidence after coding. |
| `lib/data/audio/microphone_permission_service.dart` | Modify | Add non-prompting status check and app-settings launch; preserve platform-state resolution for denied, permanently denied, and restricted, including iOS-specific denied handling after a prompt attempt. |
| `lib/data/audio/audio_recording_service.dart` | Modify | Add app-facing cancel contract for active recordings. |
| `lib/data/audio/record_audio_recording_service.dart` | Modify | Implement cancel by canceling the recorder, deleting partial audio, and clearing active session state. |
| `lib/data/transcription/transcription_service.dart` | Modify | Carry microphone access state in start failures and add live-transcription cancellation. |
| `lib/data/transcription/cloud_transcription_service.dart` | Modify | Preserve permission access state from recording failures and implement cancellation without upload, including logged cancel-failure recovery. |
| `lib/presentation/main/recording_state.dart` | Modify | Add distinct retryable microphone-denied and blocked microphone error states while preserving existing non-permission errors. |
| `lib/presentation/main/main_recording_controller.dart` | Modify | Map permission states, open settings while blocked, serialize/timelimit foreground resume checks, cancel active recording on revoked access, and clear blocked state after settings grant. |
| `lib/presentation/main/main_screen_status.dart` | Modify | Add blocked-settings status action and copy; add retryable-denial status copy and permission-specific accessibility labels/hints. |
| `lib/presentation/main/main_screen.dart` | Modify | Observe lifecycle resume, route settings status action through the controller, and expose permission-specific semantics. |
| `test/data/audio/microphone_permission_service_test.dart` | Create | Cover iOS-specific denied-state mapping and Android retryable denial preservation. |
| `test/data/audio/audio_recording_service_test.dart` | Modify | Cover cancel behavior and existing permission-denied state preservation. |
| `test/data/transcription/cloud_transcription_service_test.dart` | Modify | Cover permission-state propagation and cancellation without upload. |
| `test/presentation/main/main_recording_controller_test.dart` | Modify | Cover retryable denial, blocked/restricted denial, settings button behavior, resume recovery, and revocation cancellation. |
| `test/presentation/main/main_screen_status_test.dart` | Modify | Cover new status copy and actions. |
| `test/presentation/main/main_screen_test.dart` | Modify | Cover blocked status text, settings tap wiring, primary-button blocked behavior as needed, and lifecycle observer integration. |
| `integration_test/main_screen_permission_flow_test.dart` | Create | Provider-level main-screen permission flows using test doubles for permission status, settings launch, and transcription cancellation. |
| `integration_test/audio_recording_service_flow_test.dart` | Modify | Update fakes for the expanded audio recording contract. |
| `integration_test/main_recording_controller_flow_test.dart` | Modify | Update fakes for the expanded transcription contract and add provider-level revocation coverage if it fits better here than the new main-screen permission flow. |
| `integration_test/main_screen_flow_test.dart` | Modify | Update existing fake transcription service for the expanded contract and adjust existing blocked-copy expectations. |

No Android manifest, iOS plist, dependency, backend API, or database migration
file changes are expected.

## API contract details

This feature introduces no backend HTTP contract changes.

Application-facing contract changes:

- `MicrophonePermissionService` will expose:
  - a prompting operation for user-initiated recording attempts
  - a non-prompting operation for lifecycle/status checks
  - an app-settings launch operation returning success/failure
  - iOS-aware denied-state mapping that becomes blocked after a prompt attempt
- `RecordingPermissionDeniedFailure` and the transcription start failure will
  preserve the resolved microphone access state.
- `AudioRecordingService` and `TranscriptionService` will expose cancellation
  for active live recording sessions.

Failure behavior:

- `denied` maps to retryable microphone-denied UI and does not open settings
  automatically.
- `permanentlyDenied` and `restricted` map to blocked-settings UI.
- Opening settings failure is logged for developers and leaves the blocked
  status available.
- Revocation while recording cancels capture, suppresses upload/save, and
  publishes a permission error.

## Data model changes

No persistent data model changes are required.

### Before

```text
RecordingError:
  tooShort
  noMatch
  insufficientPermissions
  noInternet
  backendUnavailable
  proxyAuthFailed
  apiFailed
```

### After

```text
RecordingError:
  tooShort
  noMatch
  microphoneDenied        // retryable, no settings action
  microphoneBlocked       // blocked/permanent/restricted, opens settings
  noInternet
  backendUnavailable
  proxyAuthFailed
  apiFailed
```

The existing `insufficientPermissions` value will be replaced in current
callers by the two more specific permission states. No stored values or
database rows depend on this enum.

### Migration

No persistent migration is required.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| iOS microphone denial stays retryable before the first prompt attempt and becomes blocked after a denied request result | Unit | `test/data/audio/microphone_permission_service_test.dart` |
| Microphone denied before recorder start preserves retryable access state and does not touch recorder | Unit | `test/data/audio/audio_recording_service_test.dart` |
| Microphone permanently denied and restricted preserve blocked access state | Unit | `test/data/audio/audio_recording_service_test.dart` |
| Active audio recording cancel clears active state, cancels recorder, and deletes partial audio | Unit | `test/data/audio/audio_recording_service_test.dart` |
| Cloud transcription start failure preserves microphone access state | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Cloud transcription cancel does not upload audio and clears live recording state | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Cloud transcription cancel logs recorder failures and stays recoverable for the live session | Unit | `test/data/transcription/cloud_transcription_service_test.dart` |
| Controller maps retryable denial to non-blocked retryable UI | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Controller maps permanent, blocked, and restricted states to blocked-settings UI | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Controller opens settings from blocked primary-button taps and logs settings-launch failure | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Controller clears blocked state on resume after permission grant | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Controller preserves blocked state on resume when permission is still blocked | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Controller cancels active recording on resume when permission has been revoked | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Controller suppresses overlapping resume permission checks and times out hung permission refreshes without changing state | Unit | `test/presentation/main/main_recording_controller_test.dart` |
| Status resolver returns `mic blocked · tap settings` with settings action | Unit | `test/presentation/main/main_screen_status_test.dart` |
| Status resolver returns retryable denied copy without settings action | Unit | `test/presentation/main/main_screen_status_test.dart` |
| Status resolver returns permission-specific accessibility labels and hints | Unit | `test/presentation/main/main_screen_status_test.dart` |
| Main screen status tap invokes settings action | Widget | `test/presentation/main/main_screen_test.dart` |
| Main screen exposes permission-specific semantics for retryable and blocked permission states | Widget | `test/presentation/main/main_screen_test.dart` |
| Main screen lifecycle resume calls the controller permission refresh path | Widget | `test/presentation/main/main_screen_test.dart` |
| First recording tap requests permission and denial remains retryable | Integration | `integration_test/main_screen_permission_flow_test.dart` |
| Blocked permission status and primary button both open settings | Integration | `integration_test/main_screen_permission_flow_test.dart` |
| Restricted permission follows the blocked settings recovery path | Integration | `integration_test/main_screen_permission_flow_test.dart` |
| Granting permission from settings and resuming clears blocked status | Integration | `integration_test/main_screen_permission_flow_test.dart` |
| Permission revocation during active recording cancels capture and does not save/upload | Integration | `integration_test/main_screen_permission_flow_test.dart` |
| Existing main-screen and recording flows still pass with expanded contracts | Integration | `integration_test/main_screen_flow_test.dart`, `integration_test/main_recording_controller_flow_test.dart`, `integration_test/audio_recording_service_flow_test.dart` |

### Android emulator verification

Use an Android emulator targeting app ID `com.wrait.flutter`.

1. Reset or freshly install the app so microphone permission is not granted.
2. Cold launch with `adb shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`.
3. Tap the recording button and verify the Android microphone prompt appears before recording starts.
4. Deny the prompt without permanently blocking it and verify the app does not record and remains retryable without `mic blocked · tap settings`.
5. Put the app into a permanently denied or restricted microphone state through the system permission UI or emulator permission tooling.
6. Return to Wrait and verify `mic blocked · tap settings` appears.
7. Tap the blocked status line and verify Android opens Wrait's app settings page.
8. Return to Wrait, tap the primary recording button while still blocked, and verify it opens Wrait's app settings page.
9. Grant microphone permission from settings, return to Wrait, and verify blocked feedback clears without restarting the app.
10. Start recording with permission granted, revoke microphone permission from settings or emulator tooling, return to Wrait, and verify recording cancels into a permission error without upload/save success.

### Real Android device verification

Use exactly one connected physical Android phone targeting app ID
`com.wrait.flutter`.

1. Prefer `./deploy_debug.sh` with `PROXY_SECRET` set when backend-backed
   recording/transcription flows are part of the validation run.
2. Reset Wrait's microphone permission state on the physical phone, or freshly
   install the app so microphone permission is not granted.
3. Cold launch with `adb -s <phone-serial> shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`.
4. Tap the recording button and verify the Android microphone prompt appears
   before recording starts.
5. Deny the prompt without permanently blocking it and verify the app does not
   record and remains retryable without `mic blocked · tap settings`.
6. Put the app into a permanently denied or restricted microphone state through
   the phone's system permission UI.
7. Return to Wrait and verify `mic blocked · tap settings` appears.
8. Tap the blocked status line and verify Android opens Wrait's app settings
   page.
9. Return to Wrait, tap the primary recording button while still blocked, and
   verify it opens Wrait's app settings page.
10. Grant microphone permission from settings, return to Wrait, and verify
    blocked feedback clears without restarting the app.
11. Start recording with permission granted, revoke microphone permission from
    settings, return to Wrait, and verify recording cancels into a permission
    error without upload/save success.
12. Preserve the current deploy-script safety guidance: do not uninstall
    `com.wrait.app`, keep `com.wrait.flutter` as the Flutter target, and use
    the profile final install artifact when validating the same deployed state
    as `./deploy_debug.sh`.

### iOS simulator verification

Use an iOS simulator targeting bundle ID `com.wrait.app`.

1. Reset or freshly install the app so microphone permission is not granted.
2. Launch the app on the simulator.
3. Tap the recording button and verify the iOS microphone prompt appears before recording starts.
4. Deny the prompt and verify the app does not record; because iOS does not keep presenting the same prompt after denial, verify the app reaches `mic blocked · tap settings`.
5. Tap the blocked status line and verify iOS opens Wrait's app settings page.
6. Return to Wrait, tap the primary recording button while still blocked, and verify it opens Wrait's app settings page.
7. Grant microphone permission from settings, return to Wrait, and verify blocked feedback clears without restarting the app.
8. Start recording with permission granted, revoke microphone permission from settings or simulator privacy tooling, return to Wrait, and verify recording cancels into a permission error without upload/save success.

### Validation exception request

No validation exception is requested. The plan includes `integration_test`
coverage for every in-scope user flow plus Android emulator, real Android
device, and iOS simulator runtime verification.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After implementation, stop and wait for external `review.md` unless the user
  explicitly skips review.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates to
  `docs/application-description.md` and `docs/agent-findings.md` after final
  approval because it changes the recorded product behavior and future guidance
  for permission handling. `AGENTS.md` probably does not need an update unless
  validation discovers new platform-specific permission guidance.

## Integration notes

- The current `permission_handler` dependency is already present in
  `pubspec.yaml`; no dependency addition is planned.
- The Android app already declares `android.permission.RECORD_AUDIO`.
- The iOS app already declares microphone and speech-recognition usage
  descriptions. Speech-recognition prompting remains out of scope.
- The app must keep startup non-blocking. Permission checks happen from user
  recording actions or main-screen resume handling, not from app bootstrap.
- Existing backend transcription and cleanup contracts are unchanged.

## Rollout & migration

This is a normal app-code rollout with no feature flag, backend migration, or
database migration. Existing users with microphone permission already granted
should continue into recording without seeing a new prompt. Users who have
previously denied or blocked microphone access will be classified from the
current platform permission state on their next recording attempt or foreground
resume.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Platform permission states differ between Android and iOS | Medium | High | Keep state interpretation centralized in the permission service and verify Android emulator, real Android device, and iOS simulator. |
| Revocation cancellation races with stop/upload actions | Medium | High | Use controller in-flight guards plus transcription/audio cancel methods; add unit coverage around active recording revocation. |
| Opening app settings is hard to assert in automated tests | Medium | Medium | Wrap settings launch in the permission service and assert calls through fakes; verify real settings navigation manually on both platforms. |
| Retryable denied copy adds small UI surface not previously approved | Low | Medium | Keep it concise, non-settings, and in the existing status-line pattern; exact copy can be adjusted during implementation if it crowds the reserved slot. |
| Existing tests using fake services break after interface expansion | High | Low | Update fakes in the same implementation pass and keep expanded contracts minimal. |
| iOS treats denial as effectively blocked after the first prompt | Medium | Medium | Plan platform-specific runtime verification and map non-promptable states to blocked settings recovery. |

## Open items from spec

No open questions remain in the approved spec.
