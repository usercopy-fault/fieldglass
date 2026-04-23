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

capture_command "$RUN_DIR" "adb.appops" "package:${PKG}" "text/plain" shellq cmd appops get "$PKG"
