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
  class)
    conf_json="$("$APDIF_HOME/plugins/confidence.sh" score --case "$CASE_NAME" ${RUN_ID:+--run-id "$RUN_ID"})"
    CONF_JSON="$conf_json" python3 - <<'PY'
import json
import os

c = json.loads(os.environ["CONF_JSON"])
score = c["score"]
sev = c.get("severity_counts", {})
unmet = len(c.get("unmet_controls", []))
if score < 50 or sev.get("critical", 0) or sev.get("high", 0) >= 2:
    cls = "insufficient"
elif score < 70 or unmet > 3:
    cls = "baseline-reviewed"
elif score < 90 or unmet > 0:
    cls = "deep-reviewed"
else:
    cls = "high-confidence-in-scope"
payload = {"assurance_class": cls, "confidence": c}
print(json.dumps(payload, indent=2))
PY
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif assurance class' '{--case NAME}' '[--run-id RUN_ID --json]' 'map confidence into an assurance class'
    ;;
esac
