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

capture_command "$RUN_DIR" "runtime.dynamic_snapshot" "package:${PKG}" "text/plain" \
  shellq sh -c "printf '== process list ==\n'; ps -A | grep '$PKG' || true; printf '\n== appops ==\n'; cmd appops get '$PKG' || true; printf '\n== files via run-as ==\n'; run-as '$PKG' sh -c 'find . -maxdepth 3 -type f 2>/dev/null | sort | head -n 500' || true"
