#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

RUN_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIR="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) _die "Unknown option: $1" ;;
  esac
done
[[ -n "$RUN_DIR" ]] || _die 'Use {--run-dir DIR}'
pick_device

collect_device_info() {
  printf 'Serial: %s\n' "${APDIF_SERIAL:-unknown}"
  shellq getprop ro.product.manufacturer
  shellq getprop ro.product.model
  shellq getprop ro.build.version.release
  shellq getprop ro.build.version.sdk
}

capture_command "$RUN_DIR" "adb.device_info" "device:${APDIF_SERIAL:-unknown}" "text/plain" collect_device_info
