# wrait Tester Guide

Thanks for testing wrait. This guide explains how to get started, what to try,
and what to watch for in the current Flutter build.

## What wrait Is

wrait is a voice diary for your phone. You open it, tap the main button, talk,
tap again, and the app turns the recording into a diary entry.

There is no account. Entries are stored locally in an encrypted database. The
current Flutter build uses the configured wrait backend for transcription,
cleanup, and anonymous device registration.

## Installing The App

### Android APK

If you received an APK directly outside Google Play:

1. Copy or download the APK to your phone.
2. Open the APK from Downloads, Files, or your browser.
3. If Android blocks the install, tap Settings and allow that app to install
   unknown apps.
4. Go back and tap Install.
5. After install, you can turn the unknown-apps permission back off.

Requirements: Android 8.0 or newer.

### iOS

Install through the distribution channel provided by the developer, such as
TestFlight or a development build. The app requires microphone permission and a
device security setup that can satisfy the app lock flow.

## Using The App

### Recording An Entry

1. Open wrait.
2. Unlock the app if the privacy lock appears.
3. Tap the large button.
4. Speak your entry.
5. Tap again to stop.

The app uploads the recording for transcription, sends the raw transcript for
cleanup, and saves the resulting entry locally. If backend work fails in a
recoverable way, wrait preserves a draft and retries later.

### Reading Entries

Tap the stats line, such as `12 entries - 8 days`, to open the entries list.
Entries are shown newest first. Drafts are included and visibly marked.

Tap an entry to open the detail screen.

### Editing, Sharing, And Deleting

On the detail screen:

- use the edit action to change the saved entry text
- use the share action to open the platform share sheet
- use the delete action to remove the entry after confirmation

On the entries list, swipe right on a row to delete it after confirmation.

### Exporting And Importing

The entries screen has CSV export and import actions.

- Export creates a Wrait CSV file with saved and draft entries.
- Export does not include retained audio files.
- Import accepts Wrait-produced CSV files only.
- Import is additive and does not update or delete existing entries.

## What Happens To Your Data

In the current Flutter build:

- Voice audio is sent to the configured wrait backend for transcription.
- Raw transcript text is sent to the configured wrait backend for cleanup.
- An anonymous device ID is sent for device registration and backend requests.
- Saved entries stay in the encrypted local database on your device.
- Cleaned entry text is not sent back to wrait-operated servers after it is
  saved locally by the app.

For full details, see [PRIVACY.md](PRIVACY.md).

## Things To Know Before You Start

There is no account or cloud sync. If you uninstall the app, clear app data, or
factory reset the phone, local entries can be lost.

Short recordings may be discarded if they do not contain enough usable audio.

The app may ask for microphone permission, biometric/PIN authentication, and
device security settings depending on the platform and device configuration.

CSV exports are plain files. Treat them as sensitive if they contain private
entries.

## What To Try

- Record a few entries in different styles: calm, fast, emotional, and
  stream-of-consciousness.
- Record in the languages you actually use and check whether the cleaned text
  still sounds like you.
- Stop a recording normally and confirm the saved entry appears in the list.
- Tap the stats line and verify it opens the entries list.
- Open an entry, edit text, leave the screen, and reopen it to verify the edit
  persisted.
- Share an entry and confirm the platform share sheet receives the expected
  text.
- Delete an entry from the list and from the detail screen.
- Export entries to CSV and verify the file is created.
- Import a Wrait CSV and verify entries are added without replacing existing
  ones.
- Put the app in the background and return to it to check the privacy lock.
- Try taking a screenshot or opening the app switcher and check that sensitive
  content is protected where the platform supports it.
- Try recording with poor connectivity and check whether a draft is preserved.

## Known Rough Edges

This is an early Flutter build. Current limitations include:

- no account or cross-device sync
- no cloud backup of local entries
- no search
- no offline transcription mode in the Flutter client
- no automated system document picker coverage in the repo-local import tests
- iOS active screen-recording privacy still needs stronger physical-device
  validation beyond the current simulator evidence

## Giving Feedback

Please report bugs or specific issues directly to:

fedorets.alex@gmail.com

Useful feedback includes:

- whether cleanup output sounds natural in your language
- whether anything felt slow or unresponsive
- whether the recording flow was confusing
- whether the privacy lock behaved as expected
- whether any entry was lost, duplicated, or unexpectedly changed

*wrait - speak your mind. keep it private.*
