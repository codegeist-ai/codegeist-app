#!/usr/bin/env bash
# android-smoke.sh - verify the installed Codegeist App on its dedicated AVD
#
# Why this exists:
# - Exercises the Android runtime contract beyond Flutter widget tests by using
#   the same build, install, and launch workflow as normal development.
# - Optionally records a short MP4 of the verified app launch through scrcpy.
#
# Inputs:
# - Optional --record flag enables MP4 output.
# - SMOKE_RECORD_PATH overrides .artifacts/codegeist-smoke.mp4.
# - SMOKE_RECORD_SECONDS overrides the six-second recording duration.
#
# Side effects:
# - Starts or reuses emulator-5556 through scripts/android-avd.sh.
# - Writes and removes a temporary UI hierarchy on the Android device.
# - Replaces SMOKE_RECORD_PATH when recording is requested.
#
# Related files:
# - scripts/android-avd.sh
# - Taskfile.yml
# - docs/tasks/T004_add_android_smoke_test.md
set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SERIAL="emulator-5556"
readonly PACKAGE_ID="ai.codegeist.app"
readonly ACTIVITY="${PACKAGE_ID}/.MainActivity"
readonly UI_DUMP_PATH="/data/local/tmp/codegeist-smoke.xml"
readonly RECORD_SECONDS="${SMOKE_RECORD_SECONDS:-6}"

record=false
record_path="${SMOKE_RECORD_PATH:-$ROOT_DIR/.artifacts/codegeist-smoke.mp4}"
recording_pid=""

log() {
  local level="$1"
  local event="$2"
  shift 2
  printf 'level=%s event=%s %s\n' "$level" "$event" "$*" >&2
}

fail() {
  log error smoke_failed "reason=$1"
  exit 1
}

cleanup() {
  if [ -n "$recording_pid" ] && kill -0 "$recording_pid" >/dev/null 2>&1; then
    kill "$recording_pid" >/dev/null 2>&1 || true
    wait "$recording_pid" >/dev/null 2>&1 || true
  fi
  adb -s "$SERIAL" shell rm -f "$UI_DUMP_PATH" >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# Verify process, foreground activity, and Android semantics so a successful
# build alone cannot satisfy this runtime smoke test.
assert_runtime_contract() {
  local device_state=""
  local app_pid=""
  local activity_state=""
  local ui_dump=""

  device_state="$(adb -s "$SERIAL" get-state 2>/dev/null || true)"
  [ "$device_state" = device ] || fail "device_unavailable serial=$SERIAL state=${device_state:-missing}"

  app_pid="$(adb -s "$SERIAL" shell pidof "$PACKAGE_ID" 2>/dev/null | tr -d '\r' || true)"
  [ -n "$app_pid" ] || fail "app_process_missing serial=$SERIAL package=$PACKAGE_ID"

  activity_state="$(adb -s "$SERIAL" shell dumpsys activity activities 2>/dev/null || true)"
  printf '%s\n' "$activity_state" \
    | grep -F 'ResumedActivity:' \
    | grep -Fq "$ACTIVITY" \
    || fail "activity_not_resumed serial=$SERIAL activity=$ACTIVITY"

  adb -s "$SERIAL" shell rm -f "$UI_DUMP_PATH" >/dev/null
  adb -s "$SERIAL" shell uiautomator dump "$UI_DUMP_PATH" >/dev/null \
    || fail "ui_dump_failed serial=$SERIAL"
  ui_dump="$(adb -s "$SERIAL" shell cat "$UI_DUMP_PATH" 2>/dev/null | tr -d '\r' || true)"
  printf '%s\n' "$ui_dump" \
    | grep -Fq 'content-desc="codegeist"' \
    || fail "start_text_missing serial=$SERIAL expected=codegeist"

  log info smoke_check "status=completed serial=$SERIAL package=$PACKAGE_ID pid=$app_pid text=codegeist"
}

if [ "$#" -gt 1 ]; then
  fail "usage=$0_[--record]"
fi
if [ "$#" -eq 1 ]; then
  [ "$1" = --record ] || fail "usage=$0_[--record]"
  record=true
fi

case "$RECORD_SECONDS" in
  '' | *[!0-9]*) fail "invalid_record_seconds value=$RECORD_SECONDS expected=positive_integer" ;;
esac
[ "$RECORD_SECONDS" -gt 0 ] \
  || fail "invalid_record_seconds value=$RECORD_SECONDS expected=positive_integer"

for command in adb grep tr; do
  command -v "$command" >/dev/null 2>&1 || fail "missing_command=$command"
done
if [ "$record" = true ]; then
  for command in ffprobe scrcpy; do
    command -v "$command" >/dev/null 2>&1 || fail "missing_command=$command"
  done
fi

log info smoke_workflow "status=started serial=$SERIAL record=$record"
if ! actual_serial="$("$ROOT_DIR/scripts/android-avd.sh" headless)"; then
  fail "android_workflow_failed"
fi
[ "$actual_serial" = "$SERIAL" ] \
  || fail "serial_mismatch expected=$SERIAL actual=${actual_serial:-missing}"
assert_runtime_contract

if [ "$record" = true ]; then
  if [[ "$record_path" != /* ]]; then
    record_path="$ROOT_DIR/$record_path"
  fi
  install -d -m 0755 "$(dirname -- "$record_path")"
  rm -f "$record_path"

  log info smoke_record "status=started serial=$SERIAL path=$record_path duration_seconds=$RECORD_SECONDS"
  scrcpy \
    --serial "$SERIAL" \
    --no-audio \
    --no-control \
    --no-playback \
    --no-window \
    --record="$record_path" \
    --time-limit="$RECORD_SECONDS" >&2 &
  recording_pid="$!"

  sleep 1
  kill -0 "$recording_pid" >/dev/null 2>&1 \
    || fail "recording_exited_early path=$record_path"
  adb -s "$SERIAL" shell am force-stop "$PACKAGE_ID"
  adb -s "$SERIAL" shell am start -W -n "$ACTIVITY" >/dev/null

  if ! wait "$recording_pid"; then
    recording_pid=""
    fail "recording_failed path=$record_path"
  fi
  recording_pid=""
  [ -s "$record_path" ] || fail "recording_missing path=$record_path"

  record_codec="$(ffprobe -v error -select_streams v:0 \
    -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 \
    "$record_path" 2>/dev/null || true)"
  record_duration="$(ffprobe -v error \
    -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 \
    "$record_path" 2>/dev/null || true)"
  [ -n "$record_codec" ] || fail "recording_video_stream_missing path=$record_path"
  awk -v duration="$record_duration" 'BEGIN { exit !(duration > 0) }' \
    || fail "recording_duration_invalid path=$record_path duration=${record_duration:-missing}"

  assert_runtime_contract
  log info smoke_record "status=completed path=$record_path codec=$record_codec duration_seconds=$record_duration"
  printf '%s\n' "$record_path"
else
  log info smoke_workflow "status=completed serial=$SERIAL"
  printf '%s\n' "$SERIAL"
fi
