#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-help}"; shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  pm) pick_device; shellq pm "$@" ;;
  am) pick_device; shellq am "$@" ;;
  cmd) pick_device; shellq cmd "$@" ;;
  shell) pick_device; shellq "$@" ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif raw pm' '{ARGS}' '[--serial SERIAL]' 'direct pm wrapper'
    usage_triplet 'apdif raw am' '{ARGS}' '[--serial SERIAL]' 'direct am wrapper'
    usage_triplet 'apdif raw cmd' '{ARGS}' '[--serial SERIAL]' 'direct cmd wrapper'
    usage_triplet 'apdif raw shell' '{ARGS}' '[--serial SERIAL]' 'direct shell wrapper'
    ;;
esac
