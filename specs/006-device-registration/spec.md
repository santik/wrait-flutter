# Feature Specification: Device Registration

> **Feature number:** 006
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-10
> **Work item:** US-016

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-10 | Draft | Codex | Initial spec created from `plan/us_016.md`, the project SDD workflow, the current Flutter app state, the checked-in backend contract, and the referenced Android behavior |
| 2026-06-10 | Draft | Codex | Refined with user decisions: preserve the previous valid quota state when registration succeeds without usable quota data, and treat backend identity compatibility as a fresh-install-only rule with no migration of existing stored identifiers in this story |
| 2026-06-10 | Draft | Codex | Clarify phase finalized: quota reuse is in-memory only with no persistence, app launch must not be blocked on registration completion, successful registration without quota is silent, failed registration is logging-only in this story, and older incompatible stored identifiers remain out of scope |
| 2026-06-10 | Approved | Codex | User approved the finalized clarified spec for planning and implementation preparation |
| 2026-06-10 | In Progress | Codex | Implemented launch registration orchestration, session quota state, backend-compatible new device-ID hashing, automated validation, and Android/iOS runtime verification ahead of external review |
| 2026-06-10 | Complete | Codex | Review was explicitly skipped, long-lived documentation updates were approved and applied, and the knowledge-capture gate is complete |

---

## Overview

The app needs a launch-time device registration flow so the backend can
recognize the current installation for beta access gating and daily quota
tracking before later backend-assisted features depend on that state. Without
this feature, the Flutter app can talk to the backend in principle, but it
does not yet establish the registration state that later best-mode flows are
expected to rely on from the moment the app starts.

This feature defines the functional expectations for resolving one anonymous
registration identifier, attempting registration on app launch, and surfacing
usable quota information from a successful registration attempt. The flow must
be resilient: registration should improve backend-aware behavior when it works,
but it must never prevent the user from entering and using the app when the
network or backend is unavailable. The registration attempt belongs to app
launch, but it must run without blocking normal app rendering in this story.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As the app, I want to register the current anonymous installation at launch
  so that the backend can apply beta gating and quota tracking consistently.
- As a user, I want the app to continue opening even if registration fails so
  that backend setup problems do not block ordinary app usage.
- As the app, I want usable quota information from registration to become
  available to downstream flows so that later quota-aware features can start
  from current backend state instead of guessing.

## Acceptance criteria

- [ ] On every app launch, the app attempts device registration before any
      later launch-time flow that depends on registration or quota state.
- [ ] The registration attempt does not block ordinary app startup or initial
      rendering in this story.
- [ ] The app resolves one anonymous registration identifier and reuses that
      same identifier across later launches unless the locally stored app data
      is intentionally reset.
- [ ] The identifier sent during registration satisfies the current backend
      contract for device identity.
- [ ] A successful registration response is treated as success even when quota
      information is absent, as long as the response is otherwise usable.
- [ ] When registration succeeds without usable quota data, the app leaves the
      current in-memory quota state unchanged without surfacing a user-visible
      warning.
- [ ] When registration succeeds and the response contains valid quota data,
      the app updates its current quota state so later feature flows can read
      it.
- [ ] Invalid or internally inconsistent quota data from registration is
      treated as unavailable and must not replace the previously known valid
      quota state with nonsensical values.
- [ ] Transient registration failures are retried up to three total attempts
      with bounded backoff before the app gives up for that launch.
- [ ] Non-transient registration failures are not retried.
- [ ] If registration still fails after the allowed attempts, the app records
      diagnostic information and continues launching without blocking the user.
- [ ] Registration failure in this story is logging-only and does not expose a
      user-visible error message.

## API contract

This feature does not introduce a new backend endpoint. It consumes the
existing backend registration endpoint and defines how app launch should use
it.

### `POST /api/register`

**Purpose:**

Associate the current anonymous app installation with the backend so quota and
beta-access behavior can be applied to later backend-assisted operations.

**Request:**

- No JSON body required.
- Includes the required device identity metadata expected by the backend.

**Response (success):**

```json
{
  "ok": true,
  "quota": {
    "limit": 5,
    "count": 1,
    "remaining": 4,
    "resetAt": "2026-06-10T00:00:00Z"
  }
}
```

`quota` may be absent. When present, it must be validated before use.

**Error responses:**

| Status | Body | When |
| --- | --- | --- |
| 4xx | `{ "error": "..." }` | Request rejected for validation, auth, or other non-transient reasons |
| 5xx | `{ "error": "..." }` | Backend unavailable or internal failure |
| Timeout / connectivity failure | transport-level failure | Request did not complete successfully |

## Data model changes

This feature introduces or activates functional application state for:

- current launch registration outcome
- current in-memory record-quota state derived from registration when valid
- one stable anonymous registration identifier suitable for backend requests

Functional expectations:

- The registration identifier must remain stable across launches.
- The app must be able to distinguish success, retryable failure, and
  non-retryable failure well enough to enforce the launch rules above.
- Quota state derived from registration must only be considered available when
  it passes internal consistency checks.
- If a registration attempt succeeds without usable quota data, the app keeps
  the previous valid in-memory quota state instead of replacing it with an
  invalid or empty value.
- The quota reuse requirement in this story is session-scoped only and does
  not introduce persistence of quota across app relaunches.
- This story does not migrate previously stored local identifiers that may not
  satisfy the backend identity contract; compatibility requirements apply to
  the registration identifier behavior implemented for this story going
  forward.

## Dependencies

- [ ] Existing Flutter startup/bootstrap flow
- [ ] Existing local preferences/device-identity capability
- [ ] Existing backend registration client and checked-in backend contract
- [ ] Backend availability and network connectivity at launch time when
      registration is attempted

## UX / design references

No dedicated visual design is required for this story.

This feature is primarily launch-time behavior and shared application state for
later flows.

## Non-functional requirements

- **Performance:** Launch-time registration must not make app startup feel
  hung or indefinitely delayed. Retry behavior must stay bounded.
- **Security:** The registration identifier must remain anonymous from the
  product perspective and must not require exposing raw hardware identifiers to
  the rest of the app.
- **Reliability:** Registration failure must degrade gracefully without
  trapping the user in a broken startup flow.
- **Scalability:** The resulting quota state should be reusable by later
  backend-assisted stories without duplicating registration logic.
- **Observability:** Failed registration attempts should leave enough
  diagnostic signal to distinguish transient launch issues from persistent
  contract or configuration problems, even though this story does not add
  user-visible registration error messaging.
- **Maintainability:** Registration should remain one centralized launch
  concern rather than being reimplemented separately by later features.

## Out of scope

- Adding or redesigning UI beyond whatever existing launch surfaces later read
  the resulting quota state
- Recording, transcription, transcript cleanup, or draft retry behavior beyond
  ensuring registration runs before those later launch-time consumers when they
  exist
- User accounts, sign-in, or named-device management
- Background refresh, periodic re-registration outside app launch, or
  foreground-resume registration
- Changing the backend registration endpoint contract itself
- Migrating previously stored local device identifiers that do not satisfy the
  current backend identity contract
- Persisting quota state across app relaunches
- User-visible registration error presentation

## Open questions

None at this stage.
