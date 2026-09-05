# Feature Specification: Single-step Feedback Submission Form

> **Feature number:** 045
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-09-04
> **Work item:** Not assigned

## Status history

| Date       | Status      | Author | Notes                    |
| ---------- | ----------- | ------ | ------------------------ |
| 2026-09-04 | Draft       | Codex  | Initial spec created from the requested feedback-form layout change |
| 2026-09-04 | Approved    | Codex  | Draft approved; clarification completed with direct one-step submission confirmed |
| 2026-09-05 | Complete    | Codex  | Approved review remediation, validation, and durable documentation updates completed |

---

## Overview

The feedback experience currently separates preparation from message entry: a
user selects a feedback category and optional reply contact, presses
`Continue`, and then enters the feedback message in a second screen. This adds
an unnecessary step to a short feedback task.

The preparation form should become the complete feedback form. It should place
the feedback message field directly below the reply contact field and provide a
`Submit` action alongside `Cancel`, so users can review and send their
category, optional contact, and message from one form.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a Wrait user, I want to enter my feedback in the same form where I choose
  its category so that I can submit it without moving through a second step.
- As a Wrait user who wants a response, I want to optionally provide reply
  contact information without being forced to use a particular format.
- As a privacy-conscious Wrait user, I want the existing privacy guidance to
  remain visible while I write feedback so that I can decide what to include.

## Acceptance criteria

- [x] The existing single feedback entry point remains the only feedback entry
      point.
- [x] Opening feedback presents the four existing category choices:
      `Bug`, `Idea`, `Confusing`, and `Praise`.
- [x] The user must choose one category before the feedback can be submitted.
- [x] The form keeps the optional reply contact field, accepts any plain text,
      and permits it to remain blank.
- [x] A multiline free-text feedback field appears directly below the reply
      contact field in the initial form.
- [x] The feedback message must contain non-whitespace text before submission
      is allowed.
- [x] The form action row contains `Cancel` and `Submit`; the `Continue`
      action is no longer shown.
- [x] Pressing `Submit` submits the category, reply contact, and feedback
      message from the current form without opening another message-entry step.
- [x] Pressing `Cancel` closes the form without submitting feedback.
- [x] If submission fails or feedback is unavailable, the user receives the
      existing sanitized failure/unavailable feedback and all entered category,
      contact, and message values remain available for retry.
- [x] If submission succeeds, the form closes and the existing success
      confirmation is shown.
- [x] Existing privacy guidance remains visible and continues to tell users not
      to include private journal content unless they intentionally type it into
      the message.
- [x] The form remains top-anchored when the keyboard appears, and its content
      can scroll so the message field and actions remain reachable on smaller
      screens.
- [x] The change does not alter recording, transcription, entry, navigation,
      app-lock, capture-privacy, or the existing feedback privacy boundary.
- [x] Automated coverage includes the complete main-screen-to-submit flow,
      cancellation, validation, and retry preservation, plus runtime checks on
      an Android emulator and an iOS simulator unless an explicit planning-time
      exception is approved.

## API contract

This feature does not introduce or modify a Wrait backend HTTP endpoint. The
existing feedback destination must receive the message entered in this form,
along with the selected category, optional reply contact, and existing
privacy-safe context.

## Data model changes

No persisted Wrait data or database migration is required. The in-memory
feedback draft used while the form is open now includes the current feedback
message in addition to its category and optional reply contact. This draft is
not journal data.

## Dependencies

- [x] Existing feedback entry point and submission destination.
- [x] Existing feedback success, cancellation, unavailable, failure, and retry
      behavior.
- [x] Existing top-anchored form and keyboard-safe layout behavior.
- [x] Existing widget and integration validation paths for Android and iOS.

## UX / design references

No external design reference is provided. The required form order is:

1. Feedback category choices: `Bug`, `Idea`, `Confusing`, `Praise`.
2. Optional reply contact field.
3. Multiline feedback message field.
4. Existing privacy guidance.
5. `Cancel` and `Submit` actions.

The existing Wrait visual style, spacing, top anchoring, and keyboard behavior
remain the source of truth.

## Non-functional requirements

- **Performance:** Adding the message field must not add startup work or a
      noticeable delay to opening the feedback form.
- **Security:** The message is user-entered content and must follow the
      existing feedback privacy boundary. No journal content, recordings,
      identifiers, paths, secrets, screenshots, or raw diagnostics may be
      attached automatically.
- **Reliability:** Failed or unavailable submission must keep all entered form
      values available for retry and must retain sanitized user-facing errors.
- **Accessibility:** Category choices, both text fields, and both actions must
      remain discoverable and have meaningful labels for assistive technology.
- **Keyboard behavior:** Focusing either text field must preserve the
      top-anchored form while allowing the lower content and actions to be
      reached by scrolling.
- **Scalability:** The in-memory draft must leave room for future feedback
      fields without changing journal storage.
- **Observability:** Existing developer-only feedback diagnostics may remain,
      but entered message text must not be added to logs.

## Out of scope

- Adding new categories or changing the existing feedback category set.
- Adding another feedback entry point or a settings-based feedback entry.
- Persisting feedback drafts in the Wrait journal database.
- Changing the feedback destination's privacy-safe metadata policy.
- Adding attachments, screenshots, analytics, automatic diagnostics, or
      journal/audio context.
- Redesigning unrelated recording, entry, navigation, lock, or capture-privacy
      behavior.

## Test strategy

- Widget tests will verify the form order, four category choices, required
      category/message validation, arbitrary optional contact input, `Cancel`,
      `Submit`, and keyboard-safe top anchoring.
- Service tests will verify that the submitted draft contains the message,
      success/unavailable/failure outcomes remain sanitized, and retry keeps
      category, contact, and message values.
- The main feedback integration flow will cover opening from the main screen,
      selecting a category, entering contact and message text, submitting once
      from the initial form, cancellation without submission, and retry after
      failure.
- Android emulator and iOS simulator runs will verify the real form layout,
      keyboard behavior, direct submit flow, and unchanged main-screen behavior.

## Open questions

- [x] None. `Submit` directly sends the message entered in the initial form;
      no second message-entry screen is part of this feature.
