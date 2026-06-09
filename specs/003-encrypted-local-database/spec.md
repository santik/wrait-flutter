# Feature Specification: Encrypted Local Entry Store

> **Feature number:** 003
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-08
> **Work item:** US-003

## Status history

| Date       | Status | Author | Notes |
| ---------- | ------ | ------ | ----- |
| 2026-06-08 | Draft | Codex | Initial spec created from `plan/us_003.md`, the existing Flutter foundation, and the Android data-layer reference behavior |
| 2026-06-08 | Draft | Codex | Clarifications incorporated: stale draft cleanup also removes referenced audio files, language values use supported BCP-47 codes, and single-entry access must support both reactive and one-time reads |
| 2026-06-08 | Approved | Codex | Finalized spec approved for planning |
| 2026-06-08 | Complete | Codex | Implemented Drift-based encrypted local entry store, startup cleanup, automated coverage, and Android/iOS launch verification |

---

## Overview

The Flutter app currently has no persistent entry storage, which means future
recording, transcription, and entry-browsing stories would have nowhere to save
or recover journal content. For a voice-first diary product, that gap is
especially important because journal entries and unfinished drafts contain
sensitive personal data that should not be left in plain readable storage.

This feature introduces protected on-device persistence for diary entries and
drafts. It must let the app save, read, update, and remove entry records,
support unfinished draft flows that can later be finalized into completed
entries, and ensure stored journal content remains protected at rest. The
result should give later stories a stable local source of truth for entry data
without yet introducing entry-list UI, cloud sync, or transcription logic.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a mobile user, I want my diary entries stored privately on my device so
  that someone who accesses the raw app storage cannot read my journal content.
- As a mobile user, I want saved entries and drafts to still be available after
  I close and reopen the app so that I do not lose work in progress.
- As a mobile user, I want unfinished drafts to be recoverable and finalizable
  so that interrupted recording or transcription flows can continue later.
- As a developer, I want a clear local entry-storage contract so that future
  entry list, detail, recording, and cleanup flows can rely on one source of
  truth.
- As a developer, I want entry-list consumers to receive change notifications
  automatically so that future UI surfaces stay in sync without manual refresh.

## Acceptance criteria

- [x] The app can persist diary entry records and draft records locally on the
      device and load them again across app restarts.
- [x] Stored journal content is protected at rest so that the backing database
      files are not readable as plain text without the app's retained secret
      material.
- [x] The app can create, read, update, and delete completed entries.
- [x] The app can save in-progress drafts, update a draft's transcript text,
      finalize a draft into a completed entry, and update an entry's language.
- [x] The persisted entry model includes a unique identifier, raw transcript,
      optional cleaned text, draft/completed state, language, created timestamp,
      word count, and optional audio-file reference for audio-backed drafts.
- [x] Entry-list consumers can observe a reactive collection of entries ordered
      from newest to oldest and receive updates when entries are inserted,
      updated, finalized, or deleted.
- [x] The app can fetch pending drafts for resume flows and can fetch an
      individual entry by identifier for detail or workflow continuation using
      both reactive and one-time read patterns.
- [x] Draft records older than 7 days are removed automatically during app
      startup before the app relies on pending-draft results, and any audio
      files referenced only by those stale drafts are removed as part of the
      cleanup.
- [x] If the protected secret material is lost or reset, previously stored
      entries are treated as unrecoverable by design rather than exposed
      partially or incorrectly.

## API contract

No HTTP endpoints are introduced or modified by this feature.

This story defines only local on-device persistence behavior and the
application-facing contract for working with saved entries and drafts.

## Data model changes

This feature introduces a persistent local entry record for the Flutter app.

Required fields:

- `id`: unique entry identifier
- `rawTranscript`: stored transcript text captured from the user's recording or
  draft flow
- `cleanedText`: optional finalized or cleaned-up text
- `isDraft`: whether the record is still an in-progress draft
- `language`: stored supported BCP-47 language code associated with the entry
- `createdAt`: creation timestamp
- `wordCount`: stored word count for the current transcript/cleaned text state
- `audioPath`: optional reference to an on-device audio file associated with a
  draft awaiting later processing

No migration is required for existing Flutter user data because this is the
first entry-storage story for the Flutter client.

## Dependencies

- [ ] Existing app foundation from `specs/us_001-flutter-project-foundation/`
- [ ] Existing shell and route placeholders from `specs/us_002-theme-design-tokens-core-ui-shell/`
- [ ] Story requirements in `plan/us_003.md`
- [ ] Supported platform capability to retain app-local protected secret
      material across normal app restarts

## UX / design references

No dedicated design artifact was provided for this data-layer story.

This feature is expected to operate behind future recording, entry-list, and
entry-detail interfaces rather than introduce new user-facing design on its own.

## Non-functional requirements

- **Performance:** Local save, read, update, and delete operations for
  individual entries should be fast enough to support future journaling flows
  without noticeable lag.
- **Security:** Journal content must be protected at rest, the secret material
  used to unlock the store must not be exposed in logs or source-controlled
  configuration, and loss of that secret may make stored data unrecoverable by
  design.
- **Reliability:** Draft-to-final-entry transitions must keep record state
  consistent, and startup cleanup of stale drafts must not leave the store in a
  partially updated state.
- **Scalability:** The local store should support the expected personal-diary
  entry volume for a single user without requiring a redesign of the record
  shape or access contract in upcoming stories.
- **Observability:** Validation evidence must show protected-store creation,
  CRUD behavior, reactive updates, and stale-draft cleanup behavior.
- **Maintainability:** The storage contract should remain narrow and reusable so
  later stories can build entry features without duplicating persistence logic.

## Out of scope

- Cloud backup, sync, export, or cross-device recovery
- Recording, transcription, cleanup, or entry-browsing UI behavior beyond the
  storage contract those stories will use
- Biometric unlock, app passcode, or other user-facing privacy gates
- Search, filtering, tagging, or sorting beyond the required newest-first entry
  ordering
- Non-entry persistence such as user preferences or backend caches

## Open questions

None at this stage.
