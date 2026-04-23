#!/usr/bin/env bash

serial_apply() {
  if [[ -n "${APDIF_SERIAL:-$APDIF_DEFAULT_SERIAL}" ]]; then
    printf '%s' "${APDIF_SERIAL:-$APDIF_DEFAULT_SERIAL}"
  fi
}

adbq() {
  need adb
  local serial
  serial="$(serial_apply)"
  if [[ -n "$serial" ]]; then
    adb -s "$serial" "$@"
  else
    adb "$@"
  fi
}

shellq() {
  local serial
  serial="$(serial_apply)"
  if [[ -n "$serial" ]]; then
    adb -s "$serial" shell "$@"
  else
    adb shell "$@"
  fi
}

device_count() {
  adb devices | awk 'NR>1 && $2=="device" {print $1}' | wc -l | tr -d ' '
}

pick_device() {
  need adb
  local count serial
  count="$(device_count)"
  [[ "$count" -ge 1 ]] || _die 'No adb device in state=device'
  serial="$(serial_apply)"
  if [[ -n "$serial" ]]; then
    return 0
  fi
  if [[ "$count" -eq 1 ]]; then
    serial="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
    export APDIF_SERIAL="$serial"
    return 0
  fi
  _warn 'Multiple devices detected. Use [--serial SERIAL] or export ANDROID_SERIAL.'
  adb devices -l
  exit 1
}

current_focus_pkg() {
  shellq dumpsys window 2>/dev/null |
    awk '/mCurrentFocus|mFocusedApp/ {print}' |
    sed -n 's/.* \([^ /]*\)\/.*/\1/p' |
    head -n1
}

apk_paths() {
  local pkg="$1"
  shellq pm path "$pkg" | sed 's/^package://'
}
