# Tasks: Single-step Feedback Submission Form

> **Feature number:** 045
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-09-04

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

### Group 1: Contracts and submission seam

Add the complete in-memory draft shape, stable selectors, configuration inputs,
and the isolated direct-submission boundary before changing the visible flow.

- [x] [P] Add the required `message` field to `FeedbackDraft` and update all
      repository callers to construct complete drafts —
      `lib/presentation/feedback/feedback_model.dart`
- [x] [P] Replace the preparation `Continue` selector with
      `feedbackSubmitButtonKey` and add `feedbackMessageFieldKey`; inventory
      and update all existing selector references —
      `lib/presentation/feedback/feedback_preparation_sheet.dart`,
      `test/`, `integration_test/`
- [x] [P] Define the injectable direct-submission adapter contract and isolate
      all Wiredash 2.6.1 service-graph/internal imports in the adapter —
      `lib/presentation/feedback/wiredash_feedback_submission.dart`
- [x] [P] Pass Wiredash project ID, secret, and environment from app
      configuration into the production feedback service without changing
      startup behavior —
      `lib/presentation/feedback/feedback_providers.dart`,
      `lib/presentation/feedback/feedback_service.dart`
- [x] Pin `wiredash` exactly to `2.6.1` and confirm the mounted app-shell
      wrapper remains available for SDK lifecycle and pending-feedback uploads;
      do not add a new credential or deployment-script interface —
      `pubspec.yaml`, `pubspec.lock`, `lib/app.dart`
  - Depends on: none

### Group 2: Core implementation

Implement the one-step form and direct provider submission while preserving the
existing privacy, retry, lifecycle, and app-lock boundaries.

- [x] Add a message controller initialized from `initialDraft`, dispose it
      correctly, and render a labeled multiline field directly below the reply
      contact field with the 2,048-character limit —
      `lib/presentation/feedback/feedback_preparation_sheet.dart`
  - Depends on: Group 1 draft contract and message selector
- [x] Keep reply contact optional and unrestricted; enable `Submit` only when a
      category is selected and the message contains non-whitespace text —
      `lib/presentation/feedback/feedback_preparation_sheet.dart`
  - Depends on: previous form-field task
- [x] Replace the visible `continue` action with `submit`, return category,
      contact, and message together, and keep `Cancel` non-submitting —
      `lib/presentation/feedback/feedback_preparation_sheet.dart`
  - Depends on: previous validation task
- [x] Preserve the top-anchored constrained scroll layout, fixed panel height,
      bottom action gap, privacy copy, and keyboard behavior with the expanded
      content; keep the focused field mounted while IME insets update and keep
      the full panel visible whenever it fits above the keyboard —
      `lib/presentation/feedback/feedback_preparation_sheet.dart`
  - Depends on: previous form-field tasks
- [x] Implement the production adapter using the pinned Wiredash 2.6.1
      submission primitives: apply the existing clean metadata allowlist, set
      the typed message as the feedback body, keep labels empty, hide email and
      screenshot prompts, submit without `WiredashController.show()`, and
      dispose temporary resources safely —
      `lib/presentation/feedback/wiredash_feedback_submission.dart`
  - Depends on: Group 1 adapter contract and configuration inputs
- [x] Update `WiredashFeedbackService` to submit the complete draft through the
      adapter/launcher seam, never open a second provider message screen, keep
      `_pendingDraft` until success or cancellation, and preserve the existing
      single-flight and sanitized result behavior —
      `lib/presentation/feedback/feedback_service.dart`
  - Depends on: form draft and production adapter tasks
- [x] Verify no explicit analytics, screenshots, automatic journal/audio data,
      raw diagnostics, or message text in Wrait logs is introduced by the direct
      submission path —
      `lib/presentation/feedback/feedback_service.dart`,
      `lib/presentation/feedback/wiredash_feedback_submission.dart`
  - Depends on: production adapter task
- [x] Keep reply-contact text in free-text provider fields only; do not send it
      through Wiredash's strict `userEmail` field, which rejects non-email
      contacts —
      `lib/presentation/feedback/feedback_metadata.dart`,
      `lib/presentation/feedback/wiredash_feedback_submission.dart`
  - Depends on: production adapter task

### Group 3: Automated validation

Add deterministic coverage before device verification. No automated test may
send feedback to the external project.

- [x] [P] Update metadata tests for the new draft constructor and verify the
      message remains feedback body data, not metadata —
      `test/presentation/feedback/feedback_metadata_test.dart`
- [x] [P] Extend preparation-sheet widget tests for field order, message key,
      required category/message validation, 2,048-character input, arbitrary or
      blank contact, complete draft return, Submit, Cancel, and updated keyboard
      anchoring —
      `test/presentation/feedback/feedback_preparation_sheet_test.dart`
- [x] [P] Add direct-adapter tests through its injected submission seam for one
      complete message, safe allowlisted metadata, no provider UI launch, and
      no message logging; exercise the real pinned Wiredash model and direct
      submitter through a local HTTP client without provider network access —
      `test/presentation/feedback/wiredash_feedback_submission_test.dart`
- [x] [P] Add accessibility assertions for the four category choices, both
      text fields, Cancel, and Submit —
      `test/presentation/feedback/feedback_preparation_sheet_test.dart`
- [x] [P] Update feedback-service tests for complete-draft submission,
      submitted/cancelled/unavailable/failed results, single-flight coalescing,
      timeout failure mapping, retry restoration of category/contact/message,
      plus keyboard focus retention across inset changes and full-panel
      keyboard visibility —
      `test/presentation/feedback/feedback_service_test.dart`
- [x] [P] Update the main feedback integration fake to accept the message on
      the submitted draft, remove the fake second message dialog, and verify
      one-step submit, no duplicate call, cancellation, and failure retry —
      `integration_test/main_feedback_flow_test.dart`
- [x] [P] Update app-lock feedback-surface assertions to use the Submit key and
      verify the root lock still covers the expanded form —
      `integration_test/app_lock_flow_test.dart`
- [x] Update every remaining `FeedbackDraft` constructor and old Continue-key
      reference found by repository search; run `dart format` on all changed
      Dart files —
      `lib/`, `test/`, `integration_test/`
- [x] Run focused feedback widget/unit tests, service/adapter tests, app-lock
      integration coverage, and the main feedback integration flow with no
      network submission.
- [x] Run `flutter analyze` and the relevant project test suites; confirm no
      generated backend package or unrelated feature regression is introduced.
  - Depends on: Group 2 implementation tasks

### Group 4: Runtime verification

Validate the actual expanded form and direct provider submission on both
required mobile runtimes using synthetic values and the existing non-production
configuration.

- [x] Build and launch on an Android emulator, including launcher-style cold
      start verification.
- [x] On Android, verify the form order, four categories, optional contact,
      message field, privacy copy, Cancel, Submit, disabled validation states,
      keyboard scrolling/top anchoring, and unchanged main-screen recording
      behavior.
- [x] On Android, submit synthetic feedback from the initial form and verify no
      second provider-managed message screen appears; capture success,
      cancellation, failure/retry, and app-lock evidence.
- [x] Defer credentialed Android/iOS provider-boundary verification as release
      gate TD-045-01; require explicit authorization, synthetic data, and
      provider-side cleanup before executing it. Do not create a provider
      record during local feature validation.
- [x] Build and launch on an iOS simulator with the existing non-production
      configuration.
- [x] On iOS, repeat form order, validation, keyboard scrolling/top anchoring,
      direct submit, success, cancellation, failure/retry, app-lock, and main
      screen regression checks.
- [x] Store command output and screenshots in the implementation evidence and
      document the iOS native privacy-cover/passcode limitation without
      claiming an unverified provider form screenshot, console state, or
      credentialed transport result —
      `test_driver/feedback_screenshot.dart`, `specs/045-feedback-form-submit/evidence/`
  - Depends on: Group 3 automated validation

### Group 5: Review and fix

Handle the mandatory external review loop after implementation.

- [x] Create `implementation.md` with implementation details, changed files,
      direct-submission rationale, privacy evidence, automated test results, and
      Android/iOS runtime evidence.
- [x] Stop and wait for an externally authored `review.md`, unless the user
      explicitly skips review.
- [x] Read `review.md`, judge each finding individually, and prepare a
      remediation plan without changing files.
- [x] Present the remediation plan and wait for explicit approval before making
      any remediation changes.
- [x] Implement the approved review fixes and update the feature artifacts,
      code, tests, and validation evidence where scope, approach, or validation
      changed.
- [x] Confirm the unrelated untracked `specs/043-entry-inline-edit-autosave/`
      directory is preserved as user-owned workspace state and excluded from
      the feedback feature scope; do not delete or move it in this remediation.
- [x] Confirm no second review/fix pass is required because the external
      `review.md` was not updated after the approved remediation.
  - Depends on: Group 4 runtime verification

### Group 6: Finalization

Complete durable knowledge capture only after implementation and review are
finished.

- [x] Decide whether the direct submission adapter or changed feedback flow
      created durable product or architecture guidance; durable guidance was
      identified for the free-text contact contract, exact SDK pin, and local
      transport validation.
- [x] Propose updates to `AGENTS.md`, `docs/application-description.md`, and
      `docs/agent-findings.md`.
- [x] Wait for explicit approval before editing those long-lived documents.
- [x] Apply only the approved documentation updates.
- [x] Record that the knowledge-capture gate resulted in durable updates to
      `AGENTS.md`, `docs/application-description.md`, and
      `docs/agent-findings.md`.
- [x] Mark the feature status `Complete` after all acceptance criteria, tests,
      runtime checks, review handling, and finalization gates were done.
  - Depends on: Group 5 review and fix completion

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

To be recorded during implementation:

```text
2026-09-04
- flutter analyze: passed with no issues.
- Android main feedback integration: 2/2 passed on emulator-5554.
- Android app-lock integration: 7/7 passed on emulator-5554.
- Android launcher-style cold start: Status ok for
  com.wrait.flutter/com.wrait.flutter.MainActivity.
- iOS main feedback integration: 2/2 passed on iPhone 17 simulator.
- iOS app-lock integration: 7/7 passed on iPhone 17 simulator.
- Android/iOS feedback integration focus assertions: passed on both mobile
  targets after the IME focus fix.

2026-09-05
- flutter pub get: passed with Wiredash resolved at the exact 2.6.1 pin.
- flutter analyze: passed with no issues after the review remediation.
- flutter test test/presentation/feedback: 21 feedback tests passed.
- feedback metadata/adapter tests: 8 tests passed, including the local real-SDK
  transport contract.
- flutter test: 450 tests passed.
- Android main feedback integration: 2/2 passed on emulator-5554; the driver
  screenshot run also passed and retained `evidence/feedback_form_android.png`.
- iOS main feedback integration: 2/2 passed on iPhone 17 simulator; the driver
  screenshot run also passed and retained `evidence/feedback_form_ios.png`,
  which shows the expected native `Private` capture cover.
- Android app-lock integration: 7/7 passed on emulator-5554.
- iOS app-lock integration: 7/7 passed on iPhone 17 simulator.
- Wiredash endpoint validation identified strict rejection of arbitrary
  `userEmail` contact text; no feedback record was created during diagnostics.
- Accessibility assertions cover category, field, and action semantics.
- Timeout failure mapping is covered at the feedback service boundary.
- git diff --check: passed.

Credentialed provider transport/console submission remains deferred as
TD-045-01 because it would create an external feedback record. The direct
adapter was validated against the real pinned Wiredash model and submitter with
a local fake HTTP client. The iOS form screenshot could not be captured through
the native simulator surface because the app's privacy cover and the existing
simulator passcode prompt protect the screen; that limitation is documented in
implementation.md without weakening privacy behavior.
```

## Notes

- The direct provider submission adapter is intentionally isolated because the
  current public Wiredash controller API cannot submit a prefilled message.
- No validation exception is requested; both Android emulator and iOS
  simulator checks are required.
