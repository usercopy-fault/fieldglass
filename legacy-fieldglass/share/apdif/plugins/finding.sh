#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
source "${APDIF_HOME}/lib/findings.sh"

cmd="${1:-help}"
shift || true

CASE_NAME="default"
PKG=""
ID=""
SEV="info"
TITLE=""
STATUS="confirmed"
EVID=""
CONTROL_ID=""
SOURCE_TYPE=""
SOURCE_PATH=""
TAGS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case|--name) CASE_NAME="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --pkg) PKG="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --id) ID="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --severity) SEV="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --title) TITLE="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --status) STATUS="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --evidence) EVID="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --control-id) CONTROL_ID="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --source-type) SOURCE_TYPE="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --source-path) SOURCE_PATH="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --tags) TAGS="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    *) break ;;
  esac
done

case "$cmd" in
  add)
    [[ -n "$PKG" && -n "$ID" && -n "$TITLE" ]] || _die 'Use {--case NAME --pkg PKG --id ID --title TITLE}'
    out="$(finding_emit "$CASE_NAME" "$PKG" "$ID" "$SEV" "$TITLE" "$STATUS" "$EVID")"
    python3 - "$out" "$CONTROL_ID" "$SOURCE_TYPE" "$SOURCE_PATH" "$TAGS" "$STATUS" <<'PY'
import json
import sys

path, control_id, source_type, source_path, tags, status = sys.argv[1:7]
with open(path, encoding="utf-8") as fh:
    obj = json.load(fh)
if control_id:
    obj["control_id"] = control_id
if source_type:
    obj["source_type"] = source_type
if source_path:
    obj["source_path"] = source_path
if tags:
    obj["tags"] = [item.strip() for item in tags.split(",") if item.strip()]
obj["status"] = status
with open(path, "w", encoding="utf-8") as fh:
    json.dump(obj, fh, indent=2)
print(path)
PY
    ;;
  list)
    finding_summary "$CASE_NAME"
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif finding add' '{--case NAME --pkg PKG --id ID --title TITLE}' '[--severity SEV --status STATUS --evidence TEXT --control-id ID --source-type TYPE --source-path FILE --tags a,b]' 'add a manual finding record to the case'
    usage_triplet 'apdif finding list' '{--case NAME}' '[]' 'list findings for the latest run plus manual case findings'
    ;;
esac
