#!/usr/bin/env bash

case_add_evidence() {
  local case_name="$1"
  local kind="$2"
  local path="$3"
  local note="${4:-}"
  local case_dir evidence_id sha256 payload
  case_dir="$(ensure_case "$case_name")"
  evidence_id="MANUAL-$(date -u +%Y%m%dT%H%M%SZ)-$RANDOM"
  if [[ -f "$path" ]]; then
    sha256="$(sha256_file "$path")"
  else
    sha256=""
  fi
  payload="$(python3 - "$evidence_id" "$kind" "$path" "$note" "$sha256" <<'PY'
import json
import sys
from datetime import datetime, timezone

evidence_id, kind, path, note, sha256 = sys.argv[1:6]
payload = {
    "evidence_id": evidence_id,
    "kind": kind,
    "path": path,
    "note": note,
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "sha256": sha256,
}
print(json.dumps(payload, sort_keys=True))
PY
)"
  append_jsonl "${case_dir}/evidence/manual.jsonl" "$payload"
  printf '%s\n' "$payload"
}

case_list_evidence() {
  local case_name="$1"
  local case_dir latest_run
  case_dir="$(ensure_case "$case_name")"
  latest_run="$(case_latest_run_dir "$case_name")"
  python3 - "${latest_run:-}" "${case_dir}/evidence/manual.jsonl" <<'PY'
import json
import os
import sys

run_dir, manual_path = sys.argv[1:3]
items = []
if run_dir:
    idx = os.path.join(run_dir, "evidence", "index.jsonl")
    if os.path.exists(idx):
        with open(idx, encoding="utf-8") as fh:
            items.extend(json.loads(line) for line in fh if line.strip())
if os.path.exists(manual_path):
    with open(manual_path, encoding="utf-8") as fh:
        items.extend(json.loads(line) for line in fh if line.strip())
print(json.dumps(items, indent=2))
PY
}
