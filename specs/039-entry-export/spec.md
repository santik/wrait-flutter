# Feature Specification: Entry Export

> **Feature number:** 039
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-29
> **Work item:** US-039

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-29 | Draft | Codex | Initial spec created from the request to export entries from the entries screen to a user-accessible local file |
| 2026-06-29 | Draft | Codex | Clarified export scope, file format, audio exclusion, and automatic destination behavior |
| 2026-06-29 | Approved | User | Finalized spec approved for implementation planning |
| 2026-06-29 | Approved | User | Implementation plan approved for task breakdown |
| 2026-06-29 | Approved | User | Task list approved for analysis |
| 2026-06-30 | In Progress | Codex | Implementation and validation completed; awaiting external review artifact |
| 2026-06-30 | In Progress | User/Codex | User confirmed there are no shipped iOS users, skipped review for this pass, and removed the legacy iOS database migration requirement |
| 2026-06-30 | In Progress | Codex | External review remediation applied for diagnostics, accessibility, and filename-collision hardening |
| 2026-06-30 | Complete | Codex | Long-lived documentation updated in AGENTS/application description/agent findings and feature workflow closed out |

---

## Overview

Users want an explicit safety mechanism before updating or otherwise changing
the app: a way to export their local Wrait entries into a user-accessible local
file. The export should be available from the entries screen, where users
already review their records, so the action is discoverable at the point where
the exported content is visible.

The exported file should let a user keep a readable CSV copy of their local
diary records outside the app's private storage. A successful export must not
alter, delete, duplicate, or otherwise mutate existing app data. The feature is
a manual local export path, not an automated backup, import, cloud sync, or app
update mechanism.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a diary user, I want to export my entries from the entries screen so that
  I can keep a local safety copy before updating the app.
- As a diary user, I want the exported file to be stored somewhere I can access
  outside the app, such as a downloads-style local location, so that I can
  inspect, move, or archive it myself.
- As a diary user, I want the app to choose the export destination
  automatically so that I do not have to configure a folder before making a
  safety copy.
- As a diary user, I want export success and failure to be clearly reported so
  that I know whether my records were actually copied.
- As a maintainer, I want the export behavior covered by focused validation so
  that future storage, privacy, or entry-list changes do not silently break the
  user's safety-copy flow.

## Acceptance criteria

- [ ] The entries screen provides a clear export action for exporting locally
      stored entries.
- [ ] Starting an export includes all entries that the entries screen is
      expected to represent, including saved entries and any locally stored
      draft entries.
- [ ] Each exported entry includes the user-visible record content and metadata
      needed to understand it outside the app, including creation time,
      language, draft state, word count, raw transcript, and cleaned text when
      present.
- [ ] Exporting entries creates a CSV file in an automatically selected
      user-accessible local destination outside the app's private database
      storage.
- [ ] The exported file has a name that makes it recognizable as a Wrait export
      and distinguishable from older exports.
- [ ] The export contains database entry content only and does not include
      retained draft audio files.
- [ ] After a successful export, the app clearly communicates that the export
      completed and provides enough location or destination information for the
      user to find the file.
- [ ] If export cannot complete, the app clearly communicates the failure and
      leaves existing entries unchanged.
- [ ] Exporting with no entries does not crash and gives the user an
      understandable result.
- [ ] Exporting entries must not delete, modify, reorder, duplicate, finalize,
      retry, upload, or otherwise mutate existing entries or drafts.
- [ ] Exporting entries must not expose encryption keys, backend secrets, local
      implementation diagnostics, stack traces, or unrelated app-private files.
- [ ] Exporting entries must remain compatible with the current app-lock and
      capture-privacy expectations.
- [ ] The feature does not weaken the existing encrypted local database
      storage; the export is an explicit user-initiated readable copy.
- [ ] Validation evidence includes automated coverage for successful export,
      export failure handling, and empty-entry export behavior plus runtime
      checks on both Android emulator and iOS simulator unless a planning-time
      validation exception is explicitly approved.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

## Data model changes

This feature does not require new user-visible diary fields or changes to the
persisted entry data model.

The export must represent existing entry data in CSV form. If planning
identifies that the current entry data shape cannot satisfy the accepted export
requirements, the plan must document the gap before any code changes are made.

## Dependencies

- [ ] Existing entries screen and entry-list behavior
- [ ] Existing locally stored entry and draft data
- [ ] Existing entry metadata: creation time, language, draft state, word count,
      raw transcript, cleaned text, and retained draft audio reference where
      applicable
- [ ] Platform support for creating or handing off a user-accessible local file
      in an automatically selected destination
- [ ] Existing app-lock and capture-privacy behavior
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design reference is currently provided.

The export action should fit the existing entries screen style and should avoid
turning the entries screen into a backup-management surface. Success and
failure feedback should be short, clear, and consistent with existing Wrait
messaging.

## Non-functional requirements

- **Performance:** Export should complete without noticeable UI jank for normal
  entry counts. Large exports should avoid blocking entry browsing longer than
  necessary.
- **Security:** Export must be explicitly user-initiated and must include only
  the intended entry content and metadata. It must not include encryption keys,
  proxy secrets, backend configuration, local file paths unless explicitly
  required by the accepted spec, draft audio files, or diagnostic internals.
- **Reliability:** Export must be all-or-clear-failure from the user's
  perspective: a successful message should only be shown after the file is
  created, and a failed export must leave app data unchanged.
- **Scalability:** The export format and flow should support growth from a few
  entries to a large local diary without requiring a future redesign for normal
  personal-use volumes.
- **Observability:** Validation evidence must include automated test output and
  runtime observations showing where export is started, how success or failure
  is surfaced, and that exported content matches the stored entries.

## Out of scope

- Importing, restoring, or merging exported entries back into Wrait
- Cloud backup, cloud sync, account-based restore, or cross-device transfer
- Automatic export as part of `deploy_release.sh`
- Replacing the existing same-identity app update data-preservation behavior
- Copying or exposing the raw encrypted database as the primary user export
- Exporting retained draft audio files
- Letting the user choose or configure a custom export directory
- Exporting backend registration state, device identity, preferences, app-lock
  settings, quota state, or secrets
- Redesigning the entries screen beyond the export action and required export
  feedback
- Changing recording, transcription, cleanup, retry, sharing, deletion, app
  lock, or capture-privacy behavior except where needed to keep the export flow
  correct and private
- Long-term backup scheduling, background automation, or reminder behavior
- Updating long-lived documentation before the final SDD knowledge-capture gate

## Open questions

No open questions remain in the spec. Clarification answers recorded:

- Export should include all database entries.
- Export should not include retained draft audio files.
- Export format should be CSV.
- The app should select the export destination automatically.
