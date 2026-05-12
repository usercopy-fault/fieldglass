#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

cmd="${1:-help}"
shift || true

CASE_NAME="default"
PKG=""
FORMAT="md"
RUN_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case|--name) CASE_NAME="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --pkg) PKG="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --format) FORMAT="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --profile) parse_value_arg "$1" "${2-}" >/dev/null; shift 2 ;;
    --run-id) RUN_ID="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    *) break ;;
  esac
done

case "$cmd" in
  build)
    case_dir="$(ensure_case "$CASE_NAME")"
    if [[ -n "$RUN_ID" ]]; then
      run_dir="${case_dir}/runs/${RUN_ID}"
    else
      run_dir="$(case_latest_run_dir "$CASE_NAME")"
    fi
    [[ -n "${run_dir:-}" && -d "$run_dir" ]] || _die "No run found for case ${CASE_NAME}"
    run_pkg="$(python3 - "$run_dir" <<'PY'
import json
import sys
from pathlib import Path

run = json.loads((Path(sys.argv[1]) / "run.json").read_text(encoding="utf-8"))
print(run["target"]["value"])
PY
)"
    if [[ -n "$PKG" && "$PKG" != "$run_pkg" ]]; then
      _die "Latest run target is ${run_pkg}, not ${PKG}"
    fi
    mkdir -p "${case_dir}/reports"
    json_out="${case_dir}/reports/${run_pkg##*/}_$(basename "$run_dir").json"
    md_out="${case_dir}/reports/${run_pkg##*/}_$(basename "$run_dir").md"
    python3 "$APDIF_HOME/renderers/report_json.py" "$run_dir" > "$json_out"
    python3 "$APDIF_HOME/renderers/report_markdown.py" "$run_dir" > "$md_out"
    if [[ "$FORMAT" == "json" ]]; then
      cat "$json_out"
    else
      printf '%s\n' "$md_out"
    fi
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif report build' '{--case NAME --pkg PKG}' '[--format md|json --profile PROFILE --run-id RUN_ID]' 'render the latest structured run into JSON and analyst-friendly markdown'
    ;;
esac
