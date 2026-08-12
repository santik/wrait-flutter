# Feature Specification: User Feedback First Version

> **Feature number:** 042
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-07-13
> **Work item:** US-042

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-07-13 | Draft | Codex | Initial spec created from the request for the simplest first user-feedback version |
| 2026-08-11 | Approved | Codex | Finalized functional requirements approved for planning |
| 2026-08-12 | Complete | Codex | Implementation, review remediation, second-pass review, validation, and durable documentation finalized |

---

## Overview

Wrait should provide a simple way for users to send feedback from inside the
app. The first version should make feedback easy to submit while preserving the
app's privacy posture: users can describe a problem, idea, confusing moment, or
positive experience without being asked to leave the app or expose private
journal content.

This story focuses on the smallest useful feedback flow: a single button on the
main screen, a short feedback form, optional reply contact, privacy-conscious
context collection, submission feedback, and graceful failure handling.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want to send feedback from inside Wrait so that I can report
  problems or share ideas without searching for a separate contact channel.
- As a user, I want to understand what information is included with my feedback
  so that I can avoid sharing private journal content unintentionally.
- As a user who wants a response, I want to optionally provide contact
  information so that the Wrait team can follow up.
- As a maintainer, I want submitted feedback to include safe app context so
  that reports are easier to triage without collecting sensitive entry content.

## Acceptance criteria

- [ ] The main screen includes one discoverable feedback button.
- [ ] The first version does not require a settings area or a second feedback
      entry point.
- [ ] Opening the feedback entry point presents a form that lets the user enter
      a free-text feedback message.
- [ ] The feedback form lets the user classify the feedback using a small
      category set containing `Bug`, `Idea`, `Confusing`, and `Praise`.
- [ ] The user can optionally provide reply contact information as plain text.
- [ ] The reply contact field has no format validation and the user can submit
      feedback with the field blank or with any text they choose.
- [ ] The feedback experience includes concise privacy copy explaining that the
      user should not include private entry content unless they choose to type
      it into the message.
- [ ] The preparation form remains top-anchored when the keyboard appears; its
      content can scroll without automatically moving the form.
- [ ] Submitted feedback collects available automatic context only when it is
      privacy-safe and useful for triage, such as app version, platform, broad
      app area, locale, and timestamp.
- [ ] The feedback flow does not collect or transmit available information when
      doing so could reveal private journal content, recordings, or other
      sensitive user data.
- [ ] Submitted feedback does not automatically include transcripts, cleaned
      entry text, audio recordings, audio paths, entry identifiers, export file
      names, screenshots, or raw diagnostic logs.
- [ ] If submission succeeds, the user sees clear confirmation and returns to a
      normal app state.
- [ ] If submission fails, the user sees a sanitized failure message and can
      retry or dismiss without losing typed feedback while the feedback form
      remains open.
- [ ] The user can cancel the feedback flow without submitting anything.
- [ ] Adding the feedback flow does not change recording, transcription, entry
      list, entry detail, import, export, app lock, or capture privacy behavior.
- [ ] Validation evidence includes automated coverage for the main-screen-to-
      feedback user flow plus runtime checks on both Android emulator and iOS
      simulator unless a planning-time validation exception is explicitly
      approved.

## API contract

This feature does not require a Wrait backend HTTP endpoint in the functional
spec. The destination and transport for feedback submission will be selected in
the implementation plan.

## Data model changes

This feature does not require local Wrait data model changes.

## Dependencies

- [ ] Existing main-screen surface where the single feedback button can live
- [ ] Existing app version/build, platform, locale, and broad navigation context
      signals
- [ ] A feedback destination capable of receiving user message, category,
      optional plain-text reply contact, and safe app context
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design reference is currently provided. The first version should
match Wrait's existing minimal, privacy-forward app experience and should avoid
interrupting core recording or entry-review workflows.

## Non-functional requirements

- **Performance:** The feedback button and form must not add noticeable delay to
  app startup or core recording flows.
- **Security:** Feedback submission must not expose secrets, raw diagnostics,
  recordings, transcripts, cleaned entry text, entry identifiers, or file paths
  automatically. User-facing errors must be sanitized.
- **Reliability:** Failed submissions must preserve the user's typed message
      while the form remains open and must not block normal app use after dismissal.
- **Keyboard behavior:** Focusing the optional contact field must not move the
  top-anchored preparation form; lower actions may remain manually scrollable
  above the keyboard.
- **Scalability:** The first version should support future feedback triage
  categories or contextual launch points without requiring changes to existing
  journal data.
- **Observability:** Implementation evidence must show what safe context is
  collected and verify that sensitive Wrait entry or audio content is excluded
  by default.

## Out of scope

- Contextual feedback prompts after recording, transcription, import, export,
  or other feature-specific events
- Product analytics, usage tracking, event funnels, or user behavior analysis
- Screenshot annotation or automatic screenshot attachment
- Automatic diagnostic log, network log, transcript, entry, export, or audio
  attachment
- In-app support chat, two-way messaging, public roadmap voting, or changelog
  delivery
- Backend admin UI, moderation tooling, or automated conversion of feedback
  into issues
- Changes to recording, transcription, entry storage, import/export, app lock,
  capture privacy, or local database behavior
