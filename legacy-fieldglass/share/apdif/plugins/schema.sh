#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

cmd="${1:-help}"
shift || true

FILE=""
TYPE="finding"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --type) TYPE="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    *) break ;;
  esac
done

schema_path="${APDIF_HOME}/schemas/${TYPE}.schema.json"

case "$cmd" in
  show)
    [[ -f "$schema_path" ]] || _die "Unknown schema type: ${TYPE}"
    cat "$schema_path"
    ;;
  validate)
    [[ -n "$FILE" ]] || _die 'Use {--file FILE --type TYPE}'
    [[ -f "$schema_path" ]] || _die "Unknown schema type: ${TYPE}"
    python3 - "$FILE" "$schema_path" <<'PY'
import json
import sys

obj = json.load(open(sys.argv[1], encoding="utf-8"))
schema = json.load(open(sys.argv[2], encoding="utf-8"))
missing = [field for field in schema.get("required", []) if field not in obj]
if missing:
    print("invalid")
    print("missing:", ", ".join(missing))
    raise SystemExit(1)
print("valid")
PY
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif schema show' '{--type finding|evidence|run|observation|report}' '[]' 'print a bundled schema'
    usage_triplet 'apdif schema validate' '{--file FILE --type finding|evidence|run|observation|report}' '[]' 'validate required fields against a bundled schema'
    ;;
esac
