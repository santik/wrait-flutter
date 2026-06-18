# Implementation: Entry Detail Screen

> **Feature number:** 014
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-16

## Summary

US-014 replaces the `/entry/:id` placeholder with a real repository-backed
entry detail experience. The new screen reads one entry reactively, redirects
invalid or unreadable entries back to `/entries`, shows localized metadata,
supports selectable reading, editable multiline text with auto-save,
platform-share delegation, and shared deletion behavior that matches the
entries list.

## Implemented behavior

- Added repository and DAO support for editing only `cleanedText` and
  recalculating `wordCount` without mutating `rawTranscript`.
- Extracted shared delete confirmation and delete-controller logic so entry
  detail and entry list use the same wording, semantics, and failure handling.
- Added an injectable share service around `share_plus`.
- Added detail-specific formatters for readable text selection, localized date
  labels, unreadable-entry detection, and word-count presentation.
- Added `EntryDetailController` for reactive entry watching, edit state,
  debounced auto-save, flush-on-exit, share delegation, and delete delegation.
- Added `EntryDetailScreen` with:
  - back, edit/done, share, and delete actions
  - localized weekday/date metadata and stored word count
  - selectable read mode and multiline edit mode
  - automatic save feedback and generic failure feedback
  - redirect handling for missing, deleted, invalid, and unreadable entries
- Updated router, main-screen navigation tests, and entry-list navigation tests
  so `/entry/:id` lands on the real detail UI.
- Added new widget, controller, formatter, repository, and integration coverage
  for the approved detail flows.

## Notable implementation notes

- `PopScope` replaced `WillPopScope` so the detail screen uses the current
  Flutter back-navigation API.
- The detail screen defers state synchronization with a post-frame callback to
  avoid mutating Riverpod state during build.
- Auto-save now uses a revision-based single-flight save sequence. That keeps
  persistence finite, avoids stale completion races, and still flushes the
  latest edit on back navigation without a manual Save action.
- Programmatic editor updates now suspend the text-controller listener during
  controller writes instead of relying on a mutable syncing flag.
- Router ID parsing is shared between redirect and builder paths, with a safe
  builder fallback if parsing ever fails unexpectedly.
- The multiline editor exposes an explicit accessibility label.
- The share integration-test seam did not require a `lib/main.dart` change.
  Existing provider overrides already allowed the test harness to inject a fake
  share service directly.

## Validation

- `dart run build_runner build --delete-conflicting-outputs`
- `dart format` on changed US-014 Dart files
- `flutter analyze`
- `npm run build`
- `flutter test`
- Focused Flutter test pass for detail formatter/controller/screen and entry
  repository behavior
- Android emulator:
  - `flutter test integration_test/entry_detail_flow_test.dart -d emulator-5554`
  - `flutter test integration_test/entry_list_flow_test.dart integration_test/main_screen_flow_test.dart -d emulator-5554`
- Connected Android device:
  - `flutter test integration_test/entry_detail_device_smoke_test.dart -d 4A181FDJH0030G`
- iOS simulator:
  - `flutter test integration_test/entry_detail_flow_test.dart integration_test/entry_list_flow_test.dart integration_test/main_screen_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`

All validation above passed.

## Screenshot checkpoints

- Detail checkpoints: `entry-detail-readable`,
  `entry-detail-long-after-scroll`, `entry-detail-invalid-redirect`,
  `entry-detail-missing-redirect`, `entry-detail-unreadable-redirect`,
  `entry-detail-edit-mode`, `entry-detail-edited-back-to-list`,
  `entry-detail-delete-confirmation`, `entry-detail-after-delete`
- Existing list/main checkpoints remained exercised through the updated
  integration files on both Android and iOS.

## Review remediation

The approved `review.md` pass resulted in these concrete changes:

- replaced the original mutable drain-loop auto-save sequencing with a
  revision-based single-flight save pipeline
- added controller coverage for an in-flight save followed by a newer revision
- shared route-ID parsing between router redirect and builder code
- replaced the detail-screen text sync guard with listener suspension during
  programmatic controller updates
- added explicit accessibility coverage for the editable text field
- added a screenshot-free connected-device smoke test for the remediated detail
  flow
