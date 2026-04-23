#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-review}"; shift || true
PKG=""; JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --json) JSON=1; shift ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) break ;;
  esac
done
[[ -n "$PKG" || "$cmd" == "help" ]] || _die 'Use {--pkg PKG}'
emit_output(){
  local target="$1" raw_file="$2" status=0
  if [[ "$JSON" -eq 1 ]]; then
    render_module_json "storage" "$cmd" "$target" "${APDIF_SERIAL:-}" "$raw_file" || status=$?
  else
    cat "$raw_file" || status=$?
  fi
  rm -f "$raw_file"
  return "$status"
}
case "$cmd" in
  review)
    pick_device
    raw_file="$(mktemp)"
    {
      printf '== shared prefs ==\n'; shellq run-as "$PKG" sh -c 'ls -la shared_prefs 2>/dev/null; for f in shared_prefs/*.xml; do [ -f "$f" ] && echo "--- $f" && sed -n "1,200p" "$f"; done' || true
      printf '\n== databases ==\n'; shellq run-as "$PKG" sh -c 'ls -la databases 2>/dev/null' || true
      printf '\n== files ==\n'; shellq run-as "$PKG" sh -c 'find files -maxdepth 3 -type f 2>/dev/null | sort | head -n 300' || true
    } > "$raw_file"
    emit_output "$PKG" "$raw_file"
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif storage review' '{--pkg PKG}' '[--json --serial SERIAL]' 'storage review via run-as'
    ;;
esac
