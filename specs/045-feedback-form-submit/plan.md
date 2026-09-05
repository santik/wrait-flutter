# Implementation Plan: Single-step Feedback Submission Form

> **Feature number:** 045
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-09-04

---

## Approach summary

Extend the existing in-memory feedback draft with a required message, render
that message field immediately below the optional reply contact field, and
rename the primary action from `Continue` to `Submit`. The feedback dialog will
return a complete draft and the service will submit it directly without
opening the provider-managed message screen. A small local adapter will reuse
the pinned Wiredash 2.6.1 submission and metadata primitives behind the
existing injectable launcher seam, preserving the current privacy allowlist,
configuration handling, pending-feedback behavior, and result statuses.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Form ownership | Keep the existing top-anchored preparation dialog as the single feedback form | It already owns category/contact state, keyboard-safe scrolling, retry restoration, and the required main-screen entry point. Extending it avoids a second form or a new route. |
| Message validation | Require a non-whitespace message and a selected category before enabling `Submit`; keep contact optional and unrestricted | Wiredash requires a message, and the existing category requirement must remain. A disabled primary action gives immediate feedback without submitting invalid data. |
| Message limits | Use multiline input with the existing Wiredash-compatible 2,048-character maximum | This preserves the provider's current message boundary while keeping the form usable on small screens. |
| Submission boundary | Add a local direct-submission adapter that creates a provider feedback item from the complete draft and submits it programmatically; do not call `WiredashController.show()` | The public controller API always opens a separate message-entry flow and cannot accept a pre-entered message. Reusing the pinned SDK's submission primitives avoids reimplementing its request and pending-storage format. |
| SDK coupling | Isolate imports of pinned Wiredash submission internals in one adapter and pin the dependency exactly to 2.6.1 | The package exposes the UI controller but not a public prefilled-message submission API. Isolation and an exact dependency pin limit the impact of SDK changes, while a local transport contract test detects request-shape drift without creating provider records. |
| Retry behavior | Keep `_pendingDraft` in `WiredashFeedbackService` until success or cancellation; count provider `submitted` and `pending` outcomes as completed user submissions | All form values, including the message, are restored after a thrown/unavailable submission, and existing offline behavior remains available through the SDK's pending-feedback mechanism. |
| Test seam | Retain the injectable `WiredashFlowLauncher` and use it for widget/service/integration tests; exercise the adapter with the real 2.6.1 model and submitter against a local fake HTTP client | Tests remain deterministic and make no real feedback requests, while the actual SDK serialization and transport boundary are covered without depending on provider credentials. |
| Stable selectors | Replace the preparation action key with `feedbackSubmitButtonKey` and add a stable message-field key | Tests and accessibility checks should describe the new contract and should not depend on visible copy alone. |
| App shell | Leave the existing `Wiredash` wrapper below `AppLockGate` and do not move feedback work into startup | The wrapper keeps the SDK's lifecycle and pending-feedback upload behavior available; the direct adapter does not open provider UI or add startup work. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/presentation/feedback/feedback_model.dart` | Modify | Add the required user-entered message to `FeedbackDraft`. |
| `lib/presentation/feedback/feedback_preparation_sheet.dart` | Modify | Add the multiline message field below contact, restore it from an initial draft, validate category/message, rename the primary action to `Submit`, and expose updated stable keys. |
| `lib/presentation/feedback/feedback_service.dart` | Modify | Pass the complete draft to the direct submission boundary, remove the controller-driven second screen, preserve single-flight behavior, and retain all values after failure/unavailability. |
| `lib/presentation/feedback/feedback_providers.dart` | Modify | Supply the configured Wiredash project ID, secret, and environment to the production feedback service. |
| `lib/presentation/feedback/wiredash_feedback_submission.dart` | Create | Encapsulate the direct provider submission path: configure the pinned SDK service graph, apply the safe metadata callback, set the message, create the feedback item, submit it, and dispose temporary resources without exposing raw diagnostics. |
| `pubspec.yaml` | Modify | Pin Wiredash exactly to 2.6.1 because the adapter uses its internal service graph. |
| `test/presentation/feedback/feedback_preparation_sheet_test.dart` | Modify | Cover field order, message validation, message/contact draft creation, submit/cancel behavior, and keyboard-safe layout with the new action key. |
| `test/presentation/feedback/feedback_metadata_test.dart` | Modify | Update draft construction for the message field and verify message text is not copied into metadata. |
| `test/presentation/feedback/feedback_service_test.dart` | Modify | Cover direct complete-draft submission, message retry preservation, single-flight behavior, timeout failure mapping, sanitized outcomes, and the new stable selector. |
| `test/presentation/feedback/wiredash_feedback_submission_test.dart` | Create | Verify the adapter's injected submission seam, real SDK item construction, and local transport serialization without opening provider UI or logging message content. |
| `test_driver/feedback_screenshot.dart` | Create | Persist named integration screenshots under the feature evidence directory. |
| `integration_test/main_feedback_flow_test.dart` | Modify | Replace the fake second dialog with a fake direct submission boundary, cover one-step submit/cancellation/retry, and capture the populated form for device evidence. |
| `integration_test/app_lock_flow_test.dart` | Modify | Update the feedback-surface selector and ensure the root lock still covers the expanded form. |

No changes are planned for the Wrait database, backend OpenAPI contract,
recording flow, router, native Android/iOS sources, deployment scripts, or the
app-shell mounting code.

## API contract details

### Existing Wrait service contract

The public application-facing contract remains:

```text
open(context, appArea) -> FeedbackLaunchResult
```

The preparation dialog returns:

```text
FeedbackDraft(
  category: Bug | Idea | Confusing | Praise,
  replyContact: arbitrary text, possibly blank,
  message: non-whitespace text, max 2048 characters,
)
```

`FeedbackLaunchStatus` remains `submitted`, `cancelled`, `unavailable`, or
`failed`. The service clears the pending draft on cancellation or successful
submission and retains it after an unavailable or failed attempt.

### Direct provider submission

The production adapter will use the pinned Wiredash 2.6.1 SDK service graph to
create and submit the same type of feedback item the existing provider UI
creates:

- `message` is the trimmed text entered by the user.
- category, app area, platform, locale, and optional trimmed contact continue
  to come from the existing allowlisted metadata builder.
- explicit contact is copied only to the provider's non-email `userId` field
  and the `reply_contact` custom field. The provider's strict `userEmail`
  field remains unset, even when the contact happens to look like an email,
  because the form accepts arbitrary free text.
- provider labels remain empty, email and screenshot prompts remain hidden,
  and no screenshot or attachment is created.
- the adapter does not call `WiredashController.show()`, `Wiredash.trackEvent`,
  or any analytics API.

The adapter will treat both immediate provider submission and provider-persisted
pending submission as a completed user action, matching the current Wiredash
feedback result semantics. Exceptions remain developer-only diagnostics and are
converted by the service into the existing sanitized failure result.

## Data model changes

No persisted Wrait data model or migration is required.

### Before

```text
FeedbackDraft {
  category: FeedbackCategory
  replyContact: String
}
```

### After

```text
FeedbackDraft {
  category: FeedbackCategory
  replyContact: String
  message: String
}
```

`FeedbackDraft` remains in memory only. It is not written to the encrypted
journal database and does not change entry import/export or database lifecycle
behavior.

### Migration

None. Existing callers and tests will be updated to provide a message. No
stored feedback draft format exists in Wrait to migrate.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Renders the four categories, contact field, message field directly below contact, privacy copy, Cancel, and Submit | Widget | `test/presentation/feedback/feedback_preparation_sheet_test.dart` |
| Keeps Submit disabled until category and non-whitespace message exist; accepts blank/arbitrary contact | Widget | `test/presentation/feedback/feedback_preparation_sheet_test.dart` |
| Returns a complete draft and returns no draft on cancel | Widget | `test/presentation/feedback/feedback_preparation_sheet_test.dart` |
| Keeps the top anchor, fixed panel height, and action gap stable while either field receives keyboard insets | Widget | `test/presentation/feedback/feedback_preparation_sheet_test.dart`, `test/presentation/feedback/feedback_service_test.dart` |
| Builds safe metadata without including the message or sensitive Wrait data | Unit | `test/presentation/feedback/feedback_metadata_test.dart` |
| Direct adapter receives the trimmed message and submits one item with the safe metadata contract | Unit | `test/presentation/feedback/wiredash_feedback_submission_test.dart` |
| Direct adapter serializes the real pinned SDK request through a local HTTP client without provider network access | Contract | `test/presentation/feedback/wiredash_feedback_submission_test.dart` |
| Service reports submitted, cancelled, unavailable, and failed outcomes and preserves category/contact/message for retry | Widget/service | `test/presentation/feedback/feedback_service_test.dart` |
| Service maps a timeout to the sanitized failed outcome | Widget/service | `test/presentation/feedback/feedback_service_test.dart` |
| Concurrent opens coalesce into one direct submission | Widget/service | `test/presentation/feedback/feedback_service_test.dart` |
| Category choices, fields, and actions expose meaningful semantics | Widget/accessibility | `test/presentation/feedback/feedback_preparation_sheet_test.dart` |
| Complete main-screen flow submits once from the initial form; no second message dialog appears | Integration | `integration_test/main_feedback_flow_test.dart` |
| Cancel does not invoke submission and failed submission restores all three entered values | Integration | `integration_test/main_feedback_flow_test.dart` |
| App lock remains above an open expanded feedback form | Integration | `integration_test/app_lock_flow_test.dart` |

All automated submission tests use synthetic message/contact values and local
fakes. The adapter contract test uses the real pinned SDK model and direct
submitter with a local HTTP client; it must not send feedback to the configured
external project.

### Android emulator verification

1. Build and launch the app on the configured Android emulator with the
   existing non-production Wiredash configuration, using a launcher-style cold
   start in addition to the normal test launch.
2. Open feedback from the main screen and verify the order: four categories,
   reply contact, multiline feedback field, privacy copy, Cancel, and Submit.
3. Verify Submit is disabled with no category or blank message, then enter a
   synthetic category, arbitrary contact, and message and submit directly from
   the initial form.
4. Confirm no second provider-managed message-entry screen appears, success is
   shown, and the main screen returns normally.
5. Exercise cancellation, keyboard scrolling/top anchoring, failure/retry, and
   app-lock coverage with synthetic data.
6. Capture test output and the populated-form screenshot through the feature
   screenshot driver. Credentialed provider verification is tracked separately
   as deferred release gate TD-045-01; do not inspect or report any private
   journal data.

### iOS simulator verification

1. Build and launch the app on the configured iOS simulator with the existing
   non-production Wiredash configuration.
2. Repeat the Android form-order, validation, keyboard, direct-submit, success,
   cancellation, and failure/retry checks.
3. Confirm no second provider-managed message-entry screen appears and that
   returning to the main screen preserves existing navigation and lock behavior.
4. Capture test output and the populated-form screenshot through the feature
   screenshot driver. If the simulator's native capture privacy cover or
   passcode prompt prevents a form image, retain that evidence and document the
   limitation; do not weaken native privacy behavior. Credentialed provider
   verification remains deferred under TD-045-01.

### Validation exception request

No exception is requested for Android emulator or iOS simulator verification;
both remain required before final approval. Credentialed provider transport is
an explicitly deferred release gate (TD-045-01), not an automated-test
requirement, because it would create an external feedback record.

## Review and finalization

- The implementation will stop after creating `implementation.md` and wait for
  an externally authored `review.md`, unless the user explicitly skips review.
- Each review finding will be judged individually. No files will be changed
  after reading `review.md` until a remediation plan is explicitly approved.
- Review remediation approved on 2026-09-05 pins Wiredash exactly to 2.6.1,
  adds a real-SDK/local-transport contract test, adds accessibility and timeout
  assertions, and retains mobile screenshot evidence without changing the
  feedback form or native privacy behavior.
- The unrelated untracked `specs/043-entry-inline-edit-autosave/` directory is
  preserved as user-owned workspace state and is outside this feature's
  tracked scope; it is not deleted by the feedback remediation.
- Credentialed provider transport verification is tracked as TD-045-01 and is
  deferred until an explicitly authorized synthetic submission/cleanup window.
- Because this changes the feedback flow from provider-managed UI to a direct
  submission adapter, durable knowledge capture was proposed for
  `AGENTS.md`, `docs/application-description.md`, and
  `docs/agent-findings.md`. The user approved the proposal, and the approved
  updates were applied on 2026-09-05.

## Integration notes

- `feedbackServiceProvider` will pass the current app configuration into the
  service. Missing credentials continue to make feedback unavailable without
  affecting startup or normal app rendering.
- The existing `Wiredash` widget remains mounted below `AppLockGate` so its
  lifecycle and pending feedback upload behavior remain available. The local
  direct adapter will use the same project/environment and SDK storage
  conventions.
- The app-lock integration continues to cover the entire feedback surface; no
  route-specific lock logic is added.
- The metadata builder remains the single privacy allowlist. The message is
  transmitted only as the explicitly typed feedback body and is never added to
  metadata or developer logs. Reply contact remains free text and is not sent
  through Wiredash's strict email field.

## Rollout & migration

No feature flag, backend migration, or data migration is required. The change
ships with the existing app version and Wiredash configuration. Builds without
the required credentials continue to show the existing sanitized unavailable
behavior. Release and debug deployment scripts do not need new inputs because
the already-supported Wiredash configuration defines are reused.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Wiredash 2.6.1 does not expose a stable public programmatic submission API | High | High | Keep all internal SDK imports in one adapter, pin/verify 2.6.1, add compile-time and local-transport adapter coverage, and reserve credentialed Android/iOS checks for the explicitly authorized release gate. |
| Credentialed provider transport has not been exercised locally | Medium | Medium | Track TD-045-01 as a release gate requiring explicit authorization, synthetic data, and provider-side cleanup; rely on the local real-SDK transport contract test for deterministic validation. |
| The expanded form exceeds small-screen height or loses its top anchor | Medium | Medium | Reuse the existing constrained scroll layout, preserve fixed-height/action-gap regression tests, and verify both keyboard paths on both platforms. |
| A failed direct submission loses the message while reopening feedback | Medium | High | Store the complete draft in `_pendingDraft` before submission and test failure/retry with category, contact, and message assertions. |
| A rapid repeated tap creates duplicate submissions | Low | High | Preserve the service single-flight guard and ensure the integration fake records exactly one submission. |
| User-entered message text leaks through diagnostics | Low | High | Do not interpolate the message into Wrait logs or metadata; review the adapter and runtime diagnostics for sanitized errors only. |
| The temporary SDK service graph conflicts with the mounted SDK's pending storage | Medium | Medium | Use the same configured project/environment and SDK storage conventions, keep one in-flight service request, and validate offline/pending behavior on both platform runtimes. |

## Open items from spec

None. The spec's direct one-step submission decision is finalized.
