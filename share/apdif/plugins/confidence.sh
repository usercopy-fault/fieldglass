#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

cmd="${1:-help}"
shift || true

CASE_NAME="default"
RUN_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case|--name) CASE_NAME="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --run-id) RUN_ID="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --profile) shift 2 ;;
    --json) shift ;;
    *) break ;;
  esac
done

case "$cmd" in
  score)
    case_dir="$(ensure_case "$CASE_NAME")"
    if [[ -n "$RUN_ID" ]]; then
      run_dir="${case_dir}/runs/${RUN_ID}"
    else
      run_dir="$(case_latest_run_dir "$CASE_NAME")"
    fi
    [[ -n "${run_dir:-}" && -d "$run_dir" ]] || _die "No run found for case ${CASE_NAME}"
    python3 "$APDIF_HOME/engines/confidence.py" "$run_dir" >/dev/null
    cat "$run_dir/findings/confidence.json"
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif confidence score' '{--case NAME}' '[--run-id RUN_ID]' 'refresh and print confidence for the latest or selected run'
    ;;
esac
