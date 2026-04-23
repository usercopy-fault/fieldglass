#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
source "${APDIF_HOME}/lib/parser.sh"

cmd="${1:-help}"
shift || true

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${1:-}" == "help" ]]; then
  cmd="help"
fi

APK=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk) APK="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    *) break ;;
  esac
done

case "$cmd" in
  manifest)
    [[ -n "$APK" ]] || _die 'Use {--apk FILE}'
    need aapt
    manifest_to_json "$APK"
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif parser manifest' '{--apk FILE}' '[]' 'parse AndroidManifest into normalized component and intent-filter JSON'
    ;;
esac
