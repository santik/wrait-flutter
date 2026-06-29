# Implementation Notes: Recording, Sharing, and Navigation Polish

> **Feature number:** 035
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-25

---

## Summary

This implementation shipped the three approved user-facing changes:

- The active recording pulse now expands from the button to the safe-area
  viewport bounds and slightly beyond without disturbing the action button or
  countdown layout.
- Shared entry text now includes the entry date and time using the app's
  existing localized timestamp style, followed by the shared body text.
- Android system back now matches the visible in-app back behavior on the
  entry list and entry detail surfaces.

After device feedback, the pulse rendering received one follow-up adjustment:
the pulse still starts at the button diameter and expands outward, but it now
uses a stronger initial stroke and glow so the beginning of the animation is
clearly visible on deployed devices.
The follow-up was refined again so the ring stroke is painted outward from the
button boundary instead of being centered on it, which keeps the extension
visibly outside the button from the first animation frame.
After external review, the implementation was remediated so pulse sizing uses
the actual button position, the share timestamp matches the entry-detail date
presentation more closely, and entry-list back behavior prefers a true route
pop before falling back to the main screen.

No API contract, data model, backend generation, app-lock, or capture-privacy
behavior was changed.

## Implementation details

### Recording pulse

- `MainScreen` now computes a viewport-scale pulse diameter from the current
  safe-area layout bounds.
- `ButtonArea` accepts that pulse diameter, keeps its own layout sized around
  the button/countdown ring, and lets the pulse overflow visually behind the
  controls.
- `PulseRing` now animates between a start diameter and an end diameter rather
  than scaling a fixed-size circle.
- The pulse ring now starts with a thicker stroke and visible glow, then tapers
  as it expands, so the ring remains readable at the button edge before it
  grows to the viewport bounds.
- The pulse ring is now painted with a custom outward stroke, so the visible
  ring sits around the button instead of hiding half its thickness underneath
  the button surface.
- Review remediation changed the sizing input from a generic viewport
  calculation to a measured button-center-to-corner calculation, with a
  temporary max-dimension fallback until the first layout measurement is
  available.
- `ButtonArea` now validates incoming pulse diameters and falls back or clamps
  invalid values instead of trusting every caller input.

### Share payload

- `entry_detail_formatters.dart` now exposes
  `formatEntryDetailShareTimestamp(...)`, which formats share timestamps with
  the same localized full weekday and long-date style used on the entry-detail
  screen, plus localized time.
- `EntryDetailController.shareDisplayedText(...)` now composes the final share
  payload as `timestamp + blank line + body`.
- `EntryDetailScreen` passes the current entry timestamp plus the currently
  displayed text, including edited text still in the editor.
- The share payload separator is now a named constant so future share-format
  changes do not require hunting for duplicated string literals.

### Android back behavior

- `EntryDetailScreen` already routed system back through the same flush-and-go
  path as the visible back button; that behavior was preserved and covered by
  new tests.
- `EntryListScreen` now uses `PopScope` so Android system back matches the
  visible list back button and returns to the main screen.
- Review remediation changed the entry-list back path so it pops the current
  route when stack history exists, and only falls back to `/` when there is no
  prior route to pop. Widget coverage now also verifies that system back
  dismisses the delete confirmation dialog before leaving the list.

Implementation finding:

- Because the app navigates with `context.go(...)`, visible back buttons were
  not evidence that the router history itself would make Android system back do
  the same thing. The entry list needed explicit `PopScope` handling to satisfy
  the approved back-button behavior.
- The final pulse-sizing behavior needed the measured button position rather
  than only viewport dimensions because the main action button is not always at
  the geometric center of the safe-area viewport.

## Files changed

- `lib/presentation/main/main_screen.dart`
- `lib/presentation/main/button_area.dart`
- `lib/presentation/main/pulse_ring.dart`
- `lib/presentation/theme/design_tokens.dart`
- `lib/presentation/entries/entry_detail_formatters.dart`
- `lib/presentation/entries/entry_detail_controller.dart`
- `lib/presentation/entries/entry_detail_screen.dart`
- `lib/presentation/entries/entry_list_screen.dart`
- `test/presentation/main/button_area_test.dart`
- `test/presentation/entries/entry_detail_formatters_test.dart`
- `test/presentation/entries/entry_detail_controller_test.dart`
- `test/presentation/entries/entry_detail_screen_test.dart`
- `test/presentation/entries/entry_list_screen_test.dart`
- `integration_test/main_screen_flow_test.dart`
- `integration_test/entry_detail_flow_test.dart`
- `integration_test/entry_list_flow_test.dart`

## Validation

### Host

- `dart format` on all touched Dart files -> passed
- `/opt/homebrew/bin/flutter analyze` -> passed
- `/opt/homebrew/bin/flutter test --no-pub test/presentation/main/button_area_test.dart test/presentation/entries/entry_detail_formatters_test.dart test/presentation/entries/entry_detail_controller_test.dart test/presentation/entries/entry_detail_screen_test.dart test/presentation/entries/entry_list_screen_test.dart`
  -> passed
- `/opt/homebrew/bin/flutter test --no-pub test/presentation/main test/presentation/entries`
  -> passed

### iOS simulator

- Device: `iPhone 17` simulator
- Command:
  `/opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart integration_test/entry_detail_flow_test.dart integration_test/entry_list_flow_test.dart`
  -> passed

Validated in that run:

- Pulse grows beyond the viewport while controls remain usable
- Share payload contains localized date/time plus short, long, raw-draft, and
  edited text
- System back returns from detail to list and from list to main
- Existing delete, edit, and fallback entry flows remain green

### Android emulator

- Emulator: `Pixel_8_emulator` (`emulator-5554`)
- Boot command:
  `/Users/alexander/Library/Android/sdk/emulator/emulator @Pixel_8_emulator -no-snapshot-save`
- Command:
  `/opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/main_screen_flow_test.dart integration_test/entry_detail_flow_test.dart integration_test/entry_list_flow_test.dart`
  -> passed

Validated in that run:

- Pulse grows beyond the viewport while controls remain usable
- Share payload contains localized date/time plus short, long, raw-draft, and
  edited text
- Android system back returns from detail to list and from list to main
- Existing delete, edit, and fallback entry flows remain green

### Environment notes

- A no-target integration invocation,
  `/opt/homebrew/bin/flutter test --no-pub integration_test/...`, required an
  explicit `-d` device selection in this multi-device environment, so the
  focused integration validation was performed on explicit simulator/emulator
  targets instead.
- Android runs emitted a non-blocking Flutter warning that
  `package_info_plus`, `share_plus`, `speech_to_text`, and `wakelock_plus`
  still apply the Kotlin Gradle Plugin path and will require future
  maintenance. This story did not change those plugins.

### Post-feedback validation

After deployed-device feedback that the pulse was not perceptible enough, the
follow-up pulse visibility fix was validated with:

- `/opt/homebrew/bin/flutter analyze` -> passed
- `/opt/homebrew/bin/flutter test --no-pub test/presentation/main/button_area_test.dart`
  -> passed
- `/opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart`
  -> passed

After the second feedback round that the pulse was visible but not clearly
extending around the button, the outward-stroke refinement was validated with:

- `/opt/homebrew/bin/flutter analyze` -> passed
- `/opt/homebrew/bin/flutter test --no-pub test/presentation/main/button_area_test.dart`
  -> passed
- `/opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart`
  -> passed

### Review remediation validation

- `dart format` on remediated Dart files -> passed
- `/opt/homebrew/bin/flutter analyze` -> passed
- `/opt/homebrew/bin/flutter test --no-pub test/presentation/main/button_area_test.dart test/presentation/entries/entry_detail_formatters_test.dart test/presentation/entries/entry_detail_controller_test.dart test/presentation/entries/entry_list_screen_test.dart test/presentation/entries/entry_detail_screen_test.dart`
  -> passed
- `/opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart`
  -> passed
- `/opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/entry_detail_flow_test.dart integration_test/entry_list_flow_test.dart`
  -> passed
- `/opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/main_screen_flow_test.dart`
  -> passed
- `/opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/entry_detail_flow_test.dart integration_test/entry_list_flow_test.dart`
  -> passed

Residual validation note:

- The combined iOS simulator command that runs `main_screen_flow_test.dart`,
  `entry_detail_flow_test.dart`, and `entry_list_flow_test.dart` together was
  retried after remediation and intermittently failed only
  `main_screen_flow_test.dart: listening pulse grows beyond the viewport while
  controls stay visible`, while the isolated `main_screen_flow_test.dart` run
  and the shared `entry_detail` + `entry_list` run both passed. That was
  recorded as a simulator combined-run flake rather than evidence of an app
  regression.
