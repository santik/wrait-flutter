# Wrait Android release playbook

Use this checklist every time a new Android version is released to Google Play.
The release target is the Flutter Android application `com.wrait.flutter`.

## 1. Confirm the release scope

- Confirm the exact user-facing version name with the release owner. Use
  `MAJOR.MINOR.PATCH` format, for example `1.0.2`.
- Confirm the Play Console track. The normal tester track for Wrait is
  **Closed testing → Alpha**. Do not switch to Production unless explicitly
  requested.
- Collect the final release notes for the actual changes in this version.
- Confirm that the release is ready for external publication before making
  Play Console or Google Group changes.

## 2. Assign a new version and build number

1. Read the current `version:` value in `pubspec.yaml`.
2. Check the highest version code already uploaded or published in Play
   Console.
3. Choose a version code strictly greater than that value. Never reuse a
   version code, even if the earlier upload failed or was discarded.
4. Update `pubspec.yaml` so the version name and code match the intended
   release. For example, after published build `2`, a patch release is:

   ```yaml
   version: 1.0.2+3
   ```

   Flutter maps the value before `+` to Android `versionName` and the value
   after `+` to Android `versionCode`.

5. Keep the version in `pubspec.yaml` consistent with any command-line build
   overrides. The `--build-name` and `--build-number` options affect only the
   current build; they do not update `pubspec.yaml`.

## 3. Validate the source and release configuration

From the repository root, run:

```sh
flutter pub get
flutter analyze
flutter test
```

Before building, verify that:

- The intended code and release notes are present.
- Release signing configuration is available through the ignored
  `android/local.properties` or the approved transient environment variables.
- No signing password, proxy secret, Wiredash secret, or other credential is
  printed, committed, or added to release notes.
- The release package is `com.wrait.flutter`, not the debug/profile package
  `com.wrait.flutter.dev`.

If validation fails, stop and fix the failure. Do not upload an old bundle.

## 4. Build one fresh App Bundle

Use the repository release-bundle script:

```sh
./deploy_bundle.sh
```

If the release version is intentionally supplied only for this build, use
explicit values and verify them in the output:

```sh
./deploy_bundle.sh --build-name 1.0.2 --build-number 3
```

The script validates the release signing configuration and creates:

```text
build/app/outputs/bundle/release/app-release.aab
```

The build is accepted only when the command exits successfully and the bundle
exists and is non-empty. The script clears the previous bundle path before
building, so a failed run must never result in an upload of a leftover file.
The script does not install an app, create a Git commit, or create a Git tag.

For an additional artifact check, verify that the generated file is a valid
archive and record its SHA-256 checksum:

```sh
unzip -tq build/app/outputs/bundle/release/app-release.aab
shasum -a 256 build/app/outputs/bundle/release/app-release.aab
```

Upload only the bundle produced by the successful run just completed. Never
upload a bundle from a failed run, an older build directory, a debug APK, or a
profile APK.

## 5. Optional release-device smoke test

When release signing, update compatibility, backend connectivity, or device
behavior needs verification, run the physical-phone release flow separately:

```sh
./deploy_release.sh
```

This is separate from the App Bundle build. It is not a substitute for a
successful `./deploy_bundle.sh` run and must not change the Play upload artifact.

## 6. Upload and publish in Play Console

1. Open [Google Play Console](https://play.google.com/console/) and select
   **Wrait**.
2. Confirm the application package is `com.wrait.flutter`.
3. Open **Testing → Closed testing → Alpha** unless another track was approved.
4. Create a new release and upload the fresh
   `build/app/outputs/bundle/release/app-release.aab`.
5. Confirm that Play Console reports the intended version name and a version
   code greater than the previous release.
6. Add release notes for every required language. Keep them short and limited
   to changes actually included in the bundle. For example:

   ```text
   - Optimized the feedback form.
   - Improved portrait mode.
   ```

7. Review device-compatibility warnings. Wrait is intentionally portrait-only;
   do not change supported-device configuration just to remove a warning
   unless the release owner explicitly requests that change.
8. Save the release and review the final summary.
9. Immediately before the final **Send for review**, **Start rollout**, or
   **Publish** action, confirm with the release owner the exact version, build
   number, track, and release notes. Do not publish a different track or
   version by assumption.
10. After submission, verify the release status reaches the expected state,
    such as **In review** or **Published**.

## 7. Tag the exact release commit

Create the tag only for the commit that contains the release code and matching
`pubspec.yaml` version used to produce the uploaded bundle. Do not tag a dirty
worktree or a commit that includes unrelated changes.

1. Confirm the release commit and working tree:

   ```sh
   git status --short
   git log -1 --oneline
   ```

2. Confirm the tag name does not already exist locally or on the remote.
3. Create an annotated tag using the actual version name and build number. For
   example:

   ```sh
   git tag -a android-v1.0.2-build3 \
     -m "Android release 1.0.2 (build 3)"
   git push origin android-v1.0.2-build3
   ```

4. Verify that the tag points to the intended release commit:

   ```sh
   git show --summary android-v1.0.2-build3
   ```

Do not reuse a tag name or move an existing release tag. If the release commit
or version is ambiguous, stop and ask the release owner.

## 8. Announce the published update in the tester group

Post only after Play Console shows that the release is published or available
to the tester track.

1. Open the [Wrait Android Testers Google Group](https://groups.google.com/u/2/g/wrait-android-testers).
2. Use a signed-in group owner or manager account. The group’s default sender
   should remain the author’s address so the post is made from the user’s name.
3. If **New conversation** is disabled, an owner or manager must open
   **Group settings → Posting policies**, enable **Allow web posting**, and
   save the settings. Keep **Who can post** at **Group members** unless the
   release owner explicitly requests a different permission.
4. Create a new conversation with a version-specific subject, for example:

   ```text
   Wrait 1.0.2 is now available on Google Play
   ```

5. Use a message that reflects the actual release, for example:

   ```text
   Wrait 1.0.2 (build 3) is now published on Google Play for the closed test.

   This update includes:
   - Optimized feedback form
   - Improved portrait mode

   Please update Wrait and share any feedback here. Thanks for testing!
   ```

6. Immediately before clicking **Post message**, confirm with the release
   owner that this exact message may be sent to the tester group.
7. If the group moderates all messages, open **Pending** and approve the post
   when appropriate. Verify that it appears in the group conversation list.

## 9. Verify availability to testers

- Confirm the tester account is enrolled in the selected closed-testing track.
- Open the Wrait Play Store listing on a tester phone and verify that the new
  version is available.
- If the update prompt does not appear immediately, use the listing’s **Update**
  button and allow time for Play Store propagation.
- Confirm the Google Group announcement is visible or approved from Pending.
- Record the published version name, version code, track, release status,
  publication time, and bundle checksum.

## Stop conditions

Stop and ask the release owner for direction if any of the following occurs:

- The requested version name is ambiguous.
- The proposed version code is not greater than the highest Play Console code.
- `flutter analyze`, tests, signing validation, or `./deploy_bundle.sh` fails.
- The fresh bundle is missing, empty, invalid, or does not match the intended
  package/version.
- Play Console selects a different application or track than expected.
- The release owner has not confirmed the final public Play action or Google
  Group message.
- The group account lacks owner/manager permission to enable web posting.
