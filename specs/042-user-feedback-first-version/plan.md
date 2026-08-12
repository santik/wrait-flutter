# Implementation Plan: User Feedback First Version

> **Feature number:** 042
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-07-13

## Approach summary

Use Wiredash as the feedback transport and submission surface, with a small
Wrait-owned top-anchored preparation panel before it. The preparation panel collects the
four-category classification, optional unrestricted plain-text reply contact,
and the privacy warning. Wiredash then collects the free-text message and
handles submission/offline persistence. The main screen gets one top-right
feedback icon button with tooltip and accessibility label. Wiredash is
initialized lazily at the app shell boundary and
receives only an explicit allowlist of safe metadata; product analytics,
screenshots, email validation, journal content, audio, and diagnostic logs are
excluded.

## Approved review remediation

The external review was read and its remediation plan was approved before
these changes. The implementation now:

- replaces Wiredash's custom metadata map with a fresh allowlist object rather
  than merging any SDK-provided custom fields;
- resolves `Wiredash.maybeOf(context)` once and passes the non-null controller
  into the adapter;
- coalesces concurrent service calls and keeps the main-screen in-flight guard
  so rapid taps cannot open duplicate preparation flows;
- trims reply contact only when constructing transport metadata, while keeping
  the preparation draft as user-entered plain text;
- validates project ID, secret, and environment values in both deploy scripts;
- uses one shared top-anchored `showGeneralDialog` helper in production and
  widget tests, with explicit keyboard-anchor coverage. The panel height is
  based on the screen's top safe area and removes keyboard view insets from its
  layout context. Its bottom spacing is a fixed 4px because the panel is
  top-anchored and does not need bottom safe-area padding. Keyboard appearance
  cannot resize the panel or collapse the space below the actions. After the
  first layout, the measured panel height is held as an exact height for the
  lifetime of the dialog;
- configures the Android activity with `adjustNothing` so the keyboard does not
  resize the Flutter window containing the top-anchored panel; Flutter still
  receives keyboard insets for scroll behavior and normal scaffold content;
- covers missing Wiredash mounting, rapid taps, category reset after
  cancellation, and deterministic snackbar dismissal;
- logs only a fixed success message and keeps failure messages sanitized.

Wiredash `2.6.1` does not export its internal API-specific exception classes
through the public `wiredash.dart` surface, so the adapter retains a generic
sanitized catch boundary and sends diagnostics only to `developer.log`.

The current Wiredash Flutter package is `2.6.1`. Its public API supports root
initialization, `Wiredash.of(context).show()`, custom feedback options, and
custom metadata. The package's built-in email prompt is email-specific, so it
cannot be used for this story's unrestricted contact field. See the [package
quick start](https://pub.dev/packages/wiredash), [Wiredash API](https://pub.dev/documentation/wiredash/latest/wiredash/Wiredash-class.html),
and [feedback options API](https://pub.dev/documentation/wiredash/latest/wiredash/WiredashFeedbackOptions-class.html).

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Feedback destination | Wiredash `2.6.1` | Provides the in-app message flow, submission transport, console triage, and offline feedback handling without a new Wrait backend endpoint. |
| User flow shape | Wrait top-anchored preparation panel followed by Wiredash message flow | Wiredash's `EmailPrompt` accepts email only; the preparation panel preserves the approved plain-text contact requirement, provides Wrait-specific privacy copy, and stays fixed when the keyboard appears. |
| Main-screen entry point | One top-right `IconButton` in the main screen's safe-area header, using `Icons.feedback_outlined` with tooltip and semantic label | Top-right is a conventional action location, keeps the recording control unobstructed, and avoids implying back navigation from the top-left. |
| Category transport | Store the selected category as custom Wiredash metadata | Avoids a second category selector inside Wiredash and avoids environment-specific console label IDs. The four allowed values remain exactly `Bug`, `Idea`, `Confusing`, and `Praise`. |
| Contact transport | Store non-empty user-entered contact text, trimmed only at the transport boundary, as custom Wiredash metadata | Preserves arbitrary plain text without format validation, without using `userEmail` or Wiredash email validation. Blank or whitespace-only contact is omitted. |
| Screenshot handling | `ScreenshotPrompt.hidden` | The approved scope excludes screenshots and the app contains private journal content elsewhere. Screenshot capture is disabled at the feedback-flow boundary. |
| Wiredash email handling | `EmailPrompt.hidden` | Prevents Wiredash from presenting an email-only field or rejecting valid non-email contact text. |
| Metadata policy | Fresh allowlisted metadata map per feedback flow | Prevents device IDs, user IDs, backend credentials, transcripts, entry text, file paths, audio, and raw diagnostics from being forwarded accidentally. Wiredash's automatic app-version/submission-time metadata is accepted only after runtime console inspection confirms it contains no Wrait journal data. |
| Preparation dialog | Shared top-anchored `showGeneralDialog` helper used by production and tests | Keeps keyboard geometry, transition, safe-area handling, and scroll behavior covered by the same presentation path. |
| Service concurrency | Coalesce concurrent `open` calls into one request | Prevents rapid taps or multiple callers from overwriting the in-memory retry draft or opening duplicate preparation panels. |
| Analytics | No `Wiredash.trackEvent` or `WiredashAnalytics` calls | Product analytics and behavior tracking are out of scope. Feedback submission is the only Wiredash capability used. |
| Credentials | `WIREDASH_PROJECT_ID`, `WIREDASH_SECRET`, and `WIREDASH_ENVIRONMENT` build defines | Values stay out of source control and are supplied per build environment. The Wiredash secret is embedded in the client binary by necessity and must not be reused as a Wrait backend secret. |
| App-lock boundary | Keep `AppLockGate` above the Wiredash child inside `MaterialApp.router`'s builder | A lock overlay must cover an open feedback surface after a foreground exit. This placement also keeps the existing root privacy behavior intact. |
| Startup behavior | Do not initialize network work during bootstrap | Wiredash must not delay `runApp()`, database opening, app lock, or the first frame. The wrapper is configured synchronously and the network is touched only after the user opens feedback. |
| Wrait backend | No new Wrait API endpoint | Wiredash is the external destination for this first version; the existing Wrait backend contract and generated client remain unchanged. |

## Wiredash setup instructions

### 1. Create the Wiredash project

1. Sign in to the Wiredash Console and create a Wrait feedback project.
2. From the project's general settings, copy the project ID and SDK secret.
3. Use a non-production Wiredash environment for emulator, simulator, and
   development validation. Use a separate production environment or project
   for release builds according to the team's console setup.
4. Do not enable or call Wiredash analytics for this story.
5. Confirm that feedback submissions are visible in the console before wiring
   release credentials into a build.

Wiredash's current setup requires a project ID and SDK secret on the root
`Wiredash` widget. The public package documentation shows the root wrapper and
the `Wiredash.of(context).show()` entry point.

### 2. Add the dependency

Add the pinned current package version to `pubspec.yaml`:

```yaml
dependencies:
  wiredash: ^2.6.1
```

Run `flutter pub get` and `flutter analyze`. Wiredash `2.6.0` raised its
Android build requirements to Android Gradle Plugin `8.12.1`, Gradle `8.13`,
and Kotlin `2.2.0`; this repository currently uses newer versions, but the
dependency resolver and Android build must still be checked explicitly.

### 3. Supply build configuration

Add these compile-time keys to `AppConfig`:

```text
WIREDASH_PROJECT_ID
WIREDASH_SECRET
WIREDASH_ENVIRONMENT
```

Example development launch:

```sh
flutter run -d <device> \
  --dart-define=WIREDASH_PROJECT_ID=<project-id> \
  --dart-define=WIREDASH_SECRET=<sdk-secret> \
  --dart-define=WIREDASH_ENVIRONMENT=dev
```

The project ID and secret must not be committed to Dart source, shell scripts,
tracked local properties, test fixtures, screenshots, or logs. A build with no
Wiredash values remains launchable for local tests, but the feedback button
must show a sanitized unavailable message instead of throwing or blocking
startup. Release deployment configuration must require both project ID and
secret so a production build cannot silently ship an unusable feedback entry
point.

The Android deploy scripts will receive the same values from environment or
the ignored current `android/local.properties` configuration. They must pass
them as transient `--dart-define` values and must not print the secret in
status output. The current local properties file is private and ignored, just
like the existing proxy-secret configuration.

### 4. Mount Wiredash without bypassing the app lock

Inside `WraitApp`'s existing `MaterialApp.router` builder, preserve the
current `AppLockGate` and make the route child the Wiredash child when
credentials are configured:

```text
MaterialApp.router
  builder
    AppLockGate
      Wiredash (when configured)
        router child
```

The implementation must verify that `Wiredash.of(context)` resolves from
`MainScreen` when Wiredash is mounted below `MaterialApp`'s builder. If the
package requires a root placement instead, add an explicit lock-overlay guard
and test that a foreground exit cannot leave the feedback surface above the
privacy lock.

Use `environment` from `WIREDASH_ENVIRONMENT`. Do not perform a network call
from `WraitApp.build`, `main()`, or `bootstrapAppRuntime`.

### 5. Configure the feedback flow

When the user taps the main-screen button:

1. Show the Wrait preparation sheet.
2. Require one category selection from `Bug`, `Idea`, `Confusing`, and
   `Praise`.
3. Show an optional plain-text contact field with no email keyboard and no
   validator. Trim only leading and trailing whitespace at the metadata
   boundary; omit it from metadata when it is blank after trimming.
4. Show privacy copy equivalent to: `Do not include private journal content
   unless you choose to type it into your message.`
5. On continue, call `Wiredash.of(context).show()` with feedback options that:
   - provide an empty label list so Wiredash does not add a second category
     selector;
   - set the email prompt to hidden;
   - set the screenshot prompt to hidden;
   - add only the approved category, broad app area, platform, locale, and
     explicit contact text to custom metadata.
6. On `FeedbackResult.hasSubmittedFeedback == true`, show a concise success
   confirmation and return to the normal main screen.
7. On cancellation, discard the preparation sheet state without submitting.
8. On an unavailable configuration or thrown launch error, show a sanitized
   error and keep the preparation values available for retry. Do not expose
   exception text, URLs, credentials, or stack traces.

The metadata callback must replace the custom map with a clean allowlist object;
it must never merge existing custom fields. It must never set `userId`,
`userEmail`, a Wrait device ID, or any entry/audio-related field. The approved
custom metadata keys are:

```text
app_area = main
platform = broad Flutter platform name
locale = current locale tag
feedback_category = Bug | Idea | Confusing | Praise
reply_contact = user-entered text, only when non-blank
```

Do not add raw current route paths, entry IDs, entry titles, transcripts,
cleaned text, recording paths, audio bytes, export names, backend URLs, proxy
secrets, screenshots, or diagnostic logs. The [custom metadata API](https://pub.dev/documentation/wiredash/latest/wiredash/CustomizableWiredashMetaData-class.html)
supports a custom map; user-entered contact text belongs there only because the
user explicitly supplied it.

## File changes

| File | Action | Description |
| --- | --- | --- |
| `pubspec.yaml` | Modify | Add `wiredash: ^2.6.1`. |
| `lib/core/config/app_config.dart` | Modify | Parse Wiredash project ID, secret, and environment build defines without making startup depend on them. |
| `lib/app.dart` | Modify | Mount Wiredash below the app-lock boundary when configured and keep the existing router/localization/theme behavior. |
| `lib/presentation/feedback/feedback_model.dart` | Create | Define the four categories and the preparation draft with plain-text contact. |
| `lib/presentation/feedback/feedback_metadata.dart` | Create | Build the allowlisted, privacy-safe custom metadata map. |
| `lib/presentation/feedback/feedback_preparation_sheet.dart` | Create | Render category selection, plain-text contact, privacy copy, cancel, continue actions, and the shared top-anchored dialog route. |
| `lib/presentation/feedback/feedback_service.dart` | Create | Coordinate the preparation dialog, Wiredash launch, controller safety, concurrency guard, success/failure handling, and retry state. |
| `lib/presentation/feedback/feedback_providers.dart` | Create | Provide the production feedback service and test override seam. |
| `lib/presentation/main/main_screen.dart` | Modify | Add exactly one top-right feedback icon button in a stable safe-area header slot, with tooltip and accessibility label, without changing recording behavior. |
| `lib/presentation/main/main_screen_test_keys.dart` | Modify | Add a stable key for the feedback button. |
| `deploy_debug.sh` | Modify | Pass optional debug Wiredash defines when supplied and validate paired configuration without exposing the secret. |
| `deploy_release.sh` | Modify | Read required Wiredash values from the current ignored `android/local.properties`, pass transient build defines, and preserve the existing proxy-secret deployment mechanism. |
| `test/core/config/app_config_test.dart` | Modify | Cover Wiredash define parsing and missing/partial configuration behavior. |
| `test/presentation/feedback/feedback_metadata_test.dart` | Create | Verify the exact metadata allowlist, trimmed contact transport, unsupported-platform fallback, and exclusion of sensitive fields. |
| `test/presentation/feedback/feedback_preparation_sheet_test.dart` | Create | Verify category selection, privacy copy, unrestricted contact input, shared dialog presentation, cancel, and continue behavior. |
| `test/presentation/feedback/feedback_service_test.dart` | Create | Verify success, cancellation, unavailable configuration, sanitized failure, and retry-state behavior through a fake Wiredash launcher. |
| `test/presentation/main/main_screen_test.dart` | Modify | Verify one feedback button exists, launches the feedback service, and does not alter recording controls. |
| `test/app_smoke_test.dart` | Modify | Verify missing local Wiredash credentials do not block bootstrap or normal app rendering. |
| `test/deploy_debug_script_test.sh` | Modify | Cover optional Wiredash define forwarding and partial-config rejection without logging secrets. |
| `test/deploy_release_script_test.sh` | Modify | Cover required private Wiredash configuration, transient build arguments, and secret exclusion from synchronized local properties. |
| `integration_test/main_feedback_flow_test.dart` | Create | Cover the complete main-screen feedback flow with a fake submission boundary: open, classify, enter arbitrary contact, read privacy copy, submit, cancel, and retry after failure. |
| `integration_test/app_lock_flow_test.dart` | Modify | Verify the app lock remains above a feedback surface after a foreground exit when Wiredash is mounted. |

No Wrait database, entry model, router route, backend OpenAPI contract, native
Android channel, or iOS native source change is planned.

## API contract details

### External Wiredash contract

The app will call the public `Wiredash.of(context).show()` API. The flow will
use `WiredashFeedbackOptions` with the following effective configuration:

```text
labels: []
email: hidden
screenshot: hidden
collectMetaData: allowlisted callback
```

The exact enum names and constructor parameters must be compiled against the
resolved `2.6.1` package during implementation. The package documents the
email prompt as email-only and supports hidden/optional/mandatory modes; this
plan uses hidden because the Wrait field is deliberately not an email field.

### Internal feedback service contract

```text
open(context, appArea) -> FeedbackLaunchResult
```

The result distinguishes `submitted`, `cancelled`, `unavailable`, and
`failed`. The service owns the current preparation draft until the Wiredash
flow succeeds or the user cancels. User-facing failures are fixed sanitized
copy; implementation errors are logged only through the existing developer
logging convention and are never displayed or attached to feedback.

Wiredash's own offline/pending behavior must be verified during implementation.
The adapter must not clear or recreate the native message form after a
transient submission error, because that could discard typed feedback.

## Data model changes

No persisted Wrait data model changes are required.

### Before

```text
No feedback model or local feedback storage.
```

### After

```text
An in-memory feedback preparation draft only:
- category: Bug | Idea | Confusing | Praise
- replyContact: optional arbitrary text
```

The draft is not journal data and is not written to the encrypted entry
database. Wiredash may persist its own pending feedback according to the SDK's
offline behavior; Wrait must not copy that data into local journal storage.

### Migration

None.

## Test strategy

### Automated tests

Every in-scope user flow is covered through the integration test below. Unit
and widget tests isolate privacy policy, form behavior, configuration, and
failure handling so the external Wiredash service is not contacted by normal
CI tests.

| Test case | Type | File |
| --- | --- | --- |
| Wiredash build-define parsing and missing/partial configuration | Unit | `test/core/config/app_config_test.dart` |
| Safe metadata allowlist and arbitrary plain-text contact | Unit | `test/presentation/feedback/feedback_metadata_test.dart` |
| Preparation sheet categories, privacy copy, no contact validation, cancel, continue, shared dialog route, and keyboard anchoring | Widget | `test/presentation/feedback/feedback_preparation_sheet_test.dart`, `test/presentation/feedback/feedback_service_test.dart` |
| Service success, cancel, sanitized failure, retry preservation, missing controller, and concurrent-call coalescing | Unit | `test/presentation/feedback/feedback_service_test.dart` |
| Main screen has one feedback button, accessibility semantics, rapid-tap protection, and unchanged recording state | Widget | `test/presentation/main/main_screen_test.dart` |
| App remains usable without Wiredash credentials | Widget | `test/app_smoke_test.dart` |
| Debug/release deployment configuration and secret handling | Shell | `test/deploy_debug_script_test.sh`, `test/deploy_release_script_test.sh` |
| Main-screen feedback flow: open, select category, enter arbitrary contact, see privacy copy, submit, cancel, and retry | Integration | `integration_test/main_feedback_flow_test.dart` |
| App lock covers feedback UI after foreground exit | Integration | `integration_test/app_lock_flow_test.dart` |

The integration harness will override the feedback submission boundary with a
deterministic fake. A separate manual runtime check with a Wiredash staging
project will exercise the real SDK UI and console delivery without putting
external network state into automated CI.

The feedback copy is intentionally hardcoded for this first version. If the
application localizes user-facing feedback copy later, the privacy warning,
button labels, and sanitized status messages must move with the same
localization change.

### Android emulator verification

1. Create or select a non-production Wiredash environment and provide its
   project ID, secret, and environment through `--dart-define` values.
2. Run `flutter pub get`, `flutter analyze`, the focused unit/widget tests,
   and `integration_test/main_feedback_flow_test.dart` on the Android
   emulator.
3. Launch the app cold with the normal Flutter path and verify the main screen
   has exactly one top-right feedback icon button and the recording button
   behaves unchanged.
4. Tap feedback, select each category across separate synthetic submissions,
   enter a non-email contact such as `Signal: wrait-test`, verify no validation
   error appears, and confirm the privacy copy is visible.
5. Enter synthetic feedback, verify the Wiredash feedback flow has no email or
   screenshot step, submit it, and verify success confirmation plus the
   corresponding safe metadata in the Wiredash console.
6. Verify the console item does not contain entry text, transcript, audio path,
   audio data, entry identifier, export filename, screenshot, proxy secret, or
   diagnostic log.
7. Exercise a failed/unavailable submission with synthetic content and verify
   the form remains usable, the error is sanitized, retry is possible, and the
   typed message is not cleared by the adapter.
8. Enable app lock, open feedback, background/resume the app, and verify the
   lock surface covers the feedback UI until unlock.

Expected evidence: focused test output, emulator screenshot showing the
top-right feedback icon and preparation sheet, a sanitized failure/retry
result, and a console inspection or captured request fixture proving the
metadata allowlist.

### iOS simulator verification

1. Provide the same non-production Wiredash project configuration through
   `--dart-define` values for the iOS simulator build.
2. Run `flutter pub get`, `flutter analyze`, the focused unit/widget tests,
   and `integration_test/main_feedback_flow_test.dart` on the iOS simulator.
3. Verify the cold launch, single top-right main-screen feedback icon,
   unchanged recording control, category selection, privacy copy, and
   arbitrary plain-text contact behavior.
4. Submit synthetic feedback through the real Wiredash flow and verify the
   absence of email validation, screenshot collection, and sensitive Wrait
   metadata in the console.
5. Verify sanitized failure/retry behavior and that cancellation returns to the
   main screen without submission.
6. Verify app lock coverage when the feedback surface is open and the app
   leaves and re-enters the foreground.

Expected evidence: focused test output, simulator screenshots of the main
screen and preparation sheet, real Wiredash staging feedback or request
inspection, and app-lock coverage evidence.

### Validation exception request

No exception requested. Android emulator and iOS simulator verification remain
required.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- The review should pay particular attention to the Wiredash root placement,
  email/screenshot suppression, metadata allowlisting, contact-text handling,
  error preservation, deployment secret handling, and app-lock coverage.
- This feature is likely to require a proposed durable update to
  `docs/application-description.md` and/or `docs/agent-findings.md` because it
  introduces an external feedback service, build-time credentials, and a
  privacy-specific integration boundary. Those updates will be proposed only
  after implementation and review, then edited only with explicit approval.

## Integration notes

- Wiredash is an external service; feedback content and explicitly supplied
  contact text leave the device.
- The app must not send feedback through the existing Wrait backend or reuse
  `PROXY_SECRET` for Wiredash.
- The app must not call Wiredash analytics APIs. A feedback submission is not a
  product analytics event.
- Wiredash's [custom metadata object](https://pub.dev/documentation/wiredash/latest/wiredash/CustomizableWiredashMetaData-class.html)
  supports arbitrary custom values, but only the allowlisted keys in this plan
  may be populated.
- The Wiredash SDK exposes a [Confidential widget](https://pub.dev/documentation/wiredash/latest/wiredash/Confidential-class.html),
  but this story disables screenshot capture entirely and does not add a new
  capture-privacy layer. Existing Android `FLAG_SECURE` and iOS scene privacy
  behavior remain unchanged.
- Wiredash is pinned to `2.6.1` for this implementation. Dependency refreshes
  must re-run `flutter pub get`, root `flutter analyze`, and the Android/iOS
  build or integration checks before changing the version, because
  feedback-option names and Android build constraints have changed across
  major/minor releases. The current SDK does not expose public typed API
  exceptions, so the adapter must preserve its sanitized generic catch unless
  a future version provides a stable public exception contract.

## Rollout & migration

1. Add the dependency and code behind the existing app build.
2. Configure a non-production Wiredash environment for development and mobile
   validation.
3. Validate the real flow on Android emulator and iOS simulator.
4. Configure production project ID, secret, and environment only in ignored
   release configuration or CI secret storage.
5. Ship the button with configuration presence as the rollout gate. A missing
   configuration must degrade to a sanitized unavailable message, not a
   startup failure.

No local migration, backend migration, feature flag, or data backfill is
required.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Wiredash's built-in email step rejects the approved arbitrary contact text | High | High | Collect contact text in the Wrait preparation sheet and set Wiredash email prompt to hidden. Add a no-validation test with a non-email value. |
| Wiredash screenshot capture exposes private app content | Medium | High | Set screenshot prompt to hidden, do not expose an attachment control, inspect the real flow on both platforms, and retain existing native capture protections. |
| Wiredash is mounted above the app lock and remains visible after relock | Medium | High | Mount it below `AppLockGate`, test foreground-exit behavior, and treat any overlay placement failure as a blocker. |
| SDK metadata includes more device information than intended | Medium | High | Start from clean metadata, populate only the allowlist, inspect the staging console/request payload, and never set user/device identifiers. |
| Wiredash submission failure clears the native message draft | Medium | High | Use the SDK's offline/pending path, do not rebuild or dismiss the native flow on failure, and validate network failure with synthetic text. |
| Missing or incorrectly supplied build defines make feedback unusable | Medium | Medium | Keep startup non-blocking but make release deployment require paired values; add deploy-script tests and a sanitized runtime fallback. |
| Wiredash dependency changes Android build constraints | Medium | Medium | Verify current AGP/Gradle/Kotlin compatibility before implementation and run generated backend package checks plus Flutter analyze after dependency resolution. |
| External Wiredash outage blocks user feedback | Medium | Medium | Keep the app fully usable without the service, preserve retry/offline behavior, and show a sanitized retry message. |
| Adding the button changes the carefully measured main-screen layout | Medium | Medium | Use a stable top safe-area slot, a compact icon control, existing design tokens, and desktop/mobile layout tests. |

## Open items from spec

None. The approved spec has no unresolved functional questions.
