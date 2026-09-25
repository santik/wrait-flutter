# Tasks: Tap Entry Text To Edit

> **Feature number:** 047
> **Plan:** [plan.md](plan.md)
> **Status:** Review remediation complete — awaiting finalization approval
> **Author:** Codex
> **Date:** 2026-09-23

## Workflow gates

The finalized spec, implementation plan, and task checklist are approved.
Cross-artifact analysis below was approved on 2026-09-23. Implementation and
validation are complete on codex/feat/tap-entry-text-to-edit. External review
and approved remediation are handled; the final documentation gate remains.

## Group 1: Foundation

- [x] T01: Analyze spec, plan, and tasks for acceptance coverage, scope, dependencies, and both-platform validation. User approved the analysis on 2026-09-23.
- [x] T02: Inspect workspace and branch state, preserve unrelated changes, and create codex/feat/tap-entry-text-to-edit. Mark the spec In Progress.

## Group 2: Entry-body action

Depends on Group 1.

- [x] T03: In lib/presentation/entries/entry_detail_screen.dart, connect read-mode SelectableText.onTap to the existing edit transition. Read current controller state and ignore body activation if editing is already active. Reuse current displayed content, text synchronization, and focus handling.
- [x] T04: Expose a meaningful edit hint and semantic tap action sharing that guarded callback, preserving readable text and avoiding duplicate activation.
- [x] T05: Preserve read-body/editor/Edit/Done keys, the Edit button, normal editor interaction, and existing reading gestures. Keep metadata outside the tap action and keep loading/missing/unreadable states unchanged. Do not change controller, repository, save, share, delete, or navigation contracts.

## Group 3: Focused automated coverage

Depends on Group 2.

- [x] T06: Extend test/presentation/entries/entry_detail_screen_test.dart to verify taps on cleaned text and raw-transcript fallback enter editing with complete content, focus, and Done; compare with existing Edit-button behavior.
- [x] T07: Verify Done/read/re-entry, repeated activation without unintended completion or text reset, long-text scrolling and metadata taps without editing, and normal editor cursor/selection behavior.
- [x] T08: Inspect widget semantics for readable content, the edit hint, and one effective body activation action; invoke that action and verify editing starts. Retain existing header semantics assertions.
- [x] T09: Extend integration_test/entry_detail_flow_test.dart for cleaned/fallback body taps, Edit-button parity, Done/re-entry, metadata taps, and long-text scrolling. Exercise edits followed by Done or system back, sharing, word-count updates, and preservation of the raw transcript.
- [x] T10: Update integration_test/entry_detail_device_smoke_test.dart to enter editing through the body, assert focus before injecting text, leave through in-app back, and reopen the entry to confirm persisted content.
- [x] T11: In the existing screen test file, verify loading exposes no tappable entry body and that a save failure after body-triggered editing retains the existing generic error and keeps the user in editing when Done or back cannot flush. Reuse existing controller failure coverage and missing/unreadable, sharing, and deletion regressions. Format touched Dart files, run flutter analyze, run entry-detail screen/controller tests, and resolve change-related failures.

## Group 4: Platform validation

Depends on Group 3. Use synthetic entries and existing app-lock overrides.

- [x] T12: Discover Android emulator and iOS simulator IDs and record platform versions. Keep physical installations and unrelated user data out of scope.
- [x] T13: Run both modified entry-detail integration files on Android emulator; record exact commands, build/test results, and persistence assertions.
- [x] T14: On Android, verify software keyboard activation after a body tap before text injection, Done/re-entry, normal editor cursor/selection, reading scroll, metadata taps, accessibility action, and both navigation persistence paths. Preserve capture protection and record any screenshot limitations.
- [x] T15: Run both modified integration files on iOS simulator; record exact commands, build/test results, and persistence assertions.
- [x] T16: On iOS, enable the software keyboard if needed and verify body-triggered keyboard activation before text injection, Done/re-entry, normal editor selection, reading scroll, metadata taps, accessibility action, and reopened content. Identify the system-back test as a harness action, not edge-swipe validation.
- [x] T17: Record successful Android and iOS compilation from device test builds. Restore any temporary validation settings. If required verification is blocked, record the limitation and request an explicit decision; no validation exception is currently approved.

## Group 5: Implementation record and external review

Depends on Group 4.

- [x] T18: Create implementation.md documenting changed behavior, files, exact verification commands and results, runtime evidence, and any limitations. Update spec acceptance checkboxes and tasks only where evidence supports completion.
- [x] T19: Present the implemented result and stop for externally authored review.md, unless the user explicitly skips review. Do not create or prefill that file.
- [x] T20: When review.md is supplied, read and assess each finding, prepare a remediation plan, and wait for approval before changing any files.
- [x] T21: Implement approved remediation and update affected artifacts, code, tests, and validation evidence. Repeat review/fix handling if the user provides another review pass. Record explicit skips or no-change decisions when applicable.

## Group 6: Finalization

Depends on review completion or an explicit review skip.

- [x] T22: Propose a docs/application-description.md update describing both edit entry points. Assess whether AGENTS.md or docs/agent-findings.md need durable guidance and present any proposed updates.
- [ ] T23: Wait for approval before editing long-lived documentation; apply approved changes or record an explicit no-update decision.
- [ ] T24: Confirm acceptance criteria, validation, review handling, and documentation decisions are complete; mark the spec Complete and present the final result.

## Completion criteria

Every applicable task is completed with evidence. Conditional review/fix tasks
may be closed with the explicit user decision that made them unnecessary.
Both Android emulator and iOS simulator verification are required unless the
user explicitly approves a changed validation plan.

## Validation evidence

- Focused entry-detail tests after remediation: 26 passed.
- flutter analyze --no-pub: no issues found.
- Android 17/API 37, emulator-5554: detail flows 7 passed; final smoke tests 3 passed.
- iPhone 17 / iOS 26.5: detail flows 7 passed; final smoke tests 3 passed on 2026-09-24 (exit 0).
- Final iOS smoke log: /private/tmp/wrait047-ios-smoke-final.log.
- Full commands, runtime evidence, and initial test-harness corrections: [implementation.md](implementation.md).
- Follow-up from a user-reported general-suite failure: native keyboard insets are now required only with --dart-define=VERIFY_ENTRY_SOFTWARE_KEYBOARD=true. Editor focus is always asserted before injection. Controlled platform keyboard checks remain required; see implementation.md for follow-up results.

## Notes

- Spec and plan approved on 2026-09-23.
- Tasks and analysis approved on 2026-09-23. Implementation and all planned platform checks are complete as of 2026-09-24.
- Preserve unrelated workspace changes, including spec 048 and template.html.

## Cross-artifact analysis — 2026-09-23

Result: ready for implementation approval. No unresolved scope contradictions
or missing task dependencies were found. This is an artifact consistency check,
not evidence that implementation or runtime validation has passed.

Acceptance criteria are numbered below by their order in spec.md.

| Spec criteria | Planned approach | Tasks and verification |
| --- | --- | --- |
| 1–2: tap readable cleaned or fallback text | Read-body callback shares the current edit transition. | T03, T06, T09, T10; both platforms T13–T16. |
| 3: scrolling and metadata do not edit | Callback remains on text, with existing gesture recognition. | T05, T07, T09, T14, T16. |
| 4–6: Edit parity, full content, focus, existing cursor behavior | Reuse current synchronization and focus; no coordinate mapping. | T03, T06, T09; keyboard checked before injection in T14/T16. |
| 7–8: existing Edit and normal editor interaction | Preserve header and editor; guard repeated body activation. | T03, T05, T07, T09, T14, T16. |
| 9: save, Done, back, sharing, deletion, scroll, and errors | Reuse existing controller/repository and lifecycle. | T05, T07, T09–T11, T13–T16. |
| 10: accessible body action and existing Edit accessibility | Shared guarded semantic action with readable content. | T04, T08, T14, T16. |
| 11: loading, missing, invalid, unreadable states | Add the callback only within the readable data branch. | T05, T11 and retained integration route regressions in T13/T15. |

Architecture decisions are represented by T03–T05 and tested by T06–T16.
All in-scope user flows have planned integration coverage; widget tests cover
gesture/semantics edge cases and failure-state boundaries. Android and iOS
builds, real keyboard checks, and runtime evidence are explicit requirements,
with no approved exceptions.

The dependency order is foundation, presentation change, automated coverage,
platform verification, implementation record/review, then finalization. No task
introduces cursor-at-tap placement, new persistence behavior, backend changes,
or scope from discarded proposal 043. No delegation is required.

Correction made during analysis: the existing tests do not explicitly cover a
loading-state body action or save failure after body-triggered edit entry.
T11 and the plan now specify those checks in the already-planned screen test
file. Existing controller failure coverage is reused. This closes a validation
gap without changing the feature's acceptance criteria or production scope.

Approval gate: present this analysis and wait for explicit user approval before
T02 or any application/test implementation changes.

## Approved review remediation — 2026-09-24

- [x] R01: Assess all ten findings and obtain explicit remediation approval.
- [x] R02: Extract a bounded keyboard helper with explicit timeout/poll interval (finding 6).
- [x] R03: Give widget test variants descriptive names (finding 7).
- [x] R04: Cover full content and focus when editing 400-line entries in widget and platform integration tests (finding 10).
- [x] R05: Record approved no-change dispositions and localization/manual screen-reader deferrals in implementation.md; preserve external review.md.
- [x] R06: Run focused tests (26 passed), formatting, and analyzer (clean).
- [x] R07: Revalidate both platform integration suites with visible-keyboard verification enabled and record results.
- [x] R08: Present completed fixes and proposed durable documentation updates for approval.

Remediation validation confirmed on 2026-09-25: both full entry-detail integration
commands passed 10 tests each with VERIFY_ENTRY_SOFTWARE_KEYBOARD=true. Exact
commands and proposed documentation text are recorded in implementation.md.
