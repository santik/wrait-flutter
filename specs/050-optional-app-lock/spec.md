# Feature Specification: Optional app lock

> **Feature number:** 050
> **Status:** Approved
> **Author:** Codex
> **Date:** 2026-09-29
> **Work item:** US-050 (local feature identifier)

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-09-29 | Draft | Codex | Initial spec created from the user request |
| 2026-09-29 | Draft | Codex | User approved initial draft; clarification decisions incorporated; finalized spec awaiting approval |
| 2026-09-29 | Approved | Codex | User approved finalized spec; planning authorized |

---

## Overview

Allow users to choose whether Wrait protects access to the app with the device's
configured owner authentication, such as biometrics, device PIN, password, or
pattern. The choice is available in Settings and is remembered across app
sessions.

App lock is disabled by default for users who have not made a choice. Users who
want the additional privacy protection can enable it, while users who do not
want authentication prompts can leave it disabled. This preference does not
weaken the app's separate screenshot, screen-recording, recent-app preview, or
encrypted local-storage protections.

## User stories

- As a user, I want to enable app lock so that opening or returning to Wrait
  requires my device authentication.
- As a user, I want to disable app lock so that I can use Wrait without repeated
  authentication prompts.
- As a new user, I want app lock to start disabled so that protection is
  opt-in.
- As a user, I want my choice remembered so that I do not need to configure it
  every time I use the app.

## Acceptance criteria

- [ ] **AC-01 — Setting:** Settings contains a clearly labelled app-lock switch
  whose current state is unambiguous and accessible.
- [ ] **AC-02 — Default:** App lock is disabled when no app-lock preference has
  been saved, including existing users upgrading from the previously
  always-enabled behavior. A user in this state can launch, background, and
  return to the app without an app-lock authentication prompt.
- [ ] **AC-03 — Enable:** A user with supported device-owner authentication can
  enable app lock. Once enabled, the existing whole-app privacy lock protects
  every app screen on cold launch and after a true foreground exit. Switching
  it on does not request authentication or lock the current session; the first
  authentication occurs on the next cold launch or return after a true
  foreground exit. Any availability check must not prompt for authentication.
- [ ] **AC-04 — Disable:** A user can disable app lock from the already unlocked
  app without authenticating again. Once disabled, the app
  does not show the app-lock overlay or request app-lock authentication on
  launch or foreground return.
- [ ] **AC-05 — Persistence:** A successfully changed preference survives
  navigation, app restart, and normal app updates. It can be changed without a
  network connection and does not require a separate Save action.
- [ ] **AC-06 — Unsupported or unconfigured security:** If supported owner
  authentication is unavailable when enabling app lock, the switch stays off.
  The app gives clear, non-technical guidance and, where available, lets the
  user open the relevant device settings. If device security becomes unavailable
  after the preference was saved as enabled, preserve the existing lock recovery
  behavior without silently changing the saved preference.
- [ ] **AC-07 — Save failure:** If the preference cannot be saved, the switch
  returns to the last persisted state and the app shows a clear, non-technical
  error. The effective lock behavior and displayed state remain consistent.
- [ ] **AC-08 — Existing lock behavior:** When enabled, app lock retains its
  current authentication, retry, lifecycle, privacy-obscuring, and recovery
  behavior, including avoiding relock for transient interruptions caused by a
  system authentication prompt.
- [ ] **AC-09 — Runtime consistency:** Changes take effect without requiring an
  app restart. The Settings state, effective lock behavior, and saved
  preference do not disagree during or after a change.
- [ ] **AC-10 — Privacy boundaries:** Disabling app lock does not disable or
  alter screenshot, screen-recording, recent-app preview, encrypted-storage, or
  other independent privacy protections.
- [ ] **AC-11 — Usability:** The setting and all related guidance have meaningful
  accessibility labels and remain usable at larger text sizes on supported
  phone screens.

## API contract

No backend or HTTP API changes are required. The app-lock choice is device-local
and must not be sent to the backend.

## Data model changes

Add one device-local app-lock preference with enabled and disabled states. A
missing preference resolves to disabled. The preference must survive normal app
updates and must not contain biometric data, credentials, PINs, passwords, or
patterns; authentication secrets remain owned by the device operating system.

Existing installations that predate this preference also default to disabled
on upgrade; their previous always-enabled behavior is not carried forward.
Once a user explicitly chooses a value, subsequent updates preserve it.

## Dependencies

- Existing Settings navigation and screen work.
- Existing whole-app privacy lock and device-owner authentication behavior.
- Existing device-security settings recovery behavior.
- Existing device-local preference storage.

## UX / design references

No external design was supplied. The functional surface is a Settings row with
a clearly labelled app-lock switch and concise supporting text explaining that
the app uses the device's configured screen lock. Failure or unavailable states
must explain the next action without exposing technical diagnostics.

Exact wording, placement, and interaction presentation will be decided during
planning after the specification is clarified and approved.

## Non-functional requirements

- **Performance:** Reading the preference must not add a blocking authentication
  prompt or noticeably delay first usable content when lock is disabled.
- **Security:** The app must rely only on device-owner authentication and must
  never collect or persist biometric data, PINs, passwords, or patterns. State
  transitions must not expose protected content while an enabled lock is active.
- **Reliability:** Persisted state, displayed state, and effective behavior must
  agree across launches and lifecycle changes. Concurrent taps or lifecycle
  events must not produce duplicate authentication or settings requests.
- **Scalability:** Not applicable; this is one device-local boolean preference.
- **Observability:** Failures may be recorded for development diagnostics, but
  logs must not contain authentication secrets or sensitive journal content.

## Test strategy

Cover the default-disabled experience, enabling, disabling, restart
persistence, and immediate runtime behavior. Cover devices with supported
authentication, no configured device security, unavailable authentication, a
canceled authentication attempt, preference-save failure, repeated taps, and
relevant foreground/background transitions.

Verify that upgrading an installation without a saved preference defaults to
off. Enabling must not prompt or lock the current session, but must protect the
next cold launch or foreground return. Disabling from an unlocked session must
not prompt for authentication. Test cancellation at the subsequent unlock,
and distinguish an unavailable enable attempt from loss of device security
after app lock was already enabled.

Verify that enabled mode preserves the existing lock behavior across all app
screens and that disabled mode produces no app-lock prompt or overlay. Confirm
that native capture privacy remains active regardless of the app-lock setting.
Planning must map every in-scope user flow to `integration_test` coverage and
define Android emulator and iOS simulator verification. No validation exception
is requested.

## Out of scope

- Creating an app-specific PIN, password, pattern, or biometric enrollment.
- Replacing or configuring the device operating system's security credentials.
- Per-screen, per-entry, scheduled, or timeout-based lock policies.
- Account synchronization or remote administration of the preference.
- Changes to native capture privacy, encrypted local storage, or backend access.

## Clarification decisions

Confirmed by the user on 2026-09-29:

1. The disabled default applies to existing users upgrading without a saved
   app-lock preference as well as new users.
2. Switching app lock off does not require additional authentication.
3. Do not add an immediate authentication confirmation when switching app lock
   on; authentication can occur the next time the app would normally lock.

## Open questions

None. Finalized specification approved for planning.
