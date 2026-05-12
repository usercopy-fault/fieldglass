#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-help}"; shift || true
PKG=""; GREP_TEXT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --grep) GREP_TEXT="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  logcat) pick_device; if [[ -n "$GREP_TEXT" ]]; then adbq logcat | grep -i --line-buffered "$GREP_TEXT"; else adbq logcat; fi ;;
  proc) pick_device; [[ -n "$PKG" ]] || _die 'Use {--pkg PKG}'; shellq ps -A | grep "$PKG" || true ;;
  intents) pick_device; [[ -n "$PKG" ]] || _die 'Use {--pkg PKG}'; shellq dumpsys package "$PKG" | grep -Ei 'Action:|Category:|scheme=|host=|path=|BROWSABLE|VIEW' ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif trace logcat' '{}' '[--grep TEXT --serial SERIAL]' 'log stream'
    usage_triplet 'apdif trace proc' '{--pkg PKG}' '[--serial SERIAL]' 'process list filter'
    usage_triplet 'apdif trace intents' '{--pkg PKG}' '[--serial SERIAL]' 'intent-relevant dump lines'
    ;;
esac
