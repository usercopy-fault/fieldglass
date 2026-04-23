#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-help}"; shift || true
PKG=""; ACTION=""; DATA_URI=""; EXTRA_KEY=""; EXTRA_VAL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --action) ACTION="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --data) DATA_URI="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --extra-key) EXTRA_KEY="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --extra-val) EXTRA_VAL="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  list) pick_device; [[ -n "$PKG" ]] || _die 'Use {--pkg PKG}'; shellq dumpsys package "$PKG" | grep -Ei 'Action:|Category:|scheme=|host=|path=|BROWSABLE|VIEW' ;;
  fire)
    pick_device
    [[ -n "$ACTION" ]] || _die 'Use {--action ACTION}'
    if [[ -n "$DATA_URI" && -n "$EXTRA_KEY" ]]; then shellq am start -a "$ACTION" -d "$DATA_URI" --es "$EXTRA_KEY" "$EXTRA_VAL";
    elif [[ -n "$DATA_URI" ]]; then shellq am start -a "$ACTION" -d "$DATA_URI";
    else shellq am start -a "$ACTION"; fi
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif intent list' '{--pkg PKG}' '[--serial SERIAL]' 'intent hints from dumpsys'
    usage_triplet 'apdif intent fire' '{--action ACTION}' '[--data URI --extra-key K --extra-val V --serial SERIAL]' 'fire crafted intent'
    ;;
esac
