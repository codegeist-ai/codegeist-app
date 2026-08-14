#!/usr/bin/env bash
# android-avd.sh - build and start Codegeist App in its dedicated Android AVD
#
# Why this exists:
# - Provides the reproducible headless and visible emulator workflow specified
#   by docs/tasks/T001_bootstrap_minimal_flutter_android_app.md.
# - Pins all ADB operations to emulator-5556 so no unrelated device can receive
#   the application.
#
# Inputs:
# - Optional mode: headless (default) or visible.
# - Android and Flutter SDK paths from .codegeist/Dockerfile.
# - The refreshed SSH X11 display from .devcontainer/.env for visible mode.
#
# Side effects:
# - Creates ~/.android/avd/codegeist_api_36.avd when missing.
# - Starts or reuses the dedicated emulator, installs the app, and launches it.
# - Keeps scrcpy in the foreground while visible mode mirrors the running app.
# - Stops only an emulator started by this invocation when the workflow fails.
#
# Related files:
# - .codegeist/Dockerfile
# - .devcontainer/.env
# - README.md
# - android/app/build.gradle.kts
set -euo pipefail

readonly MODE="${1:-headless}"
readonly AVD_NAME="codegeist_api_36"
readonly SYSTEM_IMAGE="system-images;android-36;google_apis;x86_64"
readonly EMULATOR_PORT="5556"
readonly SERIAL="emulator-${EMULATOR_PORT}"
readonly PACKAGE_ID="ai.codegeist.app"
readonly ACTIVITY="${PACKAGE_ID}/.MainActivity"
readonly BOOT_TIMEOUT_SECONDS="300"
readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APK_PATH="$ROOT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
readonly AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
readonly AVD_CONFIG="$AVD_HOME/${AVD_NAME}.avd/config.ini"

emulator_started=false
emulator_pid=""
reuse_emulator=false
avd_list=""

log() {
  local level="$1"
  local event="$2"
  shift 2
  printf 'level=%s event=%s %s\n' "$level" "$event" "$*" >&2
}

fail() {
  log error workflow_failed "reason=$1"
  exit 1
}

refresh_display_from_workspace_env() {
  local generated_env="$ROOT_DIR/.devcontainer/.env"
  local line=""
  local display_value=""

  [ -f "$generated_env" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      DEVCONTAINER_DISPLAY=*) display_value="${line#DEVCONTAINER_DISPLAY=}" ;;
    esac
  done <"$generated_env"

  [ -z "$display_value" ] || export DISPLAY="$display_value"
}

ensure_xdg_runtime_dir() {
  local runtime_dir="${XDG_RUNTIME_DIR:-}"

  if [ -n "$runtime_dir" ] && [ -d "$runtime_dir" ] && [ -w "$runtime_dir" ]; then
    return 0
  fi

  runtime_dir="${TMPDIR:-/tmp}/codegeist-runtime-${UID}"
  install -d -m 0700 "$runtime_dir"
  export XDG_RUNTIME_DIR="$runtime_dir"
}

normalize_ssh_xauthority() {
  local display_number=""
  local cookie=""
  local xauth_dir=""
  local normalized_xauthority=""

  case "${DISPLAY:-}" in
    localhost:[0-9]* | 127.0.0.1:[0-9]*) ;;
    *) return 0 ;;
  esac

  [ -n "${XAUTHORITY:-}" ] || return 0
  [ -f "$XAUTHORITY" ] || return 0
  command -v xauth >/dev/null 2>&1 || return 0

  display_number="${DISPLAY#*:}"
  display_number="${display_number%%.*}"
  cookie="$(xauth -f "$XAUTHORITY" list 2>/dev/null \
    | awk -v suffix="/unix:${display_number}" '$1 ~ suffix"$" { print $NF; exit }')"
  [ -n "$cookie" ] || return 0

  xauth_dir="${XDG_RUNTIME_DIR:-/tmp}"
  if [ ! -d "$xauth_dir" ] || [ ! -w "$xauth_dir" ]; then
    xauth_dir="/tmp"
  fi
  normalized_xauthority="$xauth_dir/codegeist-android-xauthority-${UID}"
  cp "$XAUTHORITY" "$normalized_xauthority"
  chmod 600 "$normalized_xauthority"
  export XAUTHORITY="$normalized_xauthority"

  xauth add "localhost:${display_number}" MIT-MAGIC-COOKIE-1 "$cookie" >/dev/null 2>&1
  xauth add "localhost:${display_number}.0" MIT-MAGIC-COOKIE-1 "$cookie" >/dev/null 2>&1
  xauth add "127.0.0.1:${display_number}" MIT-MAGIC-COOKIE-1 "$cookie" >/dev/null 2>&1
  xauth add "127.0.0.1:${display_number}.0" MIT-MAGIC-COOKIE-1 "$cookie" >/dev/null 2>&1
}

cleanup() {
  local exit_code="$?"

  if [ "$exit_code" -ne 0 ] && [ "$emulator_started" = true ]; then
    log info emulator_cleanup "serial=$SERIAL reason=workflow_failure"
    adb -s "$SERIAL" emu kill >/dev/null 2>&1 || true
    if [ -n "$emulator_pid" ]; then
      kill "$emulator_pid" >/dev/null 2>&1 || true
    fi
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

if [ "$#" -gt 1 ]; then
  fail "usage=$0_[headless|visible]"
fi

case "$MODE" in
  headless | visible) ;;
  *) fail "unsupported_mode=$MODE expected=headless_or_visible" ;;
esac

for command in adb avdmanager emulator flutter; do
  command -v "$command" >/dev/null 2>&1 || fail "missing_command=$command"
done

if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
  fail "kvm_unavailable path=/dev/kvm expected=readable_and_writable"
fi

if [ "$MODE" = visible ]; then
  refresh_display_from_workspace_env
  ensure_xdg_runtime_dir
  normalize_ssh_xauthority
  command -v scrcpy >/dev/null 2>&1 || fail "missing_command=scrcpy"
  command -v xdpyinfo >/dev/null 2>&1 || fail "missing_command=xdpyinfo"
  if [ -z "${DISPLAY:-}" ] || ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    fail "display_unavailable display=${DISPLAY:-unset} expected=usable_x11_transport"
  fi
fi

if adb -s "$SERIAL" get-state >/dev/null 2>&1; then
  running_avd_name="$(adb -s "$SERIAL" emu avd name 2>/dev/null \
    | tr -d '\r' \
    | awk 'NR == 1 { print; exit }')"
  if [ "$running_avd_name" != "$AVD_NAME" ]; then
    fail "emulator_serial_in_use serial=$SERIAL expected_avd=$AVD_NAME actual_avd=${running_avd_name:-unknown}"
  fi
  reuse_emulator=true
  log info emulator_start "status=reused mode=$MODE name=$AVD_NAME serial=$SERIAL"
fi

log info dependency_sync "status=started"
flutter pub get >&2
log info dependency_sync "status=completed"

if [ "$reuse_emulator" = false ]; then
  log info acceleration_check "status=started device=/dev/kvm"
  accel_output="$(emulator -accel-check 2>&1)" || {
    printf '%s\n' "$accel_output" >&2
    fail "emulator_acceleration_check_failed"
  }
  printf '%s\n' "$accel_output" >&2

  if ! avd_list="$(avdmanager list avd 2>&1)"; then
    printf '%s\n' "$avd_list" >&2
    fail "avd_list_failed"
  fi
  if ! grep -Fq "Name: $AVD_NAME" <<<"$avd_list"; then
    log info avd_create "status=started name=$AVD_NAME image=$SYSTEM_IMAGE"
    printf 'no\n' | avdmanager create avd \
      --force \
      --name "$AVD_NAME" \
      --package "$SYSTEM_IMAGE" \
      --device pixel_6 >&2
    log info avd_create "status=completed name=$AVD_NAME"
  else
    log info avd_create "status=reused name=$AVD_NAME"
  fi

  [ -f "$AVD_CONFIG" ] || fail "avd_config_missing path=$AVD_CONFIG"
  if grep -Eq '^disk\.dataPartition\.size[[:space:]]*=' "$AVD_CONFIG"; then
    sed -Ei 's/^disk\.dataPartition\.size[[:space:]]*=.*/disk.dataPartition.size=2G/' "$AVD_CONFIG"
  else
    printf '%s\n' 'disk.dataPartition.size=2G' >>"$AVD_CONFIG"
  fi
  log info avd_configure "status=completed data_partition=2G path=$AVD_CONFIG"

  emulator_args=(
    -avd "$AVD_NAME"
    -port "$EMULATOR_PORT"
    -accel on
    -no-snapshot
    -no-boot-anim
    -no-audio
    -no-window
    -gpu swiftshader_indirect
  )

  log info emulator_start "status=started mode=$MODE name=$AVD_NAME serial=$SERIAL"
  emulator "${emulator_args[@]}" >"${TMPDIR:-/tmp}/${AVD_NAME}.log" 2>&1 &
  emulator_pid="$!"
  emulator_started=true
fi

deadline=$((SECONDS + BOOT_TIMEOUT_SECONDS))
while true; do
  if [ "$emulator_started" = true ] && ! kill -0 "$emulator_pid" >/dev/null 2>&1; then
    emulator_log="${TMPDIR:-/tmp}/${AVD_NAME}.log"
    [ ! -f "$emulator_log" ] || tail -n 80 "$emulator_log" >&2
    fail "emulator_exited_before_boot serial=$SERIAL"
  fi

  device_state="$(adb -s "$SERIAL" get-state 2>/dev/null || true)"
  boot_completed="$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  boot_animation="$(adb -s "$SERIAL" shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r' || true)"
  if [ "$device_state" = device ] \
    && [ "$boot_completed" = 1 ] \
    && { [ "$boot_animation" = stopped ] || [ -z "$boot_animation" ]; }; then
    break
  fi

  if [ "$SECONDS" -ge "$deadline" ]; then
    fail "emulator_boot_timeout serial=$SERIAL timeout_seconds=$BOOT_TIMEOUT_SECONDS"
  fi
  sleep 2
done
log info emulator_start "status=completed serial=$SERIAL"

log info apk_build "status=started mode=debug"
flutter build apk --debug >&2
[ -f "$APK_PATH" ] || fail "apk_missing path=$APK_PATH"
log info apk_build "status=completed path=$APK_PATH"

log info app_install "status=started serial=$SERIAL package=$PACKAGE_ID"
adb -s "$SERIAL" install -r "$APK_PATH" >/dev/null
adb -s "$SERIAL" shell am force-stop "$PACKAGE_ID"
adb -s "$SERIAL" shell am start -W -n "$ACTIVITY" >/dev/null

deadline=$((SECONDS + 30))
app_pid=""
while [ -z "$app_pid" ] && [ "$SECONDS" -lt "$deadline" ]; do
  app_pid="$(adb -s "$SERIAL" shell pidof "$PACKAGE_ID" 2>/dev/null | tr -d '\r' || true)"
  [ -n "$app_pid" ] || sleep 1
done
[ -n "$app_pid" ] || fail "app_process_missing serial=$SERIAL package=$PACKAGE_ID"

if [ "$MODE" = visible ]; then
  log info app_mirror "status=started serial=$SERIAL renderer=software"
  scrcpy \
    --serial "$SERIAL" \
    --no-audio \
    --render-driver=software \
    --window-title="Codegeist App" >&2
  log info app_mirror "status=completed serial=$SERIAL"
fi

log info workflow_completed "mode=$MODE serial=$SERIAL package=$PACKAGE_ID pid=$app_pid"
printf '%s\n' "$SERIAL"
