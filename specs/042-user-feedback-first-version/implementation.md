# Implementation Record: User Feedback First Version

> **Feature number:** 042
> **Date:** 2026-08-11
> **Branch:** `codex/feat/user-feedback-first-version-#US-042`

## Delivered

Wrait now has one top-right `Send feedback` icon on the main screen. The flow
is:

1. The user chooses `Bug`, `Idea`, `Confusing`, or `Praise`.
2. The user may enter unrestricted plain-text reply contact information.
3. Wrait displays the privacy warning before opening Wiredash.
4. Wiredash collects the free-text message and submits it.
5. Wrait shows a concise success, unavailable, or retry message.

The preparation form is a top-anchored panel with scrollable content. Opening
the keyboard does not move the panel; only its available content area changes.
The preparation draft is held in memory only. It is retained after a launch or
submission failure so the user can retry, and is discarded on cancellation or
successful submission. Concurrent service calls are coalesced, and the main
screen also disables the entry point while a request is active.

## Wiredash Setup

Create a non-production Wiredash project in the Wiredash Console and keep its
project ID and SDK secret in local environment variables or approved CI secret
storage. Do not commit them to Dart source, tracked property files, tests,
screenshots, or logs.

The app accepts these build defines:

```text
WIREDASH_PROJECT_ID
WIREDASH_SECRET
WIREDASH_ENVIRONMENT
```

Manual development launch:

```sh
flutter run -d <device> \
  --dart-define=WIREDASH_PROJECT_ID=<project-id> \
  --dart-define=WIREDASH_SECRET=<sdk-secret> \
  --dart-define=WIREDASH_ENVIRONMENT=staging
```

Debug deployment accepts the same values as environment variables. Project ID,
secret, and environment must be supplied together when any is supplied:

```sh
PROXY_SECRET=<wrait-proxy-secret> \
WIREDASH_PROJECT_ID=<project-id> \
WIREDASH_SECRET=<sdk-secret> \
WIREDASH_ENVIRONMENT=staging \
./deploy_debug.sh
```

Release deployment requires the three Wiredash properties in the ignored
current `android/local.properties` file:

```properties
WIREDASH_PROJECT_ID=<project-id>
WIREDASH_SECRET=<sdk-secret>
WIREDASH_ENVIRONMENT=production
```

The release script forwards all three as transient `--dart-define` values from
the current local properties file. The file is private and ignored, while
release signing passwords remain transient environment values.

A build without Wiredash credentials remains launchable. The feedback button
then returns a sanitized unavailable message instead of blocking startup.

## Privacy Boundary

The Wiredash adapter uses `EmailPrompt.hidden`, `ScreenshotPrompt.hidden`, and
an empty label list. It forwards only this custom metadata allowlist:

```text
app_area
platform
locale
feedback_category
reply_contact (only when non-blank after trimming)
```

The reply contact value remains unrestricted plain text and is not email
validated. Leading and trailing whitespace is trimmed only when building
transport metadata; blank-after-trimming values are omitted. No user ID,
device ID, route path, journal entry ID or text,
transcript, audio path or bytes, export name, backend URL, proxy secret,
screenshot, analytics event, or raw diagnostic data is attached.

`Wiredash` is mounted below `AppLockGate` in the existing app-shell builder,
so a foreground exit keeps an open feedback surface covered by the privacy
lock. Wiredash does not participate in startup or bootstrap work.

## Validation Evidence

Passed:

- `flutter pub get`
- `flutter analyze` in the root project: no issues
- Targeted Dart formatting with `--set-exit-if-changed`
- `bash -n` for both deploy scripts and both deploy-script test files
- `test/deploy_debug_script_test.sh`
- `test/deploy_release_script_test.sh`
- Focused Flutter suite after review remediation: 36 tests passed, including
  metadata, preparation sheet, service, keyboard anchoring, main screen, and
  rapid-tap coverage
- Android connected Pixel 8 feedback flow after review remediation: 2 tests
  passed
- Android connected Pixel 8 main-screen flow after review remediation: 9 tests
  passed
- Earlier Android emulator feedback flow: 2 tests passed
- Earlier Android emulator app-lock flow: 7 tests passed
- iOS simulator feedback flow after review remediation: 2 tests passed
- Earlier iOS simulator app-lock flow: 7 tests passed

The generated backend package ran `flutter pub get` successfully. Its
`flutter analyze` command reports seven existing generated-client unused or
duplicate import warnings in `lib/lib/api/default_api.dart`; no generated
backend output was changed by this feature.

## Review Remediation

The external review identified privacy, concurrency, validation, test fidelity,
and documentation gaps. The approved fixes are complete:

- Wiredash custom metadata is replaced with a fresh allowlist map, so existing
  SDK custom fields cannot be forwarded accidentally.
- The controller returned by `Wiredash.maybeOf(context)` is checked once and
  reused for the launch.
- Concurrent `open` calls share one future; rapid main-screen taps therefore
  cannot create duplicate preparation dialogs or race the in-memory retry
  draft.
- Reply contact is trimmed only at metadata transport time.
- Debug and release deployment scripts validate project ID, secret, and
  environment format before building, without printing the secret.
- Production and widget tests use the same top-anchored
  `showGeneralDialog` helper. Keyboard-anchor, cancellation-reset, missing
  controller, rapid-tap, and deterministic snackbar-dismissal coverage was
  added.
- The preparation panel's bounds are calculated without keyboard view insets
  and its layout context removes those insets. Its top-anchored layout uses a
  fixed 4px bottom spacing without an unnecessary bottom safe-area inset, and
  its measured initial height is then held as an exact height, so the panel
  keeps the same height and action-to-bottom gap while the keyboard is visible.
- Android uses activity soft-input mode `adjustNothing`, preventing the native
  keyboard from resizing the Flutter window and clipping the fixed top panel.
  Flutter still receives keyboard insets for normal scaffold and scroll
  behavior.
- A fixed success message is written to `developer.log`; user content and
  diagnostics remain excluded from user-facing output and feedback metadata.

Wiredash `2.6.1` does not export its internal API-specific exception classes
through the public `wiredash.dart` API. The adapter therefore keeps a generic
catch boundary with fixed user-facing copy and developer-only diagnostics.
The feedback privacy and status copy remains hardcoded for this first version;
localization is a follow-up if this surface is added to the app's localization
catalog.

The dependency remains pinned to Wiredash `2.6.1`. Future upgrades require
`flutter pub get`, root `flutter analyze`, and Android/iOS build or integration
checks to be rerun because the SDK's feedback options and Android build
requirements have changed across releases.

Live Wiredash UI, console delivery, and request-payload inspection remain
pending. The supplied credentials are stored in the ignored current
`android/local.properties` file, but the credentialed build permission request
was rejected before execution; release validation also requires transient
signing-password environment values. The deterministic tests use a fake
submission boundary and cover the same user flow without network submission.
The production adapter is compiled against Wiredash `2.6.1` and has direct
tests for unavailable configuration, missing controller, cancellation,
failure, retry preservation, concurrent calls, and metadata replacement.

## Review Gate

The external `review.md` was read, the remediation plan was approved, and the
approved fixes are implemented. The second-pass update was reviewed after the
keyboard/layout changes; it identified no new actionable findings, so no
additional code remediation was required. The remaining accepted items are
documented SDK or first-version scope limitations. `review.md` remains
externally authored and was not modified by this implementation.

## Finalization

The approved durable documentation updates were applied to `AGENTS.md`,
`docs/application-description.md`, and `docs/agent-findings.md`. They record
the Wiredash privacy boundary, build-time credential handling, app-lock
placement, fixed keyboard-safe feedback layout, Android soft-input mode, and
the required validation constraints for future changes.
