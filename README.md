# wrait Flutter

Flutter rewrite of wrait, a minimal voice diary app for Android and iOS.

## Android debug deployment

Connect and authorize one physical Android phone, then run:

```sh
PROXY_SECRET=SECRET_WRAIT_VALUE ./deploy_debug.sh
```

The script:

- finds the single connected Android phone with `adb devices`
- requires a `PROXY_SECRET` with no whitespace and at least 8 characters so
  the installed app can authenticate launch registration and recording
  requests
- supports starting from a locked phone with the screen off
- wakes the phone before the real-device test phase and before the final
  verified launch
- may keep the phone awake during the automated run when the automation flow is
  active
- temporarily enables a namespaced Android automation setting so the
  debuggable activity can show over the lock screen during the test phase
- auto-grants `android.permission.RECORD_AUDIO` during the automated test setup
  so recording tests do not block on a permission dialog while `flutter test`
  reinstalls the app under test
- builds the Flutter debug APK for the `flutter test` phase
- runs `flutter test --no-pub -d <phone-serial> integration_test`
- builds the Flutter profile APK for the final installed app
- installs `build/app/outputs/flutter-apk/app-profile.apk` only after tests
  pass
- verifies the built APK exists and is non-empty before install
- re-checks that the phone is still connected before install
- verifies `com.wrait.flutter` is installed after deployment
- verifies the native `com.wrait.app` app is still installed when it was
  present before deployment
- restores the temporary stay-awake and automation-setting values before exit

The Flutter Android app installs as `com.wrait.flutter`, so it can coexist with
the native Wrait Android app installed as `com.wrait.app`. The deploy script
must never uninstall `com.wrait.app`.

The split between debug-for-tests and profile-for-final-install is deliberate:
the connected validation phone can run the existing Flutter integration flow,
but a standalone debug cold launch can remain stuck on the Flutter splash
screen after deployment. The equivalent profile build launches normally on that
device, so `deploy_debug.sh` installs profile only after the debug test phase
passes.

If no usable Android phone is connected, or if the phone is unauthorized or
offline, the script exits before build/install with a clear error. Emulator-only
deployment is intentionally out of scope for this command.

The script restores the temporary Android stay-awake and automation-setting
values that it changes, but it does not restore the phone's visible screen or
lock presentation state after the run. USB debugging authorization is still
required, and some device policies may block automation until private
credentials are entered manually.

## Manual debug APK build

To build the Android debug APK manually with the proxy secret baked into the
Flutter runtime config, run:

```sh
PROXY_SECRET=SECRET_WRAIT_VALUE \
  /opt/homebrew/bin/flutter build apk --debug \
  --dart-define=PROXY_SECRET=SECRET_WRAIT_VALUE
```

The generated APK path is:

```text
/Users/alexander/projects/wrait/write-flutter/build/app/outputs/flutter-apk/app-debug.apk
```

To install that APK on the connected phone:

```sh
adb -s 4A181FDJH0030G install -r \
  /Users/alexander/projects/wrait/write-flutter/build/app/outputs/flutter-apk/app-debug.apk
```

## Common checks

```sh
/opt/homebrew/bin/flutter analyze
/opt/homebrew/bin/flutter test
/opt/homebrew/bin/flutter build apk --debug
```
