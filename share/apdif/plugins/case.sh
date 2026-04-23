#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-help}"; shift || true
NAME="default"; PKG=""; TEXT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name|--case) NAME="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --pkg) PKG="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --text) TEXT="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --format) arg_value_or_die "$1" "${2-}" >/dev/null; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  open) ensure_case "$NAME" ;;
  note) dir="$(ensure_case "$NAME")"; printf '[%s] %s\n' "$(date -Is)" "$TEXT" >> "$dir/notes/notes.md"; _ok "Wrote $dir/notes/notes.md" ;;
  report) [[ -n "$PKG" ]] || _die 'Use {--case NAME --pkg PKG}'; "${APDIF_HOME}/plugins/report.sh" build --case "$NAME" --pkg "$PKG" ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif case open' '{--name NAME}' '[]' 'create or return case dir'
    usage_triplet 'apdif case note' '{--name NAME --text TEXT}' '[]' 'append operator note'
    usage_triplet 'apdif case report' '{--name NAME --pkg PKG}' '[--format md|json]' 'build case report'
    ;;
esac
