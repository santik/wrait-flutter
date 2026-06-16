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
  the installed debug app can authenticate launch registration and recording
  requests
- builds the Flutter debug APK
- runs `flutter test --no-pub -d <phone-serial> integration_test`
- installs `build/app/outputs/flutter-apk/app-debug.apk` only after tests pass
- verifies the built APK exists and is non-empty before install
- re-checks that the phone is still connected before install
- verifies `com.wrait.flutter` is installed after deployment
- verifies the native `com.wrait.app` app is still installed when it was
  present before deployment

The Flutter Android app installs as `com.wrait.flutter`, so it can coexist with
the native Wrait Android app installed as `com.wrait.app`. The deploy script
must never uninstall `com.wrait.app`.

If no usable Android phone is connected, or if the phone is unauthorized or
offline, the script exits before build/install with a clear error. Emulator-only
deployment is intentionally out of scope for this command.

## Common checks

```sh
/opt/homebrew/bin/flutter analyze
/opt/homebrew/bin/flutter test
/opt/homebrew/bin/flutter build apk --debug
```
