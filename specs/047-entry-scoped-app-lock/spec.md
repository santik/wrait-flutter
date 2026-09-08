# Feature Specification: Entry-scoped privacy lock

> **Feature number:** 047
> **Status:** In Progress
> **Author:** Codex
> **Date:** 2026-09-08
> **Work item:** Not assigned

## Status history

| Date       | Status | Author | Notes |
| ---------- | ------ | ------ | ----- |
| 2026-09-08 | Draft  | Codex  | Initial draft for requiring device authentication only when reviewing entries. |
| 2026-09-08 | Draft  | Codex  | Clarified: retain the current device-authentication policy and require authentication for each return to the entries area. |
| 2026-09-08 | Approved | Codex | Final functional specification approved for implementation planning. |
| 2026-09-08 | In Progress | Codex | Implementation started on codex/feat/entry-scoped-app-lock. |

---

## Overview

Wrait should protect saved and draft journal entries while keeping the main
recording experience available without an unlock step. This allows a user to
start recording quickly while preventing someone who opens the app from
reading existing journal content.

The protected area includes the entries list and individual entry views. The
feature changes where the existing device-authentication policy is required;
it retains that policy, including any supported system fallback and recovery
behavior. It does not change entry data or operating-system capture privacy
behavior.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a journal user, I want to open the main recording screen without
  authenticating so that I can capture a thought immediately.
- As a journal user, I want my saved and draft entries to require device
  authentication before they are displayed so that private writing is not
  exposed to someone holding my device.
- As a journal user, I want to move between the entries list and an entry view
  after one successful authentication so that reviewing entries is not
  unnecessarily interrupted.
- As a journal user, I want the protected area to relock after I leave it or
  after the app returns from a true foreground exit so that entries remain
  protected when I am no longer actively reviewing them.

## Acceptance criteria

- [ ] On a normal launch to the main screen, the user can use the recording
      experience without first authenticating.
- [ ] Entering the entries list requires successful device authentication before
      any entry content or entry metadata is displayed.
- [ ] Opening an individual entry requires successful device authentication
      before the entry content is displayed, whether the user arrived through
      normal navigation or a direct link.
- [ ] After successful authentication, the user can move between the entries
      list and individual entry views without another prompt during the same
      protected visit.
- [ ] Leaving the protected entries area makes the main screen available
      without authentication.
- [ ] Re-entering the protected entries area after leaving it requires
      authentication again, including when the app remained in the foreground.
- [ ] If the app undergoes a true foreground exit while an entries view is
      visible, the entries area is protected again when the app returns and the
      user must authenticate before seeing entries.
- [ ] A true foreground exit while the user is on the main screen does not
      cause an entries-authentication prompt before the main screen can be used.
- [ ] Cancelled, failed, unavailable, or unsupported authentication leaves the
      protected entries content unavailable and preserves the existing
      user-facing recovery behavior, including retry and any supported device
      security setup or bypass state.
- [ ] The protected state obscures and disables the underlying entries view; it
      does not expose entry text, audio details, identifiers, or raw failure
      diagnostics.
- [ ] Existing entry interactions, including saved entries, drafts, detail
      viewing, editing, deletion, search, import, and export, continue to work
      after the protected area has been unlocked.
- [ ] Existing operating-system screenshot, recording, and recent-app privacy
      behavior is not weakened by changing the authentication scope.
- [ ] No entry data, authentication secret, or authentication result is sent to
      the backend or written to diagnostic logs.

## API contract

This feature introduces no HTTP endpoints and does not change the backend
contract.

## Data model changes

No local entry fields, persisted entry values, authentication secrets, or
database schemas change. The feature does not add a persisted lock preference;
the protected-area behavior is part of the app's existing privacy policy.

## Dependencies

- [ ] Existing device-authentication flow and its supported recovery states.
- [ ] Existing entries list and individual entry views.
- [ ] Existing navigation and app lifecycle behavior.
- [ ] Existing Android and iOS operating-system capture privacy behavior.
- [ ] Automated and runtime validation on Android and iOS.

## UX / design references

No external design reference is required. The existing lock surface, wording,
accessibility semantics, and recovery actions should be reused for the
protected entries state.

## Non-functional requirements

- **Performance:** The main screen should remain usable at launch without
  waiting for authentication. Entering the protected area should show the
  existing authentication experience promptly.
- **Security:** No protected entry content or metadata may be readable or
  interactive before successful authentication. Sensitive content must not be
  included in logs or error messages.
- **Reliability:** Authentication must remain single-flight. Lifecycle changes
  must not create repeated prompts, leave a protected view interactive, or
  cause an authentication loop.
- **Scalability:** The scope distinction between the main screen and protected
  entries area should support future protected views without changing entry
  storage or backend contracts.
- **Observability:** Developer diagnostics may record sanitized state and
  failure categories only; they must not record entry content, secrets, or raw
  authentication diagnostics.

## Out of scope

- Changing the authentication mechanism or requiring biometric-only
  authentication instead of the existing device-authentication policy.
- Adding a user-facing settings toggle for selecting which views are locked.
- Requiring authentication on the main recording screen or other non-entry
  views.
- Changing Android or iOS screenshot, screen-recording, or recent-app privacy
  coverage.
- Adding per-entry passwords, independent locks for individual entries, or a
  new timeout policy beyond the protected-visit and foreground-exit behavior.
- Changing entry storage, import/export formats, backend APIs, or entry data
  retention.

## Open questions

None. The existing device-authentication policy remains unchanged, and leaving
the entries area ends the protected visit so authentication is required again
on re-entry.
