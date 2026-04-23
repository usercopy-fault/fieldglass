#!/usr/bin/env bash

create_run_dir() {
  local case_name="$1"
  local command_id="$2"
  local target_kind="$3"
  local target_value="$4"
  local profile="${5:-baseline}"
  local case_dir run_id run_dir
  case_dir="$(ensure_case "$case_name")"
  run_id="run_$(date -u +%Y%m%dT%H%M%SZ)_${command_id// /_}"
  run_dir="${case_dir}/runs/${run_id}"
  mkdir -p "${run_dir}/raw" "${run_dir}/evidence" "${run_dir}/normalized" "${run_dir}/reports" "${run_dir}/findings"
  python3 - "$run_dir/run.json" "$run_id" "$case_name" "$command_id" "$target_kind" "$target_value" "$profile" "$APDIF_VERSION" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, run_id, case_name, command_id, target_kind, target_value, profile, version = sys.argv[1:9]
payload = {
    "run_id": run_id,
    "case_id": case_name,
    "command_id": command_id,
    "target": {"kind": target_kind, "value": target_value},
    "profile": profile,
    "status": "running",
    "started_at": datetime.now(timezone.utc).isoformat(),
    "finished_at": None,
    "apdif_version": version,
}
with open(path, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2)
PY
  printf '%s\n' "$run_dir"
}

finalize_run() {
  local run_dir="$1"
  local status="$2"
  python3 - "$run_dir/run.json" "$status" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, status = sys.argv[1:3]
with open(path, encoding="utf-8") as fh:
    payload = json.load(fh)
payload["status"] = status
payload["finished_at"] = datetime.now(timezone.utc).isoformat()
with open(path, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2)
PY
}

case_latest_run_dir() {
  local case_name="$1"
  local case_dir
  case_dir="$(ensure_case "$case_name")"
  find "${case_dir}/runs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n1
}
