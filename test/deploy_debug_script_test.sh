#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || fail "expected '$expected' in $file"
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    fail "did not expect '$unexpected' in $file"
  fi
}

write_fakes() {
  mkdir -p "$TMP_DIR/bin"

  cat >"$TMP_DIR/bin/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  devices)
    printf 'List of devices attached\n'
    case "${DEPLOY_TEST_SCENARIO:-}" in
      no_phone)
        ;;
      emulator_only)
        printf 'emulator-5554\tdevice\n'
        ;;
      unauthorized_phone)
        printf 'PHONE123\tunauthorized\n'
        ;;
      offline_phone)
        printf 'PHONE123\toffline\n'
        ;;
      disconnect_before_install)
        printf 'PHONE123\tdevice\n'
        ;;
      adb_failure)
        printf 'adb failed\n' >&2
        exit 1
        ;;
      one_phone|native_absent|native_removed_after_install|test_failure|build_no_apk|zero_size_apk)
        printf 'PHONE123\tdevice\n'
        ;;
      *)
        printf 'unknown scenario: %s\n' "${DEPLOY_TEST_SCENARIO:-}" >&2
        exit 2
        ;;
    esac
    ;;
  -s)
    printf 'adb %s\n' "$*" >>"$DEPLOY_TEST_LOG"
    if [[ "${3:-}" == "get-state" ]]; then
      if [[ "${DEPLOY_TEST_SCENARIO:-}" == "disconnect_before_install" ]]; then
        printf 'offline\n'
      else
        printf 'device\n'
      fi
      exit 0
    fi
    if [[ "${3:-}" == "shell" && "${4:-}" == "pm" && "${5:-}" == "path" ]]; then
      package_name="${6:-}"
      install_marker="$DEPLOY_TEST_STATE_DIR/install-complete"
      case "$package_name" in
        com.wrait.app)
          if [[ "${DEPLOY_TEST_SCENARIO:-}" == "native_absent" ]]; then
            exit 1
          fi
          if [[ "${DEPLOY_TEST_SCENARIO:-}" == "native_removed_after_install" && -f "$install_marker" ]]; then
            exit 1
          fi
          printf 'package:/data/app/com.wrait.app/base.apk\n'
          ;;
        com.wrait.flutter)
          [[ -f "$install_marker" ]] || exit 1
          printf 'package:/data/app/com.wrait.flutter/base.apk\n'
          ;;
        *)
          exit 1
          ;;
      esac
      exit 0
    fi
    if [[ "${4:-}" == "install" || "${3:-}" == "install" ]]; then
      mkdir -p "$DEPLOY_TEST_STATE_DIR"
      touch "$DEPLOY_TEST_STATE_DIR/install-complete"
      exit 0
    fi
    ;;
  *)
    printf 'adb %s\n' "$*" >>"$DEPLOY_TEST_LOG"
    ;;
esac
EOF

  cat >"$TMP_DIR/bin/flutter" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'flutter %s\n' "$*" >>"$DEPLOY_TEST_LOG"

case "$*" in
  build\ apk\ --debug*)
    case "${DEPLOY_TEST_SCENARIO:-}" in
      build_no_apk)
        ;;
      zero_size_apk)
        mkdir -p "$(dirname "$DEPLOY_TEST_APK_PATH")"
        : >"$DEPLOY_TEST_APK_PATH"
        ;;
      *)
        mkdir -p "$(dirname "$DEPLOY_TEST_APK_PATH")"
        printf 'fake apk\n' >"$DEPLOY_TEST_APK_PATH"
        ;;
    esac
    ;;
  "test --no-pub -d PHONE123 integration_test")
    if [[ "${DEPLOY_TEST_SCENARIO:-}" == "test_failure" ]]; then
      exit 42
    fi
    ;;
esac
EOF

  chmod +x "$TMP_DIR/bin/adb" "$TMP_DIR/bin/flutter"
}

run_script() {
  local scenario="$1"
  local output="$TMP_DIR/$scenario.out"
  local log="$TMP_DIR/$scenario.log"
  local apk_path="$TMP_DIR/$scenario/app-debug.apk"
  local state_dir="$TMP_DIR/$scenario/state"
  : >"$log"

  if [[ "$scenario" == "build_no_apk" ]]; then
    mkdir -p "$(dirname "$apk_path")"
    printf 'stale apk\n' >"$apk_path"
  fi

  (
    cd "$ROOT_DIR"
    PATH="$TMP_DIR/bin:$PATH" \
      DEPLOY_TEST_SCENARIO="$scenario" \
      DEPLOY_TEST_LOG="$log" \
      DEPLOY_TEST_ROOT="$ROOT_DIR" \
      PROXY_SECRET="test-proxy-secret" \
      DEPLOY_TEST_APK_PATH="$apk_path" \
      DEPLOY_TEST_STATE_DIR="$state_dir" \
      DEPLOY_DEBUG_APK_PATH="$apk_path" \
      ./deploy_debug.sh
  ) >"$output" 2>&1
}

run_script_expect_failure() {
  local scenario="$1"
  if run_script "$scenario"; then
    fail "expected $scenario to fail"
  fi
}

run_script_expect_success() {
  local scenario="$1"
  run_script "$scenario" || fail "expected $scenario to succeed"
}

run_script_without_proxy_secret_expect_failure() {
  local output="$TMP_DIR/missing_proxy_secret.out"
  local log="$TMP_DIR/missing_proxy_secret.log"
  local apk_path="$TMP_DIR/missing_proxy_secret/app-debug.apk"
  local state_dir="$TMP_DIR/missing_proxy_secret/state"
  : >"$log"

  if (
    cd "$ROOT_DIR"
    PATH="$TMP_DIR/bin:$PATH" \
      DEPLOY_TEST_SCENARIO="one_phone" \
      DEPLOY_TEST_LOG="$log" \
      DEPLOY_TEST_ROOT="$ROOT_DIR" \
      DEPLOY_TEST_APK_PATH="$apk_path" \
      DEPLOY_TEST_STATE_DIR="$state_dir" \
      DEPLOY_DEBUG_APK_PATH="$apk_path" \
      ./deploy_debug.sh
  ) >"$output" 2>&1; then
    fail "expected missing_proxy_secret to fail"
  fi
}

run_script_with_proxy_secret_expect_failure() {
  local scenario="$1"
  local proxy_secret="$2"
  local output="$TMP_DIR/$scenario.out"
  local log="$TMP_DIR/$scenario.log"
  local apk_path="$TMP_DIR/$scenario/app-debug.apk"
  local state_dir="$TMP_DIR/$scenario/state"
  : >"$log"

  if (
    cd "$ROOT_DIR"
    PATH="$TMP_DIR/bin:$PATH" \
      DEPLOY_TEST_SCENARIO="one_phone" \
      DEPLOY_TEST_LOG="$log" \
      DEPLOY_TEST_ROOT="$ROOT_DIR" \
      PROXY_SECRET="$proxy_secret" \
      DEPLOY_TEST_APK_PATH="$apk_path" \
      DEPLOY_TEST_STATE_DIR="$state_dir" \
      DEPLOY_DEBUG_APK_PATH="$apk_path" \
      ./deploy_debug.sh
  ) >"$output" 2>&1; then
    fail "expected $scenario to fail"
  fi
}

write_fakes

if grep -Eq '(^|[[:space:]])(adb|flutter)[[:space:]].*\buninstall\b' "$ROOT_DIR/deploy_debug.sh"; then
  fail "deploy_debug.sh must never uninstall any package"
fi

run_script_expect_failure no_phone
assert_contains "$TMP_DIR/no_phone.out" "no connected Android phone found"
assert_not_contains "$TMP_DIR/no_phone.log" "flutter build"
assert_not_contains "$TMP_DIR/no_phone.log" "install"

run_script_without_proxy_secret_expect_failure
assert_contains "$TMP_DIR/missing_proxy_secret.out" "required environment variable PROXY_SECRET is not set"
assert_not_contains "$TMP_DIR/missing_proxy_secret.log" "flutter build"
assert_not_contains "$TMP_DIR/missing_proxy_secret.log" "install"

run_script_with_proxy_secret_expect_failure short_proxy_secret "short"
assert_contains "$TMP_DIR/short_proxy_secret.out" "PROXY_SECRET must be at least 8 characters long"
assert_not_contains "$TMP_DIR/short_proxy_secret.log" "flutter build"

run_script_with_proxy_secret_expect_failure whitespace_proxy_secret "  secret value  "
assert_contains "$TMP_DIR/whitespace_proxy_secret.out" "PROXY_SECRET must not contain whitespace"
assert_not_contains "$TMP_DIR/whitespace_proxy_secret.log" "flutter build"

run_script_expect_failure adb_failure
assert_contains "$TMP_DIR/adb_failure.out" "adb devices failed"
assert_not_contains "$TMP_DIR/adb_failure.log" "flutter build"
assert_not_contains "$TMP_DIR/adb_failure.log" "install"

run_script_expect_failure emulator_only
assert_contains "$TMP_DIR/emulator_only.out" "no connected Android phone found"
assert_not_contains "$TMP_DIR/emulator_only.log" "flutter build"
assert_not_contains "$TMP_DIR/emulator_only.log" "install"

run_script_expect_failure unauthorized_phone
assert_contains "$TMP_DIR/unauthorized_phone.out" "Android phone is connected but unavailable"
assert_contains "$TMP_DIR/unauthorized_phone.out" "PHONE123 unauthorized"
assert_not_contains "$TMP_DIR/unauthorized_phone.log" "flutter build"
assert_not_contains "$TMP_DIR/unauthorized_phone.log" "install"

run_script_expect_failure offline_phone
assert_contains "$TMP_DIR/offline_phone.out" "Android phone is connected but unavailable"
assert_contains "$TMP_DIR/offline_phone.out" "PHONE123 offline"
assert_not_contains "$TMP_DIR/offline_phone.log" "flutter build"
assert_not_contains "$TMP_DIR/offline_phone.log" "install"

run_script_expect_failure test_failure
assert_contains "$TMP_DIR/test_failure.log" "flutter build apk --debug"
assert_contains "$TMP_DIR/test_failure.log" "flutter test --no-pub -d PHONE123 integration_test"
assert_not_contains "$TMP_DIR/test_failure.log" "install"

run_script_expect_failure build_no_apk
assert_contains "$TMP_DIR/build_no_apk.out" "debug APK was not created"
assert_not_contains "$TMP_DIR/build_no_apk.log" "install"

run_script_expect_failure zero_size_apk
assert_contains "$TMP_DIR/zero_size_apk.out" "debug APK at $TMP_DIR/zero_size_apk/app-debug.apk is empty"
assert_not_contains "$TMP_DIR/zero_size_apk.log" "install"

run_script_expect_failure disconnect_before_install
assert_contains "$TMP_DIR/disconnect_before_install.out" "Android phone PHONE123 is no longer connected and ready"
assert_not_contains "$TMP_DIR/disconnect_before_install.log" "adb -s PHONE123 install -r"

run_script_expect_failure native_removed_after_install
assert_contains "$TMP_DIR/native_removed_after_install.out" "com.wrait.app was installed before deployment but is missing after install"
assert_contains "$TMP_DIR/native_removed_after_install.log" "adb -s PHONE123 shell pm path com.wrait.app"
assert_contains "$TMP_DIR/native_removed_after_install.log" "adb -s PHONE123 install -r $TMP_DIR/native_removed_after_install/app-debug.apk"

run_script_expect_success native_absent
assert_contains "$TMP_DIR/native_absent.out" "Native Wrait app (com.wrait.app) was not installed before deployment."
assert_contains "$TMP_DIR/native_absent.out" "Installed com.wrait.flutter on PHONE123."

run_script_expect_success one_phone
assert_contains "$TMP_DIR/one_phone.log" "flutter build apk --debug --dart-define=PROXY_SECRET=test-proxy-secret"
assert_contains "$TMP_DIR/one_phone.log" "flutter test --no-pub -d PHONE123 integration_test"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell pm path com.wrait.app"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 get-state"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 install -r $TMP_DIR/one_phone/app-debug.apk"
assert_contains "$TMP_DIR/one_phone.log" "adb -s PHONE123 shell pm path com.wrait.flutter"
assert_contains "$TMP_DIR/one_phone.out" "Detected existing native Wrait app (com.wrait.app); it will be left installed."
assert_contains "$TMP_DIR/one_phone.out" "Verified com.wrait.app remains installed."
assert_contains "$TMP_DIR/one_phone.out" "Installed com.wrait.flutter on PHONE123."

printf 'deploy_debug_script_test.sh: all tests passed\n'
