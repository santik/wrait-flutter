# Feature Specification: App Updates Preserve Local Data

> **Feature number:** 030
> **Status:** In Progress
> **Author:** Codex
> **Date:** 2026-06-19
> **Work item:** US-030

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-19 | Draft | Codex | Initial spec created from the request to preserve local database contents across app updates while removing the database on uninstall |
| 2026-06-19 | Draft | Codex | Clarify phase resolved uninstall/clear-data scope, update baseline, draft audio preservation, reinstall identity handling, failure UX, validation build scope, and uninstall file scope |
| 2026-06-19 | Approved | Codex | User approved the finalized spec for implementation planning |
| 2026-06-20 | Approved | Codex | User approved the implementation plan for task breakdown |
| 2026-06-20 | In Progress | Codex | User approved the analysis and implementation started |
| 2026-06-20 | In Progress | Codex | Implementation and validation completed; waiting for external review artifact |
| 2026-06-22 | In Progress | Codex | Applied the approved subset of review fixes; draft-audio path-layer findings deferred to US-032 by user direction |

---

## Overview

Users rely on Wrait as a private voice diary, so installing a newer version of
the app must not cause existing entries, drafts, preferences, or local identity
state to disappear. A normal app update should feel continuous: after the update
finishes, the user opens Wrait and sees the same locally stored diary state they
had before the update.

At the same time, uninstalling the app should remove the app's private local
database so that deleting the app also deletes the diary data stored by that
installation. If the user later installs Wrait again after a true uninstall,
the app should start as a fresh installation and must not show entries from the
previously uninstalled app.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a diary user, I want my entries to remain available after updating Wrait
  to a newer version so that I can install improvements without losing my
  journal.
- As a diary user, I want pending drafts and app preferences to remain available
  after an update so that interrupted work and personalization survive version
  changes.
- As a diary user, I want uninstalling Wrait to remove the local diary database
  so that deleting the app removes the private data stored by that installation.
- As a diary user, I want reinstalling Wrait after uninstall to start fresh so
  that old local entries are not unexpectedly restored.
- As a tester, I want update and uninstall behavior verified on Android and iOS
  so that platform-specific data lifecycle behavior does not regress.

## Acceptance criteria

- [ ] Updating Wrait from an older installed version to a newer installed
      version preserves all existing saved diary entries.
- [ ] Any same-identity installation over an existing app installation with
      local data is treated as an update path and preserves the local database.
- [ ] Updating Wrait preserves entry metadata needed by the current product,
      including creation time, language, draft state, word count, cleaned text,
      raw transcript, and any retained draft audio reference.
- [ ] Updating Wrait preserves app preferences that affect the current user
      experience, including selected language, privacy mode, and first-recording
      state.
- [ ] Updating Wrait preserves the locally stored anonymous device identity used
      by backend registration and quota tracking.
- [ ] Updating Wrait must not treat the existing installation as a new install
      when local app data is still present.
- [ ] Updating Wrait must not delete, overwrite, duplicate, or corrupt existing
      local diary data.
- [ ] If an update introduces required data shape changes, existing local data
      remains readable after the update and is migrated without user action.
- [ ] If an update cannot safely read or migrate existing local data, the app
      presents a simple understandable error state rather than silently
      replacing the user's diary with an empty database.
- [ ] Uninstalling Wrait removes the app's private local database for that
      installation.
- [ ] Clearing Wrait's app storage/data through platform settings also results
      in a fresh local database state.
- [ ] Reinstalling Wrait after a true uninstall starts with no saved diary
      entries, no pending drafts, and fresh local installation state unless the
      user explicitly restores data through a future approved restore feature.
- [ ] Reinstalling Wrait after a true uninstall is treated as a fresh install;
      reuse of a platform-retained anonymous device identity is allowed but not
      required, and must not restore old diary data.
- [ ] Uninstall behavior removes local draft audio files and other database-
      linked private local data owned by the app installation.
- [ ] App update behavior is verified on both Android and iOS using a same-
      identity update path that matches how users receive newer versions on
      each platform.
- [ ] App uninstall/reinstall behavior is verified on both Android and iOS using
      the platform's normal app removal flow.
- [ ] The feature does not require a cloud account, cloud backup, or server-side
      restore mechanism.
- [ ] The feature does not weaken the existing expectation that diary content is
      stored privately on-device.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

Functional expectations for existing backend-adjacent local state:

- The app keeps using a stable anonymous device identity across ordinary app
  updates when the local installation remains present.
- A reinstall after true uninstall is allowed to create fresh local installation
  state and must not require access to the previous installation's local diary
  database.
- No backend endpoint is responsible for restoring deleted local diary entries
  as part of this feature.

## Data model changes

This feature defines local data lifecycle requirements across app update,
uninstall, and reinstall. It does not require new user-visible diary fields in
the functional data model.

Existing local data that must preserve update continuity:

- diary entries
- pending drafts
- draft audio references and owned draft audio files
- selected language
- privacy mode
- first-recording state
- anonymous device identity
- any other app-owned local metadata required to keep current user-visible
  behavior consistent after an update

If implementation analysis finds that the current local data model cannot meet
these lifecycle requirements without a schema or storage-location change, that
change must be documented in `plan.md` with before/after data shape, migration
behavior, and validation evidence.

## Dependencies

- [ ] Existing encrypted local diary storage
- [ ] Existing app preferences and anonymous device identity storage
- [ ] Existing draft retry storage for entries and draft audio
- [ ] Android platform update and uninstall behavior for the app's installed
      identity
- [ ] iOS platform update and uninstall behavior for the app's installed
      identity
- [ ] Existing integration test and runtime validation infrastructure for
      Android and iOS

## UX / design references

No new product screens are expected for the successful update or uninstall
paths.

If local data cannot be opened or migrated after an update, the app must present
a simple understandable error state. More advanced recovery UX is out of scope
for this feature.

## Non-functional requirements

- **Performance:** Update-time data continuity must not add noticeable startup
  delay beyond work required to safely open or migrate existing local data.
- **Security:** Preserved local data must keep the same privacy and encryption
  expectations as before the update. Uninstall/reinstall must not expose old
  diary content through normal app use.
- **Reliability:** Update, uninstall, and reinstall behavior must be
  deterministic on both supported platforms. Data loss during a normal update
  is a critical failure.
- **Scalability:** The lifecycle rules should support future local data model
  migrations without requiring users to export or manually copy data before
  updating.
- **Observability:** Validation evidence must clearly show pre-update data,
  post-update data, post-uninstall state, and post-reinstall fresh state on
  Android and iOS.

## Out of scope

- Cloud backup, cloud sync, account-based restore, or cross-device transfer
- User-initiated export/import
- Restoring data after a true uninstall
- Preserving data when the user or operating system explicitly clears app data
  without uninstalling
- Supporting package identity or bundle identifier changes as an update path
- Migrating data from the older native Wrait Android app identity
- Changing entry list, entry detail, recording, transcription, cleanup, quota,
  or sharing behavior except where needed to keep existing local data readable
  after an update
- Release-store rollout mechanics, staged releases, signing policy, app review
  submission, or complex multi-build release validation beyond the simplest
  same-identity install path that proves update persistence
- Removing app-owned private files that are not part of the database or linked
  to database records

## Open questions

- [ ] None at this stage.
