# Tasks: User Feedback First Version

> **Feature number:** 042
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-07-13

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

### Group 1: Foundation

Set up the dependency, configuration, data contracts, and test seams without
changing the user-facing app flow yet.

- [x] Create or confirm a non-production Wiredash project/environment and store
      the project ID and SDK secret only in approved ignored or CI secret
      storage. The supplied credentials are stored in the ignored current
      `android/local.properties` file with private file permissions; live
      Wiredash Console confirmation remains pending.
- [x] Add `wiredash: ^2.6.1` to `pubspec.yaml`, run `flutter pub get`, and
      verify dependency resolution against the current Flutter, Android Gradle,
      Gradle, and Kotlin versions.
- [x] [P] Add `WIREDASH_PROJECT_ID`, `WIREDASH_SECRET`, and
      `WIREDASH_ENVIRONMENT` parsing to `AppConfig` with non-blocking missing
      configuration behavior — `lib/core/config/app_config.dart`
- [x] [P] Define the four feedback categories and in-memory preparation draft
      shape — `lib/presentation/feedback/feedback_model.dart`
- [x] [P] Define the privacy-safe metadata allowlist and builder, including
      blank-contact omission and trimming only at the transport boundary for
      arbitrary plain-text contact —
      `lib/presentation/feedback/feedback_metadata.dart`
- [x] [P] Define the feedback service result types, production provider, and
      fake-launcher override seam —
      `lib/presentation/feedback/feedback_service.dart`,
      `lib/presentation/feedback/feedback_providers.dart`
- [x] [P] Add a stable key and semantics contract for the top-right feedback
      icon button — `lib/presentation/main/main_screen_test_keys.dart`
- [x] Update debug and release deployment configuration interfaces to forward
      Wiredash defines without committing or printing the secret —
      `deploy_debug.sh`, `deploy_release.sh`

### Group 2: Core implementation

Implement the feedback flow and integrate it into the existing app shell and
main screen.

- [x] Mount `Wiredash` below `AppLockGate` inside the existing
      `MaterialApp.router` builder when credentials are configured; preserve
      routing, localization, theme, startup non-blocking behavior, and locked
      surface coverage — `lib/app.dart`
  - Depends on: Group 1 configuration and dependency tasks
- [x] Implement the Wrait preparation sheet with required category selection,
      optional plain-text contact input, privacy copy, cancel, continue, stable
      top anchoring, and state preservation —
      `lib/presentation/feedback/feedback_preparation_sheet.dart`
  - Depends on: Group 1 feedback model task
- [x] Implement the Wiredash adapter/service: launch the preparation sheet,
      call `Wiredash.of(context).show()`, set empty labels, hide email and
      screenshot steps, attach only allowlisted metadata, coalesce concurrent
      calls, return structured results, and sanitize failures —
      `lib/presentation/feedback/feedback_service.dart`
  - Depends on: Group 1 metadata and provider tasks; Wiredash dependency task
- [x] Add exactly one top-right `IconButton` using
      `Icons.feedback_outlined`, tooltip `Send feedback`, and an accessibility
      label; keep it in a stable safe-area header slot and leave the recording
      control and stats behavior unchanged —
      `lib/presentation/main/main_screen.dart`
  - Depends on: Group 1 feedback key/provider tasks
- [x] Verify that no `Wiredash.trackEvent`, `WiredashAnalytics`, screenshot
      attachment, auto-collected user identity, entry data, audio data,
      backend URL, proxy secret, or raw diagnostic data is sent by the feature.
      Explicit contact text is sent only when supplied by the user, in the
      standard Wiredash `userId` field and custom `reply_contact`.
  - Depends on: Wiredash adapter task
- [x] Complete debug/release build-define forwarding and validation. Require
      paired Wiredash values for release builds, keep the secret in the same
      ignored `android/local.properties` mechanism as `PROXY_SECRET`, and
      preserve existing deploy-script safety checks — `deploy_debug.sh`,
      `deploy_release.sh`
  - Depends on: Group 1 deployment configuration task

### Group 3: Automated validation

Add deterministic tests before external-device verification. Tests must not
submit real feedback to Wiredash.

- [x] Add `AppConfig` tests for valid defines, missing values, partial values,
      environment defaults, and startup-safe behavior —
      `test/core/config/app_config_test.dart`
- [x] [P] Add metadata tests proving the exact allowlist, category values,
      broad platform/locale/app-area fields, blank-contact omission, arbitrary
      contact preservation in Wiredash standard metadata and custom
      `reply_contact`, and exclusion of journal/audio/diagnostic fields —
      `test/presentation/feedback/feedback_metadata_test.dart`
- [x] [P] Add preparation-sheet widget tests for all four categories, privacy
      copy, no contact validation with a non-email value, blank contact,
      cancel, required category selection, and continue —
      `test/presentation/feedback/feedback_preparation_sheet_test.dart`
- [x] [P] Add service tests for submitted, cancelled, unavailable, and failed
      results, sanitized error copy, retry preservation, missing controller,
      concurrent-call coalescing, and no data leakage —
      `test/presentation/feedback/feedback_service_test.dart`
- [x] [P] Extend main-screen widget tests to find exactly one top-right
      feedback icon, verify tooltip/semantics, launch the fake service, and
      confirm recording state is unchanged —
      `test/presentation/main/main_screen_test.dart`
- [x] [P] Extend the smoke test to confirm missing Wiredash credentials do not
      block bootstrap, app lock, routing, or normal main-screen rendering —
      `test/app_smoke_test.dart`
- [x] [P] Extend debug/release deployment script tests for paired Wiredash
      values, forwarded build defines, secret exclusion from synchronized local
      properties, and no secret output —
      `test/deploy_debug_script_test.sh`, `test/deploy_release_script_test.sh`
- [x] Add the deterministic integration flow from the main screen: tap the
      single top-right icon, select a category, enter arbitrary contact text,
      enter a free-text message, see privacy copy, submit through a fake
      boundary, verify confirmation, cancel without submission, reset the
      category, and retry after failure without timing sleeps —
      `integration_test/main_feedback_flow_test.dart`
- [x] Extend the app-lock integration flow to verify the lock surface remains
      above the Wiredash feedback surface after a foreground exit —
      `integration_test/app_lock_flow_test.dart`
- [x] Run formatting on all changed Dart files and shell syntax checks on all
      changed shell files.
- [x] Run focused unit/widget tests, deployment script tests, and the feedback
      integration test with no Wiredash network submission.
- [x] Run `flutter analyze` and verify the generated backend package still
      passes the required `flutter pub get` and `flutter analyze` checks.

### Group 4: Runtime verification

Validate the actual Wiredash UI and external delivery with synthetic content
using the non-production project/environment.

- [B] Build and launch on an Android emulator with
      `WIREDASH_PROJECT_ID`, `WIREDASH_SECRET`, and
      `WIREDASH_ENVIRONMENT` supplied through build defines. The credentialed
      build is pending because the required Flutter SDK cache permission
      request was rejected.
- [x] Verify Android cold launch, exactly one top-right feedback icon, tooltip
      and accessibility label, unchanged recording control, category selection,
      privacy copy, and arbitrary non-email contact text.
- [B] Verify Android Wiredash flow contains no email or screenshot step,
      enter and submit synthetic free-text feedback, and inspect the
      console/request payload for the safe metadata allowlist, including the
      explicit contact in the standard `userId` field and custom
      `reply_contact`, plus safe app version, platform, broad app area, locale,
      and submission timestamp where supplied by the SDK. Pending a
      credentialed runtime build.
- [x] Verify Android failure/unavailable behavior, retry behavior, typed
      message preservation, sanitized errors, cancellation, and app-lock
      coverage.
- [B] Capture Android validation evidence: test output, main-screen and
      preparation-sheet screenshots, sanitized failure/retry result, and
      metadata/privacy inspection. Live Wiredash metadata evidence is pending
      a credentialed runtime build.
- [B] Build and launch on an iOS simulator with the same non-production
      Wiredash configuration. The credentialed build is pending because the
      required Flutter SDK cache permission request was rejected; release
      validation also needs transient signing-password environment values.
- [x] Verify iOS cold launch, exactly one top-right feedback icon, unchanged
      recording control, category selection, privacy copy, and arbitrary
      non-email contact text.
- [B] Verify iOS Wiredash flow contains no email or screenshot step, submit
      synthetic free-text feedback, and inspect the console/request payload for
      the safe metadata allowlist, including the explicit contact in the
      standard `userId` field and custom `reply_contact`, plus safe app version,
      platform, broad app area, locale, and submission timestamp where supplied
      by the SDK. Pending a credentialed runtime build.
- [x] Verify iOS failure/retry behavior, cancellation, typed message
      preservation, sanitized errors, and app-lock coverage.
- [B] Capture iOS validation evidence: test output, main-screen and
      preparation-sheet screenshots, real staging delivery or request
      inspection, and metadata/privacy inspection. Live Wiredash metadata
      evidence is pending a credentialed runtime build.
- [x] Confirm no validation exception is being requested; both platform checks
      remain required.

### Group 5: Implementation record and review

Handle the mandatory post-implementation artifacts and external review gate.

- [x] Create `implementation.md` with the final architecture, changed files,
      Wiredash configuration procedure, privacy allowlist, test results, and
      Android/iOS validation evidence.
- [x] Stop and wait for externally authored `review.md`, unless the user
      explicitly skips review.
- [x] Read `review.md` and classify each finding case by case without changing
      files.
- [x] Prepare a remediation plan and stop for explicit user approval before
      applying review changes.
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when scope, approach, or
      validation changes.
- [x] Repeat the review/fix loop if the same `review.md` is updated for another
      pass.

### Group 6: Finalization

Handle durable documentation and closeout only after implementation and review
are complete.

- [x] Decide whether the Wiredash integration, build-time credentials, or
      privacy boundary created durable product or architecture knowledge.
- [x] Propose updates to `AGENTS.md`, `docs/application-description.md`,
      and/or `docs/agent-findings.md` when warranted; do not edit them yet.
- [x] Wait for explicit approval before editing long-lived guidance documents.
- [x] Apply only approved knowledge-capture edits.
- [x] Record whether the knowledge-capture gate resulted in durable updates or
      an explicit no-update decision.
- [x] Update the feature status to `Complete` only after all acceptance
      criteria, tests, runtime checks, review, and finalization gates are done.

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Recorded implementation evidence:

- Root `flutter analyze`: passed with no issues.
- Focused Flutter suite after review remediation: 36 tests passed; the final
  feedback layout and Android manifest regression suite passed 12 tests.
- Android connected Pixel 8 after review remediation: feedback flow 2/2 and
  main-screen flow 9/9 passed.
- Earlier Android emulator: feedback flow 2/2 and app-lock flow 7/7 passed.
- iOS simulator after review remediation: feedback flow 2/2 passed; earlier
  app-lock flow 7/7 also passed.
- Both deployment shell suites and `bash -n`: passed.
- Wiredash credentials are stored in the ignored current
  `android/local.properties` file. Live delivery and console payload
  inspection remain pending because the credentialed build permission request
  was rejected; no validation exception was approved.

```text
# Second-pass review completed; no additional actionable remediation required.
# Durable documentation updates approved and applied.
```

## Notes

- The feedback entry point is the main screen's top-right icon button; no
  Settings entry point is planned.
- The preparation sheet owns category/contact/privacy input because Wiredash's
  native contact field is email-specific.
- No real user or journal data may be used during validation.
