# Feature Specification: iOS Draft Audio Update Path Stability

> **Feature number:** 032
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-22
> **Work item:** US-032

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-22 | Draft | Codex | Initial spec created from the request to isolate the draft-audio update-path problem as an iOS-focused story |
| 2026-06-22 | Draft | Codex | Captured user preference to minimize platform differences while preserving existing correct behavior |
| 2026-06-22 | Draft | Codex | Clarify phase resolved platform-divergence and backward-compatibility expectations |
| 2026-06-22 | Draft | Codex | Removed migration requirement because no draft rows exist yet and clarified shared stored-reference behavior |
| 2026-06-22 | Draft | Codex | Clarified that the solution should reduce retained-audio reference complexity rather than broaden portability behavior |
| 2026-06-22 | Approved | Codex | User approved the finalized spec for implementation planning |
| 2026-06-22 | Complete | Codex | Implementation, review remediation, validation, and knowledge-capture follow-up completed; `docs/agent-findings.md` updated and no durable `AGENTS.md` or `docs/application-description.md` changes were needed |

---

## Overview

Wrait preserves pending audio drafts across ordinary app updates so that users
do not lose interrupted journal work. During update validation, the current
failure mode for linked draft audio was observed on iOS-style reinstall/update
paths where the app's private container location changed even though the app's
logical data should have remained continuous.

This story narrows that problem into an explicit platform-focused requirement:
pending audio drafts must remain usable after same-bundle iOS updates, while
Android behavior that already works must not regress. The intended product
behavior is shared across both supported platforms: users should experience
stable draft continuity after ordinary updates, fresh local state after true
uninstall/reinstall, and no visible platform-specific difference unless the
underlying platform lifecycle makes one unavoidable.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As an iPhone user, I want a pending audio draft to remain retryable after I
  install an updated version of Wrait so that I do not lose unfinished journal
  work.
- As a user with saved entries and drafts on Android, I want update behavior to
  remain unchanged so that fixing iOS draft continuity does not destabilize the
  platform that already preserves my local data correctly.
- As a maintainer, I want the project to address the real platform-specific
  draft continuity risk without introducing broader persistence complexity than
  the validated problem requires.
- As a maintainer, I want iOS and Android draft-continuity behavior to remain as
  consistent as practical so that future maintenance does not depend on
  unnecessary platform-specific rules.
- As a maintainer, I want retained draft-audio references to be saved using the
  same functional rules on iOS and Android so that platform differences are
  limited to runtime lifecycle behavior, not stored data shape.
- As a maintainer, I want the retained-audio reference behavior to stay simple
  and narrowly scoped so that preserving draft audio after updates does not add
  unnecessary portability, migration, or fallback complexity.

## Acceptance criteria

- [ ] On iOS, a same-bundle app update preserves pending draft rows that depend
      on retained local audio files.
- [ ] On iOS, after the update, a preserved pending audio draft still points to
      usable retained audio rather than a broken or stale file reference.
- [ ] On iOS, preserved audio drafts remain retryable through the existing
      launch retry and cleanup flow after the update.
- [ ] Newly saved retained draft-audio references use the same functional
      stored-reference behavior on iOS and Android.
- [ ] Because there are no existing draft rows to preserve before this story,
      no draft-audio reference migration or legacy draft-reference recovery is
      required.
- [ ] If a future unresolved draft audio reference cannot be resolved safely,
      the app must not attach the draft to a different retained audio file based
      only on an ambiguous match such as a reused file name.
- [ ] On iOS, uninstall/reinstall still returns the app to a fresh local state
      and does not restore old draft audio from a removed installation.
- [ ] On Android, update behavior for pending audio drafts remains correct and
      is not regressed by this story.
- [ ] The feature does not require broader cross-platform draft-file migration
      behavior beyond what is needed to satisfy the observed iOS continuity
      problem.
- [ ] The stored draft-audio reference behavior is the same across iOS and
      Android; platform-specific behavior is limited to runtime lifecycle
      differences needed to preserve that shared behavior.
- [ ] Retained-audio reference handling is simplified compared with the current
      draft-audio portability behavior and does not include unnecessary
      fallback or migration paths.
- [ ] Validation evidence clearly distinguishes iOS update continuity from
      uninstall/reinstall fresh-state behavior.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

## Data model changes

This feature may change how the app functionally refers to retained local draft
audio so that the reference remains valid after an iOS update. Because there
are no existing draft rows in the database before this story, no draft-audio
reference migration or legacy draft-reference compatibility is required.

If the stored-reference shape changes, planning must document the before/after
data shape. The new stored-reference behavior must be shared by iOS and Android.

## Dependencies

- [ ] Existing pending audio draft storage and retry behavior
- [ ] Existing local-data update/uninstall lifecycle behavior from US-030
- [ ] Deferred US-030 review findings about draft audio reference safety
- [ ] Existing iOS simulator or device validation path for same-bundle updates
- [ ] Existing Android update validation path to confirm no regression

## UX / design references

No new product screens are expected. The successful path should remain silent:
users simply keep their pending drafts after update.

## Non-functional requirements

- **Performance:** Draft continuity handling must not add noticeable launch
  delay beyond what is required to safely resolve preserved local audio.
- **Security:** Retained audio must remain private to the app installation and
  must not weaken the current on-device privacy expectations.
- **Reliability:** Same-bundle iOS updates must keep pending audio drafts usable
  in a deterministic way, and unsafe or ambiguous retained-audio references
  must never be treated as valid.
- **Scalability:** The chosen behavior should support future local draft
  continuity without requiring repeated ad hoc platform-specific exceptions for
  the same problem class.
- **Maintainability:** iOS and Android must use the same stored-reference rules
  for retained draft audio. Platform-specific logic is acceptable only where it
  handles platform lifecycle differences while preserving the shared user-facing
  behavior. The retained-audio reference behavior should be simpler than the
  current portability layer and avoid speculative fallback or migration logic.
- **Observability:** Validation evidence must show pre-update draft state,
  post-update draft usability, and post-uninstall fresh state on iOS, plus
  Android non-regression evidence.

## Out of scope

- Reworking the entire local-entry storage model
- Broad cross-platform file portability changes not justified by the observed
  iOS issue
- Migrating legacy draft-audio references or preserving pre-existing draft rows
- Cloud backup, export/import, or cross-device draft restoration
- Changing saved-entry behavior beyond what is needed to keep draft audio
  continuity correct
- Recovering missing draft audio through ambiguous file-name-only matching
- Adding broad retained-audio portability behavior for scenarios not required
  by this story
- Release deployment/signing changes covered by other stories

## Open questions

- [ ] None at this stage.
