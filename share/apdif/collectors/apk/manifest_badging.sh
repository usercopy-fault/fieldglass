#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

RUN_DIR=""
APK=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIR="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --apk) APK="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    *) _die "Unknown option: $1" ;;
  esac
done
[[ -n "$RUN_DIR" && -n "$APK" ]] || _die 'Use {--run-dir DIR --apk FILE}'
need aapt

capture_command "$RUN_DIR" "apk.manifest_badging" "apk:${APK}" "text/plain" run_tool aapt dump badging "$APK"
