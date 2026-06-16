#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_PATH="${DEPLOY_DEBUG_APK_PATH:-$ROOT_DIR/build/app/outputs/flutter-apk/app-debug.apk}"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_non_empty_env() {
  local name="$1"
  local value="${!name:-}"
  [[ -n "$value" ]] || fail "required environment variable $name is not set"
}

validate_proxy_secret() {
  local value="$1"
  local collapsed="${value//[[:space:]]/}"

  [[ -n "$collapsed" ]] || fail "PROXY_SECRET must not be blank or whitespace only"
  [[ "$value" == "$collapsed" ]] || fail "PROXY_SECRET must not contain whitespace"
  (( ${#value} >= 8 )) || fail "PROXY_SECRET must be at least 8 characters long"
}

configure_java() {
  # Some editors inject a Java runtime path that no longer exists.
  unset VSCODE_JAVA_EXEC || true

  if [[ -z "${JAVA_HOME:-}" ]]; then
    if [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
      export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    elif command -v /usr/libexec/java_home >/dev/null 2>&1; then
      export JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null || /usr/libexec/java_home 2>/dev/null || true)"
    fi
  fi

  if [[ -n "${JAVA_HOME:-}" ]]; then
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
}

find_connected_phone() {
  local line serial state
  local devices_output
  local phone_serials=()
  local unavailable_phone_lines=()

  if ! devices_output="$(adb devices)"; then
    fail "adb devices failed; ensure Android platform tools can access the ADB daemon"
  fi

  while IFS= read -r line; do
    [[ -z "$line" || "$line" == "List of devices attached" ]] && continue

    read -r serial state _ <<<"$line"
    [[ -z "${serial:-}" ]] && continue

    # US-027 targets a physical Android phone and intentionally ignores emulators.
    if [[ "$serial" == emulator-* ]]; then
      continue
    fi

    if [[ "${state:-}" == "device" ]]; then
      phone_serials+=("$serial")
    else
      unavailable_phone_lines+=("$serial ${state:-unknown}")
    fi
  done <<<"$devices_output"

  if (( ${#phone_serials[@]} == 1 )); then
    printf '%s\n' "${phone_serials[0]}"
    return 0
  fi

  if (( ${#phone_serials[@]} > 1 )); then
    fail "expected one connected Android phone, found ${#phone_serials[@]}; disconnect extra phones and retry"
  fi

  if (( ${#unavailable_phone_lines[@]} > 0 )); then
    printf 'error: Android phone is connected but unavailable:\n' >&2
    printf '  %s\n' "${unavailable_phone_lines[@]}" >&2
    printf 'Authorize the phone for USB debugging, wait for it to come online, then retry.\n' >&2
    exit 1
  fi

  fail "no connected Android phone found; connect and authorize one phone, then retry"
}

package_installed() {
  local phone_serial="$1"
  local package_name="$2"
  adb -s "$phone_serial" shell pm path "$package_name" >/dev/null 2>&1
}

ensure_phone_connected() {
  local phone_serial="$1"
  local state

  state="$(adb -s "$phone_serial" get-state 2>/dev/null || true)"
  [[ "$state" == "device" ]] || fail "Android phone $phone_serial is no longer connected and ready"
}

prepare_apk_output() {
  local apk_path="$1"

  mkdir -p "$(dirname "$apk_path")"
  rm -f "$apk_path"
}

verify_built_apk() {
  local apk_path="$1"

  [[ -f "$apk_path" ]] || fail "debug APK was not created at $apk_path"
  [[ -s "$apk_path" ]] || fail "debug APK at $apk_path is empty"
}

main() {
  cd "$ROOT_DIR"
  configure_java
  require_command adb
  require_command flutter
  require_non_empty_env PROXY_SECRET
  validate_proxy_secret "$PROXY_SECRET"

  local phone_serial
  phone_serial="$(find_connected_phone)"
  local native_wrait_was_installed=false
  local flutter_build_args=(
    "--dart-define=PROXY_SECRET=$PROXY_SECRET"
  )

  printf 'Building Flutter debug APK...\n'
  prepare_apk_output "$APK_PATH"
  flutter build apk --debug "${flutter_build_args[@]}"

  verify_built_apk "$APK_PATH"

  printf 'Running Flutter integration tests on %s...\n' "$phone_serial"
  flutter test --no-pub -d "$phone_serial" integration_test

  if package_installed "$phone_serial" "com.wrait.app"; then
    native_wrait_was_installed=true
    printf 'Detected existing native Wrait app (com.wrait.app); it will be left installed.\n'
  else
    printf 'Native Wrait app (com.wrait.app) was not installed before deployment.\n'
  fi

  ensure_phone_connected "$phone_serial"
  printf 'Installing debug APK on %s...\n' "$phone_serial"
  adb -s "$phone_serial" install -r "$APK_PATH"

  package_installed "$phone_serial" "com.wrait.flutter" || fail "com.wrait.flutter was not found after install"

  if [[ "$native_wrait_was_installed" == true ]]; then
    package_installed "$phone_serial" "com.wrait.app" || fail "com.wrait.app was installed before deployment but is missing after install"
    printf 'Verified com.wrait.app remains installed.\n'
  fi

  printf 'Installed com.wrait.flutter on %s.\n' "$phone_serial"
}

main "$@"
