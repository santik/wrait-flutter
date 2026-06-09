# Feature Specification: Backend API Client

> **Feature number:** 005
> **Status:** In Progress
> **Author:** Codex
> **Date:** 2026-06-09
> **Work item:** US-005

## Status history

| Date       | Status | Author | Notes |
| ---------- | ------ | ------ | ----- |
| 2026-06-09 | Draft | Codex | Initial spec created from `plan/us_005.md`, the project SDD workflow, the current Flutter product context, and the referenced backend contract artifacts |
| 2026-06-09 | Draft | Codex | Clarify phase incorporated: the checked-in OpenAPI contract is the source of truth, quota should be propagated whenever the backend provides valid data, and registration may use a narrower failure surface than transcription and cleanup |
| 2026-06-09 | Draft | Codex | Analyze phase aligned the spec with the approved plan: the Flutter codebase keeps a checked-in copy of the backend OpenAPI contract for generation while preserving the original contract as the upstream synchronization source |
| 2026-06-09 | In Progress | Codex | Implemented the generated backend client layer, the handwritten adapter, automated unit/regression coverage, and Android/iOS device validation ahead of the first external review pass |
| 2026-06-09 | In Progress | Codex | Approved review remediation replaced the custom local generator with the official OpenAPI Generator CLI `dart-dio` workflow while keeping the app-facing US-005 behavior unchanged |
| 2026-06-09 | In Progress | Codex | Approved second review remediation added explicit request-too-large and quota-exceeded failure mapping plus explicit transport timeout configuration |

---

## Overview

The Flutter app needs one centralized way to communicate with the Wrait backend
for the cloud-assisted parts of the journaling flow. Without this feature,
later stories for launch-time device registration, best-mode transcription, and
transcript cleanup would each need to construct their own backend requests and
invent their own success, quota, and error-handling rules. That would make the
app harder to evolve and more likely to behave inconsistently across flows.

This feature defines the functional contract for backend communication that the
rest of the app can rely on. It must let the app register a device, submit
audio for transcription, and submit raw transcript text for cleanup, while
ensuring required request identity/authentication data is attached, backend
quota information is handled safely, and failures are translated into
application-meaningful outcomes instead of transport-level surprises.

The checked-in backend OpenAPI contract is the source of truth for the request
and response shapes this feature consumes. Story shorthand or downstream code
must align to that contract rather than redefining endpoint payloads locally.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As the app, I want one backend communication contract for registration,
  transcription, and cleanup so that later features do not duplicate request
  construction or error-handling rules.
- As a user in best mode, I want my recorded audio sent to the backend and
  returned as text so that I can create a diary entry from speech.
- As a user in best mode, I want my raw transcript cleaned up by the backend so
  that the saved entry reads more naturally.
- As the app, I want usable quota information returned whenever the backend
  provides valid quota data so that later UI and workflow logic can react to
  daily usage limits consistently.

## Acceptance criteria

- [ ] The app exposes one centralized application-facing contract for backend
      registration, transcription, and cleanup operations.
- [ ] The registration operation can submit the app's device identity to the
      backend and return either success with optional valid quota information or
      a bounded failure outcome that callers can handle safely without exposing
      the full transport-level error space.
- [ ] The registration operation retries transient timeout, connectivity, and
      backend-unavailable failures within a bounded number of attempts before
      returning final failure.
- [ ] The transcription operation can submit recorded audio and the required
      backend-defined request payload for transcription processing, and on
      success returns the transcript text, the backend-detected language when
      provided, and optional valid quota information.
- [ ] The cleanup operation can submit raw transcript text plus language and on
      success returns cleaned text and optional valid quota information.
- [ ] Every backend request made through this feature includes the required
      device identity and proxy-authentication information expected by the
      backend contract.
- [ ] Quota data is accepted only when it is internally consistent. Invalid
      quota values are treated as unavailable rather than replacing a previously
      valid quota state with nonsensical data.
- [ ] When the backend includes valid quota information in either a success or
      non-success response, that quota data is surfaced to callers whenever the
      operation contract can do so safely.
- [ ] Backend failures are translated into application-meaningful error
      categories so callers can distinguish timeout, no-internet or network
      failure, request-too-large rejection, quota-exceeded rejection,
      proxy-authentication failure, backend unavailability, and other
      non-success API responses.
- [ ] Missing, malformed, blank, or otherwise unusable success payload fields
      are treated as operation failure rather than as silently successful
      results with broken data.
- [ ] Unit-level automated coverage exists for success paths, quota validation,
      retry behavior, and the expected error mappings for all three operations.

## API contract

This feature does not introduce new backend endpoints. It consumes the existing
Wrait backend OpenAPI contract through a checked-in Flutter-side copy used for
generation, while preserving the original contract file as the upstream source
that the copied version must stay synchronized with.

All operations require:

- backend base URL supplied by app configuration
- proxy-authentication credential supplied by app configuration
- device identity attached to every request

### `POST /api/register`

**Purpose:**

Register or upsert the current app/device identity with the backend so later
quota-tracked best-mode operations can be associated with that device.

**Request:**

- No JSON body required.
- Includes required device identity and proxy-authentication request metadata.

**Response (success):**

```json
{
  "ok": true,
  "quota": {
    "limit": 10,
    "count": 3,
    "remaining": 7,
    "resetAt": "2026-06-10T00:00:00Z"
  }
}
```

`quota` may be absent. When present, it must be validated before use.

**Error responses:**

| Status | Body | When |
| ------ | ---- | ---- |
| 401 | `{ "error": "..." }` | Proxy-authentication credential missing or invalid |
| 5xx | `{ "error": "..." }` | Backend unavailable or internal failure |
| Other non-success | `{ "error": "..." }` | Request rejected for another backend-defined reason |

### `POST /api/transcribe`

**Purpose:**

Submit recorded audio for backend transcription and return transcript text plus
any backend-detected language and quota information.

**Request:**

```text
multipart form data containing the recorded audio file, using the exact request
shape defined by the checked-in OpenAPI contract
```

**Response (success):**

```json
{
  "transcript": "Today I went for a walk by the river.",
  "detected_language": "en-US",
  "quota": {
    "limit": 10,
    "count": 4,
    "remaining": 6,
    "resetAt": "2026-06-10T00:00:00Z"
  }
}
```

`quota` may be absent. Blank transcript content is not a usable success result.
The backend contract currently defines `detected_language` as required in the
success payload.

**Error responses:**

| Status | Body | When |
| ------ | ---- | ---- |
| 401 | `{ "error": "..." }` | Proxy-authentication credential missing or invalid |
| 429 | `{ "error": "...", "quota": { ... } }` | Device has reached the applicable quota limit |
| 5xx | `{ "error": "..." }` | Backend unavailable or upstream failure |
| Other non-success | `{ "error": "..." }` | Request rejected for another backend-defined reason |

### `POST /api/cleanup`

**Purpose:**

Submit a raw transcript plus language so the backend can return diary-ready
cleaned text.

**Request:**

```json
{
  "transcript": "raw transcript text",
  "language": "en-US"
}
```

**Response (success):**

```json
{
  "cleanedText": "Cleaned transcript text.",
  "wasTruncated": false,
  "quota": {
    "limit": 10,
    "count": 4,
    "remaining": 6,
    "resetAt": "2026-06-10T00:00:00Z"
  }
}
```

`quota` may be absent. Blank cleaned text is not a usable success result.

**Error responses:**

| Status | Body | When |
| ------ | ---- | ---- |
| 401 | `{ "error": "..." }` | Proxy-authentication credential missing or invalid |
| 429 | `{ "error": "...", "quota": { ... } }` | Device has reached the applicable quota limit |
| 5xx | `{ "error": "..." }` | Backend unavailable or upstream failure |
| Other non-success | `{ "error": "..." }` | Request rejected for another backend-defined reason |

## Data model changes

This feature introduces application-facing backend result contracts for:

- registration outcome
- transcription outcome
- cleanup outcome
- record quota state

Functional expectations for quota data:

- `limit`, `count`, and `remaining` must all be non-negative
- `count` must not exceed `limit`
- `remaining` must not exceed `limit`
- `resetAt` must identify when the current quota window resets
- invalid quota data must be ignored rather than exposed as valid state
- callers should be able to preserve their last valid quota state when a newly
  received quota payload is invalid and therefore discarded

No local persistence migration is required for this story by itself.

## Dependencies

- [ ] Existing Flutter app foundation and runtime configuration support
- [ ] Existing app/device identity capability available to request callers
- [ ] The deployed Wrait backend endpoints for registration, transcription, and
      cleanup
- [ ] Network connectivity when backend-assisted operations are invoked

## UX / design references

No dedicated visual design is required for this story.

This feature provides data-layer behavior that later launch, recording, quota,
and entry-saving flows will consume.

## Non-functional requirements

- **Performance:** Request setup and response handling should add minimal
  overhead beyond network latency so best-mode flows remain responsive.
- **Security:** Required proxy-authentication and device identity metadata must
  be attached to every backend request, and no secret material should be
  exposed through logs, source control, or user-visible error text.
- **Reliability:** Transport failures, invalid payloads, and inconsistent quota
  data must resolve to safe failure outcomes without crashing the app.
- **Scalability:** The backend client contract should support reuse by later
  registration, transcription, retry, and cleanup stories without each feature
  redefining backend behavior.
- **Observability:** Validation evidence should demonstrate request success,
  retry behavior for registration, quota validation, and error-category mapping
  for all supported operations.
- **Maintainability:** Backend request and response rules should be centralized
  so future contract changes are made in one place instead of scattered through
  the app.

## Out of scope

- Launch-time orchestration of when registration is called
- Recording UI, recording lifecycle, or local audio capture behavior
- Entry creation, entry persistence, draft recovery, or transcript word-count
  updates
- Quota display UI or quota-state persistence outside the backend client result
  contract
- Offline transcription or offline cleanup behavior
- Backend API design changes beyond consuming the existing contract

## Open questions

None at this stage.
