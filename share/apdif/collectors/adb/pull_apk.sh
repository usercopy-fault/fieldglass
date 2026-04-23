#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

RUN_DIR=""
PKG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIR="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --pkg) PKG="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) _die "Unknown option: $1" ;;
  esac
done
[[ -n "$RUN_DIR" && -n "$PKG" ]] || _die 'Use {--run-dir DIR --pkg PKG}'
pick_device

mkdir -p "${RUN_DIR}/inputs"
base_apk="${RUN_DIR}/inputs/${PKG}.apk"
first_path="$(apk_paths "$PKG" | head -n1)"
[[ -n "$first_path" ]] || _die "Unable to resolve apk path for ${PKG}"
adbq pull "$first_path" "$base_apk" >/dev/null
capture_command "$RUN_DIR" "adb.pull_apk" "package:${PKG}" "text/plain" \
  bash -lc 'printf "%s\n" "$0"' "$base_apk"
printf '%s\n' "$base_apk"
