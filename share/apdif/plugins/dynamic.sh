#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-help}"; shift || true
PKG=""; CASE_NAME="default"; ACTION=""; DATA_URI=""; SPAWN=0; PAUSE=0; JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --case|--name) CASE_NAME="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --action) ACTION="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --data) DATA_URI="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --spawn) SPAWN=1; shift ;;
    --pause) PAUSE=1; shift ;;
    --json) JSON=1; shift ;;
    --save) shift ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) break ;;
  esac
done
[[ -n "$PKG" || "$cmd" == "help" ]] || _die 'Use {--pkg PKG}'
emit_output(){
  local target="$1" raw_file="$2" status=0
  if [[ "$JSON" -eq 1 ]]; then
    render_module_json "dynamic" "$cmd" "$target" "${APDIF_SERIAL:-}" "$raw_file" || status=$?
  else
    cat "$raw_file" || status=$?
  fi
  rm -f "$raw_file"
  return "$status"
}
case "$cmd" in
  attach)
    pick_device
    command -v frida >/dev/null 2>&1 || _die 'frida not found in PATH'
    if [[ "$SPAWN" -eq 1 ]]; then exec frida -U ${PAUSE:+--pause} -f "$PKG"; else exec frida -U -n "$PKG"; fi
    ;;
  filemon)
    pick_device
    raw_file="$(mktemp)"
    shellq run-as "$PKG" sh -c 'find . -maxdepth 3 -type f 2>/dev/null | sort | head -n 500' > "$raw_file" || true
    emit_output "$PKG" "$raw_file"
    ;;
  intent-fuzz)
    pick_device
    [[ -n "$ACTION" ]] || _die 'Use {--action ACTION}'
    raw_file="$(mktemp)"
    if [[ -n "$DATA_URI" ]]; then
      shellq am start -a "$ACTION" -d "$DATA_URI" > "$raw_file"
    else
      shellq am start -a "$ACTION" > "$raw_file"
    fi
    emit_output "$PKG" "$raw_file"
    ;;
  snapshot)
    pick_device
    dir="$(ensure_case "$CASE_NAME")"; out="$dir/artifacts/${PKG}_dynamic_snapshot_$(date +%Y%m%d_%H%M%S).txt"
    raw_file="$(mktemp)"
    {
      printf '== process list ==\n'; shellq ps -A | grep "$PKG" || true
      printf '\n== appops ==\n'; shellq cmd appops get "$PKG" || true
      printf '\n== files via run-as ==\n'; shellq run-as "$PKG" sh -c 'find . -maxdepth 3 -type f 2>/dev/null | sort | head -n 500' || true
    } > "$raw_file"
    cp "$raw_file" "$out"
    emit_output "$PKG" "$raw_file"
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif dynamic attach' '{--pkg PKG}' '[--spawn --pause --serial SERIAL]' 'Frida attach or spawn'
    usage_triplet 'apdif dynamic filemon' '{--pkg PKG}' '[--serial SERIAL]' 'quick file inventory'
    usage_triplet 'apdif dynamic intent-fuzz' '{--pkg PKG --action ACTION}' '[--data URI --serial SERIAL]' 'exercise intent surface'
    usage_triplet 'apdif dynamic snapshot' '{--pkg PKG --case NAME}' '[--save --serial SERIAL]' 'capture runtime state'
    ;;
esac
