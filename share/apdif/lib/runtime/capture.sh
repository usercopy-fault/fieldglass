#!/usr/bin/env bash

append_jsonl() {
  local path="$1"
  local json_payload="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$json_payload" >> "$path"
}

next_evidence_id() {
  local run_dir="$1"
  local counter="${run_dir}/.evidence_counter"
  local next=1
  if [[ -f "$counter" ]]; then
    next=$(( $(<"$counter") + 1 ))
  fi
  printf '%s\n' "$next" > "$counter"
  printf 'EV-%06d\n' "$next"
}

capture_command() {
  local run_dir="$1"
  local collector_id="$2"
  local target_ref="$3"
  local content_type="$4"
  shift 4

  mkdir -p "$run_dir/raw" "$run_dir/evidence"
  local evidence_id seq stdout_path stderr_path exit_code status sha256 command_string collected_at evidence_json
  evidence_id="$(next_evidence_id "$run_dir")"
  seq="${evidence_id#EV-}"
  stdout_path="${run_dir}/raw/${seq}_${collector_id//./_}.stdout.txt"
  stderr_path="${run_dir}/raw/${seq}_${collector_id//./_}.stderr.txt"
  command_string="$(printf '%q ' "$@")"

  if "$@" >"$stdout_path" 2>"$stderr_path"; then
    exit_code=0
    status="ok"
  else
    exit_code=$?
    status="error"
  fi

  if [[ -f "$stdout_path" ]]; then
    sha256="$(sha256_file "$stdout_path")"
  else
    sha256=""
  fi
  collected_at="$(date -Is)"

  evidence_json="$(python3 - "$evidence_id" "$collector_id" "$target_ref" "$stdout_path" "$stderr_path" "$sha256" "$content_type" "$command_string" "$exit_code" "$collected_at" "$status" <<'PY'
import json
import os
import sys

evidence_id, collector_id, target_ref, raw_path, stderr_path, sha256, content_type, command_string, exit_code, collected_at, status = sys.argv[1:12]
payload = {
    "evidence_id": evidence_id,
    "collector_id": collector_id,
    "target_ref": target_ref,
    "raw_path": raw_path,
    "stderr_path": stderr_path,
    "sha256": sha256,
    "content_type": content_type,
    "command": command_string.strip(),
    "exit_code": int(exit_code),
    "collected_at": collected_at,
    "collector_status": status,
    "size_bytes": os.path.getsize(raw_path) if os.path.exists(raw_path) else 0,
}
print(json.dumps(payload, sort_keys=True))
PY
)"

  append_jsonl "${run_dir}/evidence/index.jsonl" "$evidence_json"
  printf '%s\n' "$evidence_json"
}
