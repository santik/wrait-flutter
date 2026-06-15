# Implementation Plan: Entry List Screen

> **Feature number:** 013
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-14

---

## Approach summary

Replace the `/entries` placeholder route with a real entry-list screen backed
by the existing local entry repository. The screen will watch all stored
entries, include drafts, sort newest first, render localized row weekday/date/time,
always show language display names, navigate to `/entry/:id` on row tap, and
support right-swipe deletion with an anchored 80dp reveal followed immediately
by a confirmation dialog. Deletion will call the existing repository delete
contract, keep the user on the list, remove the row through the reactive entry
stream after success, and leave the row visible if deletion fails.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Entry-list route | Replace the `/entries` `ShellPlaceholderScreen` with a new `EntryListScreen` | US-013 is the first real entry-list story. Keeping the existing route while swapping its builder preserves navigation from the main-screen stats line and router tests. |
| State source | Use `entryRepositoryProvider.watchAllEntries()` through an entry-list provider/controller | The repository already streams all local entries and includes drafts. Reusing it avoids duplicate persistence logic and lets deletes update the list reactively. |
| Sorting | Sort by `Entry.createdAt` descending in presentation state | The spec defines list order as display behavior. Sorting close to the screen keeps the repository contract unchanged and is easy to test. |
| Deletion | Call `EntryRepository.deleteEntry(id)` after dialog confirmation | The repository already owns entry and audio-file deletion. The UI should request deletion, not duplicate storage cleanup. |
| Delete failure handling | Catch delete failures in the list controller, log them, and leave the stream-driven row visible | The spec requires no false deletion state, and the approved review remediation adds structured logging so failures remain diagnosable without changing the UI state. |
| Swipe interaction | Implement a horizontal anchored row reveal with hidden and revealed positions at 0dp and 80dp | The spec requires anchored, not free-form, behavior. A small row widget with explicit anchors is clearer than overloading full-row dismissal behavior. |
| Reveal reentrancy | Ignore repeated reveal/delete triggers while a reveal-confirmation flow is already active | The approved review remediation requires a single in-flight delete flow per row so repeated gestures or semantics actions cannot open duplicate prompts or callbacks. |
| Confirmation timing | Open the confirmation dialog when the row settles at the revealed anchor | This matches the clarified flow: swipe right reveals red area, then the prompt appears immediately without a separate delete tap. |
| Cancel/Delete reset | Programmatically hide the revealed row after either dialog action | The spec requires the red area to disappear on Cancel and after Delete. Resetting from dialog outcomes keeps the behavior deterministic. |
| Row presentation helpers | Add pure helpers for preview text, audio-draft preview fallback, row short weekday/date/time labels, and language display | These rules are easy to unit test and keep widget code focused on layout and interaction. |
| Audio-only drafts | Treat draft rows with an `audioPath` but no transcript/cleaned text as non-openable cards labeled `pending · will retry` | This matches the Android reference behavior, keeps retryable drafts visible, and avoids routing users to a detail placeholder with no readable content. |
| Accessibility delete action | Expose a row-level custom semantics delete action in addition to swipe | Screen-reader users still need a direct destructive action even when the primary visual affordance is gesture-based. |
| Locale-aware formatting | Add Flutter localization delegates and use `intl` formatters for short weekday, date, and time labels | The app currently has no localization delegates. Adding SDK `flutter_localizations` plus a direct `intl` dependency gives deterministic locale-aware formatting for weekday, date, and time labels across supported device locales. |
| Language labels | Reuse `supportedLanguages` display names and fall back to the stored language code if unresolved | Existing canonicalization should keep stored values supported, but a fallback prevents crashes and keeps unknown data inspectable. |
| Draft display | Show a visible `draft` marker for entries where `isDraft` is true | The clarified spec requires drafts to appear and be marked. This uses existing domain state. |
| Empty state | Render centered `no entries yet` text when the watched entry list is empty | This directly satisfies the spec and replaces the placeholder route copy. |
| Back navigation | Add a top-left back control that returns to `/` | Screen-level swipe navigation is explicitly out of scope. A route-level back control satisfies the spec and works from direct `/entries` launches. |
| Entry detail navigation | On row tap, navigate to `/entry/<id>` | The detail route is still a placeholder, but the route exists and is the approved destination for opening a selected entry. |
| Accessibility | Expose row, back, delete, and dialog semantics with meaningful labels/actions, including explicit destructive dialog labels and hints | The spec requires accessible interactive regions. The approved review remediation strengthens dialog semantics so assistive technologies can distinguish destructive and cancel actions clearly. |
| Storage migration | None | The feature uses existing entry fields and delete behavior. |
| Validation exception | None requested | Every in-scope user flow can be covered by automated integration tests plus Android emulator and iOS simulator verification. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `pubspec.yaml` | Modify | Add SDK `flutter_localizations` and direct `intl` dependencies for locale-aware weekday/date/time formatting. |
| `lib/app.dart` | Modify | Register Flutter localization delegates and broadly supported Flutter locales used by the app. |
| `lib/core/router/app_router.dart` | Modify | Route `/entries` to `EntryListScreen` instead of `ShellPlaceholderScreen`; keep `/entry/:id` behavior. |
| `lib/presentation/entries/entry_list_screen.dart` | Create | Compose the entry-list screen, empty state, back control, list body, and delete confirmation dialog. |
| `lib/presentation/entries/entry_list_controller.dart` | Create | Watch entries, sort newest first, and expose delete handling that catches failures. |
| `lib/presentation/entries/entry_list_row.dart` | Create | Render one entry row with anchored right-swipe reveal, red delete background, haptic feedback, and row tap behavior. |
| `lib/presentation/entries/entry_list_formatters.dart` | Create | Pure helpers for row preview text, localized short weekday/date/time labels, and language display names. |
| `test/core/router/app_router_test.dart` | Modify | Update `/entries` route expectations from placeholder text to entry-list UI. |
| `test/presentation/main/main_screen_test.dart` | Modify | Update stats-tap navigation expectation from placeholder `Entries` text to the real entry-list screen. |
| `integration_test/main_screen_flow_test.dart` | Modify | Update stats navigation expectations to the real entry-list screen. |
| `test/presentation/entries/entry_list_formatters_test.dart` | Create | Unit coverage for preview fallback, draft/audio-draft preview behavior, language labels, and localized short weekday/date/time helper inputs. |
| `test/presentation/entries/entry_list_controller_test.dart` | Create | Unit/provider coverage for sorting, draft inclusion, and delete success/failure behavior. |
| `test/presentation/entries/entry_list_row_test.dart` | Create | Widget coverage for row layout, anchored swipe reveal, immediate dialog trigger callback, haptic trigger hook where practical, and tap behavior. |
| `test/presentation/entries/entry_list_screen_test.dart` | Create | Widget coverage for empty state, populated list, back button, row navigation, and accessibility labels. |
| `integration_test/entry_list_flow_test.dart` | Create | Device/simulator integration coverage for all in-scope entry-list user flows. |
| `specs/013-entry-list-screen/implementation.md` | Create later | Record implementation details and validation evidence during the implementation phase. |

## API contract details

No backend HTTP endpoint changes are planned.

The entry-list presentation contract will use these runtime inputs:

```text
Entry
  id: int
  rawTranscript: String
  cleanedText: String?
  isDraft: bool
  language: String
  createdAt: int
  wordCount: int
  audioPath: String?

EntryRepository
  watchAllEntries(): Stream<List<Entry>>
  deleteEntry(int id): Future<void>
```

UI actions:

- Stats tap on the main screen continues to navigate to `/entries`.
- The top-left back control navigates to `/`.
- Row tap navigates to `/entry/<entry.id>`.
- Row right-swipe settles at the 80dp reveal anchor, triggers haptic feedback,
  and opens the delete confirmation dialog.
- Dialog Cancel dismisses the dialog and resets the row reveal to hidden.
- Dialog Delete calls `deleteEntry(entry.id)`, dismisses the dialog, resets the
  row reveal to hidden, and keeps the current route at `/entries`.

Failure behavior:

- If the entry stream is empty, show `no entries yet`.
- If cleaned text is null or blank, use raw transcript for the preview.
- If the row is an audio-only draft with no readable text yet, use
  `pending · will retry` for the preview and do not navigate on tap.
- The row timestamp label includes short weekday, localized date, and
  localized time derived from `createdAt`.
- If the stored language does not resolve to a supported display name, show the
  stored language code.
- If deletion fails, catch the error, keep the user on `/entries`, and rely on
  the unchanged repository stream to keep the row visible.

## Data model changes

No persistent data-model or database migration is planned.

### Before

```text
Entry
  id
  rawTranscript
  cleanedText
  isDraft
  language
  createdAt
  wordCount
  audioPath
```

### After

```text
Entry
  unchanged
```

### Migration

No migration is required.

## Test strategy

Validation will combine pure unit tests, widget tests, provider-graph
integration tests, static analysis, and Android/iOS runtime verification. Every
in-scope user flow has planned `integration_test` coverage; no validation
exception is requested.

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Preview uses the first line of cleaned text when available | Unit | `test/presentation/entries/entry_list_formatters_test.dart` |
| Preview falls back to the first line of raw transcript when cleaned text is absent | Unit | `test/presentation/entries/entry_list_formatters_test.dart` |
| Audio-only draft preview remains deterministic if such stored drafts appear | Unit | `test/presentation/entries/entry_list_formatters_test.dart` |
| Audio-only draft rows render the retry preview and remain non-navigable on tap | Widget | `test/presentation/entries/entry_list_row_test.dart` and `test/presentation/entries/entry_list_screen_test.dart` |
| Language display uses supported display name and falls back to stored code for unknown values | Unit | `test/presentation/entries/entry_list_formatters_test.dart` |
| Localized row timestamp helper derives short weekday, date, and time labels from `createdAt` and current locale inputs | Unit | `test/presentation/entries/entry_list_formatters_test.dart` |
| Localized row timestamp helper falls back safely when locale-specific formatting cannot be resolved | Unit | `test/presentation/entries/entry_list_formatters_test.dart` |
| Controller/provider includes finalized and draft entries | Unit/provider | `test/presentation/entries/entry_list_controller_test.dart` |
| Controller/provider sorts entries by `createdAt` descending | Unit/provider | `test/presentation/entries/entry_list_controller_test.dart` |
| Controller/provider delete success calls `EntryRepository.deleteEntry(id)` | Unit/provider | `test/presentation/entries/entry_list_controller_test.dart` |
| Controller/provider delete failure is caught and does not remove the row optimistically | Unit/provider | `test/presentation/entries/entry_list_controller_test.dart` |
| Row displays short weekday/date/time, preview, language, and `draft` marker when applicable | Widget | `test/presentation/entries/entry_list_row_test.dart` |
| Row long preview remains single-line with ellipsis | Widget | `test/presentation/entries/entry_list_row_test.dart` |
| Row tap requests navigation to the selected entry id | Widget | `test/presentation/entries/entry_list_row_test.dart` |
| Row right-swipe reveals an 80dp red delete area with trash icon | Widget | `test/presentation/entries/entry_list_row_test.dart` |
| Row right-swipe settles only to hidden or revealed states | Widget | `test/presentation/entries/entry_list_row_test.dart` |
| Row fully revealed callback opens confirmation without a separate delete tap | Widget | `test/presentation/entries/entry_list_row_test.dart` |
| Haptic feedback fires when the row reaches the revealed state, where practical to observe in tests | Widget | `test/presentation/entries/entry_list_row_test.dart` |
| Row semantics expose a custom delete action for assistive technologies | Widget | `test/presentation/entries/entry_list_row_test.dart` and `test/presentation/entries/entry_list_screen_test.dart` |
| Repeated delete triggers while one reveal flow is active do not start duplicate delete flows | Widget | `test/presentation/entries/entry_list_row_test.dart` |
| Empty entry list shows centered `no entries yet` text | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Populated entry list hides empty state and renders all entries newest first | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Back control returns to the main screen | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Swipe reveal opens the confirmation dialog with approved title/body and actions | Widget | `test/presentation/entries/entry_list_row_test.dart` |
| Cancel dismisses the dialog, hides the red reveal state, and keeps the row | Widget | `test/presentation/entries/entry_list_row_test.dart` |
| Delete dismisses the dialog, hides the red reveal state, calls deletion, and removes the row after stream update | Widget | `test/presentation/entries/entry_list_row_test.dart` plus `integration_test/entry_list_flow_test.dart` |
| Delete failure leaves the row visible and shows no false deletion state | Unit/provider | `test/presentation/entries/entry_list_controller_test.dart` plus `integration_test/entry_list_flow_test.dart` |
| Entry-list semantics expose meaningful labels/actions for back, rows, delete, and dialog actions | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Delete dialog actions expose explicit destructive and cancel semantics labels/hints | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Router `/entries` renders the real entry-list screen | Widget | `test/core/router/app_router_test.dart` |
| Main stats tap navigates to the real entry-list screen | Widget | `test/presentation/main/main_screen_test.dart` |
| Main-screen integration stats flow lands on the real entry-list screen | Integration | `integration_test/main_screen_flow_test.dart` |
| Empty-state flow launches `/entries` and shows `no entries yet` | Integration | `integration_test/entry_list_flow_test.dart` |
| Populated-list flow shows finalized and draft entries newest first with always-visible language labels | Integration | `integration_test/entry_list_flow_test.dart` |
| Audio-only draft flow keeps the user on the list when the row is tapped and still allows swipe-delete | Integration | `integration_test/entry_list_flow_test.dart` |
| Row tap flow navigates from list to `/entry/<id>` | Integration | `integration_test/entry_list_flow_test.dart` |
| Swipe-to-delete Cancel flow reveals red area, opens dialog, cancels, hides red area, and keeps row | Integration | `integration_test/entry_list_flow_test.dart` |
| Swipe-to-delete Delete flow reveals red area, opens dialog, confirms, removes row, and stays on list | Integration | `integration_test/entry_list_flow_test.dart` |
| Back-control flow returns from `/entries` to the main screen | Integration | `integration_test/entry_list_flow_test.dart` |
| `flutter analyze` completes cleanly | Static analysis | Command evidence recorded in `tasks.md` |
| `flutter test` passes | Test suite | Command evidence recorded in `tasks.md` |

### Android emulator verification

1. Run `integration_test/entry_list_flow_test.dart` on an Android emulator.
2. Run the updated `integration_test/main_screen_flow_test.dart` on an Android
   emulator to confirm stats navigation still reaches the list.
3. Verify the Android run covers:
   - empty state
   - finalized and draft entries in newest-first order
   - always-visible language labels
   - row tap to entry detail
   - swipe-to-delete Cancel
   - swipe-to-delete Delete
   - top-left back control
4. Capture Android runtime screenshot checkpoints during the integration run
   for the empty state, populated list, and delete-prompt states.
5. Record emulator target and passing command evidence in `tasks.md`.

### iOS simulator verification

1. Run `integration_test/entry_list_flow_test.dart` on an iOS simulator.
2. Run the updated `integration_test/main_screen_flow_test.dart` on an iOS
   simulator to confirm stats navigation still reaches the list.
3. Verify the iOS run covers:
   - empty state
   - finalized and draft entries in newest-first order
   - always-visible language labels
   - row tap to entry detail
   - swipe-to-delete Cancel
   - swipe-to-delete Delete
   - top-left back control
4. Capture iOS runtime screenshot checkpoints during the integration run for
   the empty state, populated list, and delete-prompt states.
5. Record simulator target and passing command evidence in `tasks.md`.

### Validation exception request

No exception requested.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature may require a durable update to
  `docs/application-description.md` after final approval because the entry-list
  product behavior changes from planned/placeholder to implemented.
- This feature may require a durable update to `docs/agent-findings.md` if the
  implementation establishes reusable swipe-row, localization, or entry-list
  testing guidance.
- No durable `AGENTS.md` update is expected unless implementation reveals a
  lasting workflow or architecture rule.

## Integration notes

- The main-screen stats line already navigates to `/entries`; this feature
  changes the destination from placeholder content to the real entry list.
- The `/entry/:id` route remains a placeholder until the entry-detail story,
  but row taps must still navigate there with the selected id.
- The entry list uses the same repository stream as main-screen stats, so
  deletion should automatically update both the list and stats after the stream
  emits updated data.
- Screen-level swipe-up and swipe-down navigation are intentionally not
  implemented for this story.
- The Android reference implementation is useful for behavior, but Flutter
  implementation should follow the existing Riverpod, GoRouter, and theme-token
  patterns in this repo.

## Rollout & migration

No feature flag or data migration is planned. Existing stored entries continue
to render from the current encrypted local database. Users who navigate to
`/entries` will see the real list instead of placeholder content.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Swipe gestures conflict with vertical list scrolling | Medium | Medium | Keep horizontal drag handling row-scoped, require a horizontal reveal anchor, and verify with widget and integration tests. |
| Weekday/date/time formatting is not truly locale-aware | Medium | Medium | Add Flutter localization delegates and cover formatting helper behavior with locale-specific widget/unit tests. |
| Deletion appears successful before repository deletion completes | Low | High | Avoid optimistic removal; rely on repository stream updates and keep row visible on failure. |
| Haptic feedback is hard to assert automatically | Medium | Low | Keep haptic call isolated at reveal completion and verify where practical with widget hooks plus manual Android/iOS verification. |
| Entry-list route changes break existing router/main-screen tests | Medium | Medium | Update router, main-screen widget, and integration tests to assert the real list screen. |
| Adding localization delegates changes app locale resolution | Low | Medium | Use Flutter's broad localization delegate support and keep UI copy unchanged. |

## Open items from spec

None.
