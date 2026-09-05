# Implementation: Single-step Feedback Submission Form

> **Feature number:** 045
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Implementation date:** 2026-09-04
> **Review remediation:** 2026-09-05

## Summary

The feedback preparation dialog is now the complete feedback form. It keeps the
four existing categories and optional unrestricted reply contact, adds a
multiline feedback field below the contact field, and replaces `Continue` with
`Submit`. The submit action is disabled until a category is selected and the
message contains non-whitespace text.

The service now submits the complete in-memory draft directly. It no longer
opens a second provider-managed message screen. Failed submissions retain the
category, contact, and message for retry; cancellation clears the draft.

## Changed files

### Production code

- `lib/presentation/feedback/feedback_model.dart`
  - Added the required `message` property to `FeedbackDraft`.
- `lib/presentation/feedback/feedback_preparation_sheet.dart`
  - Added the keyed multiline message field with a 2,048-character limit.
  - Added non-whitespace message validation and the `Submit` action.
  - Preserved the top anchor, fixed measured panel height, keyboard-aware
    internal scroll viewport, privacy copy, and action bottom gap.
  - Kept the scroll-field subtree stable while the keyboard inset changes and
    supplied persistent focus nodes so opening the IME does not dismiss it.
  - Calculate the keyboard viewport from the available screen height, so a
    panel that already fits above the keyboard remains fully visible instead
    of collapsing to the focused field.
- `lib/presentation/feedback/feedback_service.dart`
  - Routes the complete draft through the direct submission boundary.
  - Preserves single-flight and sanitized result behavior.
- `lib/presentation/feedback/feedback_providers.dart`
  - Passes the configured Wiredash project ID, secret, and environment to the
    service.
- `lib/presentation/feedback/wiredash_feedback_submission.dart`
  - New adapter containing the Wiredash 2.6.1 service-graph imports.
  - Builds a provider feedback item with the typed message and submits it
    without opening provider UI.
- `pubspec.yaml`
  - Pins Wiredash exactly to 2.6.1 because the adapter uses its internal
    service graph.

### Tests

- Updated feedback preparation, metadata, service, main feedback integration,
  and app-lock integration coverage for the complete draft and new selectors.
- Extended the keyboard-layout regression to verify the focused field element
  and focus node survive the IME inset update.
- Added coverage for keeping the complete panel visible when the keyboard fits
  below it.
- Added accessibility assertions for category choices, both text fields, and
  both actions.
- Added timeout failure mapping coverage at the feedback service boundary.
- Added `test/presentation/feedback/wiredash_feedback_submission_test.dart`.
  It exercises the production adapter path with the real pinned Wiredash model
  and submitter against a local fake HTTP client, so no external feedback is
  created.
- Added screenshot capture to the main feedback integration flow and the
  `test_driver/feedback_screenshot.dart` host driver for durable device
  evidence.

## Direct-submission rationale

Wiredash 2.6.1's public controller API opens its own message-entry flow and
does not accept a prefilled message. The new adapter therefore reuses the
SDK's pinned feedback-model and submitter primitives while keeping all
implementation imports isolated to one file. The existing mounted Wiredash
wrapper remains in the app shell for lifecycle and pending-feedback behavior;
the adapter does not add startup work or call `WiredashController.show()`.

Both `submitted` and SDK-persisted `pending` outcomes are treated as completed
feedback actions. Exceptions remain developer-only diagnostics and are mapped
by `WiredashFeedbackService` to the existing sanitized failure result.

## Privacy evidence

- Provider labels are explicitly empty.
- Email and screenshot prompts are explicitly hidden.
- No screenshot or attachment is created.
- The existing metadata allowlist remains the only custom metadata source:
  app area, broad platform, locale, category, and optional trimmed contact.
- The message is sent only as the explicitly typed feedback body and is not
  copied into custom metadata or Wrait logs.
- Contact text is not validated or submitted as an email. When present, its
  trimmed plain text is copied to the provider's standard non-email `userId`
  field and the approved `reply_contact` metadata field. The provider's
  strict `userEmail` field remains unset so arbitrary contacts are accepted.
- No journal text, transcript, audio path, identifier, secret, screenshot, or
  raw diagnostic is attached or logged by the Wrait submission path.

## Validation evidence

The original feature validation was run on 2026-09-04; submission-fix
validation was run on 2026-09-05 from the repository root.

### Static and host-side tests

- `flutter pub get` — passed with Wiredash resolved at the exact 2.6.1 pin.
- `flutter analyze` — passed; no issues found after the submission fix.
- `flutter test test/presentation/feedback` — passed; 21 feedback tests,
  including the new accessibility and timeout coverage.
- `flutter test test/presentation/feedback/feedback_metadata_test.dart
  test/presentation/feedback/wiredash_feedback_submission_test.dart` —
  passed; 8 metadata/adapter tests, including the local real-SDK transport
  contract.
- `flutter test` — passed; 450 tests.
- Deliberately invalid Wiredash validation requests confirmed that arbitrary
  `userEmail` text is rejected while the same contact is valid in `userId` and
  custom metadata; no feedback record was created.
- Android manual IME reproduction — before the fix the IME received a client
  hide request after the inset update; after the fix it remained shown with
  `mInputShown=true`, the multiline field still focused, and the full form
  panel remained present.
- `git diff --check` — passed.

### Android emulator

- `flutter test --no-pub -d emulator-5554 integration_test/main_feedback_flow_test.dart`
  — passed; 2/2 flows after the review remediation, including focused-field
  assertions and the screenshot call.
- `flutter drive --no-pub --driver=test_driver/feedback_screenshot.dart
  --target=integration_test/main_feedback_flow_test.dart -d emulator-5554`
  — passed; retained the complete form image at
  [`evidence/feedback_form_android.png`](evidence/feedback_form_android.png).
- `flutter test --no-pub -d emulator-5554 integration_test/app_lock_flow_test.dart`
  — passed; 7/7 flows.
- Launcher-style cold start:
  `adb -s emulator-5554 shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`
  — passed with `Status: ok` and `Activity: com.wrait.flutter/.MainActivity`.

### iOS simulator

- `flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_feedback_flow_test.dart`
  — passed; 2/2 flows after the review remediation, including focused-field
  assertions and the screenshot call.
- `flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/app_lock_flow_test.dart`
  — passed; 7/7 flows.
- `flutter drive --no-pub --driver=test_driver/feedback_screenshot.dart
  --target=integration_test/main_feedback_flow_test.dart -d
  491CD949-D3C0-4C4C-A6B9-15BAB1859156` — passed; retained
  [`evidence/feedback_form_ios.png`](evidence/feedback_form_ios.png), which
  shows the expected native `Private` capture cover rather than form content.

The mobile flows use synthetic values and the existing injected fake
submission boundary. They verify one-step submission, no duplicate/provider
message screen, cancellation, failure/retry restoration, keyboard reachability,
and app-lock coverage without creating external provider records.

## Validation limitations

Credentialed provider-console/transport verification remains deferred as
TD-045-01. Performing that check would create an external feedback record,
which is outside the authorized local implementation validation. The adapter's
production item construction, prompt configuration, metadata allowlist, and
actual SDK request serialization are covered by the direct-adapter test;
mobile integration uses the safe fake boundary. No provider receipt or console
state is claimed here.

The Android device run retains a complete populated-form screenshot. The iOS
integration screenshot is retained as native capture-privacy evidence: the
scene-level `Private` cover replaces the form when the integration screenshot
surface is captured. A direct `xcrun simctl io screenshot` attempt was also
blocked by the existing simulator iPhone passcode prompt. Native privacy
behavior was not weakened and no unverified iOS form screenshot is claimed.

## Review status

The external review dated 2026-09-05 was read and its approved remediation was
implemented. The unrelated untracked feature-043 specs were preserved as
user-owned workspace state. The credentialed provider check remains deferred
as TD-045-01 and requires separate authorization before any external feedback
record is created. Approved durable documentation updates were applied to
`AGENTS.md`, `docs/application-description.md`, and `docs/agent-findings.md`.
