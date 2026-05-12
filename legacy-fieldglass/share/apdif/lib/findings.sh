#!/usr/bin/env bash

finding_emit() {
  local case_name="$1"
  local pkg="$2"
  local finding_id="$3"
  local severity="$4"
  local title="$5"
  local status="$6"
  local evidence_text="$7"
  local case_dir out_path payload
  case_dir="$(ensure_case "$case_name")"
  mkdir -p "${case_dir}/findings"
  out_path="${case_dir}/findings/${finding_id}_$(date -u +%Y%m%dT%H%M%SZ).json"
  payload="$(python3 - "$finding_id" "$pkg" "$severity" "$title" "$status" "$evidence_text" <<'PY'
import json
import sys
from datetime import datetime, timezone

finding_id, pkg, severity, title, status, evidence_text = sys.argv[1:7]
payload = {
    "finding_id": finding_id,
    "package": pkg,
    "severity": severity,
    "title": title,
    "status": status,
    "summary": evidence_text,
    "generated_at": datetime.now(timezone.utc).isoformat(),
}
print(json.dumps(payload, indent=2))
PY
)"
  printf '%s\n' "$payload" > "$out_path"
  printf '%s\n' "$out_path"
}

finding_summary() {
  local case_name="$1"
  local case_dir latest_run
  case_dir="$(ensure_case "$case_name")"
  latest_run="$(case_latest_run_dir "$case_name")"
  python3 - "${latest_run:-}" "${case_dir}/findings" <<'PY'
import json
import os
import sys
from glob import glob

run_dir, findings_dir = sys.argv[1:3]
items = []
if run_dir:
    run_findings = os.path.join(run_dir, "findings", "findings.jsonl")
    if os.path.exists(run_findings):
        with open(run_findings, encoding="utf-8") as fh:
            items.extend(json.loads(line) for line in fh if line.strip())
for path in sorted(glob(os.path.join(findings_dir, "*.json"))):
    with open(path, encoding="utf-8") as fh:
        items.append(json.load(fh))
print(json.dumps(items, indent=2))
PY
}
