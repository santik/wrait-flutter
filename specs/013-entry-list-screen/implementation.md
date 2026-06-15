# Implementation Record: Entry List Screen

> **Feature number:** 013
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-15

---

## Outcome

US-013 is implemented, and the approved review remediation has been applied.
The `/entries` route now renders a real entry-list screen backed by the local
entry repository, includes draft entries, sorts newest first, shows localized
timestamp and language metadata per row, opens entry detail on tap, and
supports right-swipe delete with immediate confirmation.

## Delivered behavior

- Replaced the `/entries` placeholder route with `EntryListScreen`.
- Added entry-list state/controller wiring around
  `entryRepositoryProvider.watchAllEntries()`.
- Included draft entries in the list and marked them with a visible `draft`
  chip.
- Rendered a localized short weekday/date/time label for each row.
- Kept the language label always visible for every row.
- Derived the row preview from cleaned text first, then raw transcript.
- Added the Android-matching audio-draft fallback preview
  `pending · will retry`.
- Prevented audio-only draft rows from opening entry detail while keeping them
  visible and deletable from the list.
- Added an anchored right-swipe reveal with an 80dp red delete affordance and
  trash icon.
- Triggered haptic feedback when the reveal reaches the delete anchor.
- Opened the delete confirmation dialog immediately after the row becomes fully
  revealed.
- Exposed a dedicated semantics delete action so assistive technologies can
  trigger the delete confirmation without performing the swipe gesture.
- Kept the user on `/entries` after confirmed deletion and relied on the
  reactive stream update to remove the row.
- Closed the reveal again on both Cancel and Delete outcomes.
- Kept deletion failure non-destructive by catching the repository error and
  leaving the row visible.
- Added structured controller logging for delete failures so unsuccessful
  deletions remain diagnosable without changing the visible list state.
- Added a safe timestamp-format fallback path so unsupported locale formatting
  inputs still produce weekday/date/time labels.
- Guarded each row's reveal-confirmation flow against repeated triggers while a
  delete flow is already active.
- Added explicit semantics labels and hints to the dialog's Cancel and Delete
  actions.

## Files changed

### App and routing

- `pubspec.yaml`
- `pubspec.lock`
- `lib/app.dart`
- `lib/core/router/app_router.dart`

### Entry-list implementation

- `lib/presentation/entries/entry_list_controller.dart`
- `lib/presentation/entries/entry_list_formatters.dart`
- `lib/presentation/entries/entry_list_row.dart`
- `lib/presentation/entries/entry_list_screen.dart`

### Automated coverage

- `test/presentation/entries/entry_list_formatters_test.dart`
- `test/presentation/entries/entry_list_controller_test.dart`
- `test/presentation/entries/entry_list_row_test.dart`
- `test/presentation/entries/entry_list_screen_test.dart`
- `test/core/router/app_router_test.dart`
- `test/presentation/main/main_screen_test.dart`
- `integration_test/entry_list_flow_test.dart`
- `integration_test/main_screen_flow_test.dart`

## Implementation notes

- Flutter localization delegates were added alongside a direct `intl`
  dependency so row timestamps respect the current locale.
- `supportedLocales` is built from both the current device locales and the
  app's supported language set, with `en-US` as a final fallback.
- The delete flow is modeled as a row-level reveal interaction that awaits the
  screen's delete callback and then animates closed in a `finally` block.
- The controller now owns the reusable newest-first sort helper so entry-list
  ordering stays with the presentation state that applies it.
- Audio-only drafts are detected from `audioPath` plus the absence of cleaned
  or raw text, then rendered with a retry preview and disabled tap navigation.
- Screen-level swipe-dialog widget coverage was intentionally moved down to the
  row widget harness plus device integration coverage because direct gesture
  testing through the `ListView` layer was brittle and lower signal than
  testing the reusable row interaction directly.

## Review remediation

The approved `review.md` remediation changed implementation details in four
places without changing feature scope:

- delete failures are now logged from `EntryListController` while the row stays
  visible
- timestamp formatting now retries with language-code and default-locale
  fallbacks
- row reveal/delete handling now reuses a single in-flight flow until the
  dialog outcome resets the row
- dialog Cancel/Delete actions now expose explicit destructive semantics labels
  and hints

## Validation evidence

### Formatting and static analysis

- `dart format` run on all changed Dart files completed successfully.
- `flutter analyze` completed successfully.
- `flutter test` completed successfully.
- After the approved review fixes, targeted widget/provider tests reran
  successfully:
  `flutter test test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_formatters_test.dart test/presentation/entries/entry_list_row_test.dart test/presentation/entries/entry_list_screen_test.dart`
- After the approved review fixes, `flutter analyze` completed successfully
  again.
- After the approved review fixes, `flutter test` completed successfully again.

### Android device verification

- Command:
  `/opt/homebrew/bin/flutter test integration_test/main_screen_flow_test.dart integration_test/entry_list_flow_test.dart -d emulator-5554`
- Target:
  `emulator-5554` (`sdk gphone16k arm64`)
- Result:
  all tests passed on Android.
- Runtime screenshot checkpoints captured during the Android integration run:
  `entry-list-empty`, `entry-list-populated`, `entry-list-audio-draft`,
  `entry-list-delete-prompt-cancel`, `entry-list-delete-prompt-confirm`,
  `entry-list-audio-draft-delete-prompt`

### iOS simulator verification

- Command:
  `/opt/homebrew/bin/flutter test integration_test/main_screen_flow_test.dart integration_test/entry_list_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
- Target:
  `491CD949-D3C0-4C4C-A6B9-15BAB1859156` (`iPhone 17`)
- Result:
  all tests passed on iOS.
- Runtime screenshot checkpoints captured during the iOS integration run:
  `entry-list-empty`, `entry-list-populated`, `entry-list-audio-draft`,
  `entry-list-delete-prompt-cancel`, `entry-list-delete-prompt-confirm`,
  `entry-list-audio-draft-delete-prompt`

## Closeout

The approved review remediation is complete, Android and iOS validation passed,
and the approved long-lived documentation updates were applied to
`docs/application-description.md` and `docs/agent-findings.md`. No durable
`AGENTS.md` change was needed for US-013.
