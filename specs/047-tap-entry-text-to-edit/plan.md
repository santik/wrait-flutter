# Implementation Plan: Tap Entry Text To Edit

> **Feature number:** 047
> **Spec:** [spec.md](spec.md)
> **Status:** Approved — 2026-09-23
> **Author:** Codex
> **Date:** 2026-09-23

## Approach summary

Add a tap action to the existing read-mode entry body that invokes the same
edit transition as the header Edit button. Keep the existing read/editor
switch, text synchronization, focus request, and Edit/Done controls. The change
belongs entirely in the entry-detail presentation layer.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Tap handling | Use the existing SelectableText.onTap callback. | Reuses its gesture recognition and preserves reading gestures without an outer competing gesture detector. |
| Edit transition | Invoke the existing _handleEditToggle path used by Edit. | Shares the existing content and focus behavior without duplicating editor initialization. |
| Repeated activation | Guard body activation using the current controller edit state; ignore it when editing is already active. | A repeated or delayed read-body callback must not accidentally invoke Done. |
| Accessibility | Add an edit hint and semantic tap action sharing the guarded callback, retaining readable text and the header action. | Makes the additional action discoverable; inspect the semantics tree to prevent duplicate activation. |
| Cursor and keyboard | Reuse current text synchronization and post-frame focus request. | Matches the Edit button without introducing tap-coordinate mapping. |
| Persistence | Keep the existing controller and repository untouched. | This feature changes only the trigger for an existing operation. |
| Validation | Extend existing entry-detail harnesses using synthetic data and their app-lock overrides. | Exercises the actual screen and persistence boundary without new test infrastructure. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| lib/presentation/entries/entry_detail_screen.dart | Modify | Add guarded read-body tap and accessible edit action. |
| test/presentation/entries/entry_detail_screen_test.dart | Modify | Verify tap/button parity, content, focus, semantics, scrolling, metadata taps, and repeated activation. |
| integration_test/entry_detail_flow_test.dart | Modify | Extend flows for cleaned/fallback body taps, Done/re-entry, scrolling, sharing, and system-back persistence. |
| integration_test/entry_detail_device_smoke_test.dart | Modify | Exercise body tap, keyboard/focus, in-app back, and persisted content after reopening. |
| specs/047-tap-entry-text-to-edit/spec.md | Update | Track approval and acceptance status at the appropriate gates. |
| specs/047-tap-entry-text-to-edit/plan.md | Update | Track approval and approved deviations. |
| specs/047-tap-entry-text-to-edit/tasks.md | Fill after plan approval | Derive the implementation checklist. |
| specs/047-tap-entry-text-to-edit/implementation.md | Create during implementation | Record changes and validation evidence. |

## API contract details

No backend API changes. The read-body action exists only for readable entries
outside edit mode. It uses the same displayed text and transition as Edit;
the editor then owns text interaction. Dragging to scroll and tapping metadata
do not enter editing. Preserve the read-body, editor, Edit, and Done test keys.

Both cleaned text and raw-transcript fallback continue to use the existing
display-text selection. Save errors, sharing, deletion, and navigation retain
their current contracts.

## Data model changes

None. Before and after the change, edits use the existing cleaned-text and
word-count persistence path and preserve the raw transcript. No migration,
new storage, or network request is required.

## Test strategy

### Automated tests

Extend tests for the new interaction and affected boundaries; reuse existing
regression coverage for unchanged behavior.

| Scenario | Coverage |
| --- | --- |
| Tap cleaned text or raw fallback; complete content, focus, and Done match Edit-button entry. | Widget tests and entry_detail_flow_test.dart. |
| Tap a very long entry and preserve its complete editor content, including after read-mode scrolling. | A 400-line widget variant and expanded 400-line integration fixture, each over 10,000 characters. |
| Edit remains available; Done returns to reading; another tap resumes editing with current content. | Widget tests and entry_detail_flow_test.dart. |
| Scroll long text and tap metadata without entering editing. | Widget tests and entry_detail_flow_test.dart. |
| Repeated body activation does not finish editing or reset content. | Widget tests and runtime verification. |
| Accessible body retains readable content and exposes a working edit action without duplicate activation. | Widget semantics tests and runtime accessibility inspection. |
| Tap-to-edit, modify, finish with Done or system back, preserve raw transcript, update word count, and share through the existing path. | entry_detail_flow_test.dart. |
| Tap-to-edit, modify, leave through in-app back, and reopen persisted text. | entry_detail_device_smoke_test.dart. |
| Loading exposes no body action; failed saving after body-triggered editing keeps the existing generic error and edit state on failed Done/back. Missing/unreadable entries, sharing, and deletion retain behavior. | Add the two explicit screen checks; reuse existing controller failure and widget/integration regression coverage. |

Run flutter analyze and the entry-detail screen/controller test files.
Run both modified integration files on each target below with discovered
device IDs. Their successful builds provide Android and iOS compilation
evidence. Record exact commands, device versions, and results.

### Android emulator verification

1. Run both integration files on an available Android emulator using synthetic
   entries and the existing app-lock override.
2. Confirm tapping read text focuses the editor and opens the software keyboard
   before injecting test text, so a test helper cannot mask a missing focus step.
3. Verify Done/re-entry, normal editor cursor placement and selection, scrolling
   without editing, metadata taps, and both back-navigation persistence paths.
4. Inspect the accessible body action. Record runtime observations and test
   assertions; retain capture protection and document any black screenshots
   caused by FLAG_SECURE rather than weakening privacy for evidence.

### iOS simulator verification

1. Run the same two integration files on an available iOS simulator.
2. Enable the simulator software keyboard if needed and verify it appears after
   the body tap, before test text injection.
3. Verify Done/re-entry, normal editor selection, reading scroll, metadata taps,
   in-app back, and reopened persisted content. The harness's system-back test
   is not evidence for an iOS edge-swipe navigation gesture.
4. Inspect accessibility and record runtime observations and test outcomes.
   Use the synthetic-data harness to avoid unrelated secure-startup prompts.

### Software-keyboard test mode

Keyboard-test configuration: the bounded software-keyboard wait is extracted
into _expectSoftwareKeyboardVisible with explicit timeout/pollInterval parameters
(defaults: three seconds / 100 milliseconds). General smoke runs always assert editor focus
before text injection. Controlled software-keyboard verification additionally
uses --dart-define=VERIFY_ENTRY_SOFTWARE_KEYBOARD=true to require nonzero native
IME insets. This avoids treating hardware-keyboard or lockscreen suppression as
an app focus failure in deploy suites; visible keyboard verification remains
required for this feature's controlled platform runs.

### Validation exception request

None. Both platforms are required. If validation is blocked, document the exact
limitation and request an explicit decision before claiming completion.

## Review and finalization

Create implementation.md after implementation and validation, then stop for
externally authored review.md unless the user explicitly skips review. After
reading review.md, present a remediation plan and wait for approval before
editing files. Do not create or prefill review.md.

At finalization, propose updating docs/application-description.md to describe
both ways to enter editing. Propose AGENTS.md or docs/agent-findings.md changes
only if implementation reveals durable guidance. Obtain approval before editing
those long-lived documents.

## Integration notes

Reuse the existing detail route and root privacy gate. No startup, plugin,
dependency, analytics, logging, or backend changes are needed. Preserve unrelated
workspace changes, including spec 048 and template.html.

## Rollout & migration

Ship as an ordinary app update with no feature flag or migration. At
implementation time create codex/feat/tap-entry-text-to-edit while preserving
existing workspace changes. Reverting the presentation change would not alter
stored data.

## Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| Tap handling interferes with reading gestures. | Use the text widget callback and verify scrolling and existing read-mode selection. |
| Rapid activation toggles into Done. | Guard against current edit state and exercise repeated interaction. |
| Semantics hide content or expose duplicate activation. | Inspect and invoke the semantic action in widget tests and inspect runtime accessibility. |
| Test text injection hides a focus defect. | Assert focus and check the keyboard before injecting text. |
| Native screenshots are blocked by privacy protections. | Keep privacy enabled and use assertions/runtime observations as evidence. |

## Open items from spec

None. The user discarded proposal 043 and approved the finalized 047 spec.
The user approved this plan and its task breakdown on 2026-09-23. Analysis
clarified two validation checks within the existing screen test file; its
report is recorded in tasks.md and awaits approval before implementation.
