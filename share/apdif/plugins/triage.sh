#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

cmd="${1:-help}"
shift || true

PKG=""
APK=""
CASE_NAME="default"
PROFILE="baseline"
JSON=0
RUN_ID=""
run_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --apk) APK="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --case|--name) CASE_NAME="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --profile) PROFILE="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --run-id) RUN_ID="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --json) JSON=1; shift ;;
    --save) shift ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) break ;;
  esac
done

trap 'if [[ -n "${run_dir:-}" && -f "${run_dir}/run.json" ]]; then finalize_run "$run_dir" "failed"; fi' ERR

run_summary() {
  local run_dir="$1"
  python3 - "$run_dir" <<'PY'
import json
import sys
from collections import Counter
from pathlib import Path

run_dir = Path(sys.argv[1])
run = json.loads((run_dir / "run.json").read_text(encoding="utf-8"))
evidence = [json.loads(line) for line in (run_dir / "evidence" / "index.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
findings_path = run_dir / "findings" / "findings.jsonl"
findings = []
if findings_path.exists():
    findings = [json.loads(line) for line in findings_path.read_text(encoding="utf-8").splitlines() if line.strip()]
collector_counts = Counter(item["collector_status"] for item in evidence)
severity_counts = Counter(item["severity"] for item in findings)
summary = {
    "run_id": run["run_id"],
    "case_id": run["case_id"],
    "target": run["target"],
    "collector_counts": dict(collector_counts),
    "severity_counts": dict(severity_counts),
    "run_dir": str(run_dir),
}
print(json.dumps(summary, indent=2))
PY
}

collect_pkg_run() {
  local run_dir="$1"
  "$APDIF_HOME/collectors/adb/device_info.sh" --run-dir "$run_dir" ${APDIF_SERIAL:+--serial "$APDIF_SERIAL"} >/dev/null
  "$APDIF_HOME/collectors/adb/package_dump.sh" --run-dir "$run_dir" --pkg "$PKG" ${APDIF_SERIAL:+--serial "$APDIF_SERIAL"} >/dev/null
  "$APDIF_HOME/collectors/adb/appops.sh" --run-dir "$run_dir" --pkg "$PKG" ${APDIF_SERIAL:+--serial "$APDIF_SERIAL"} >/dev/null
  "$APDIF_HOME/collectors/adb/storage_inventory.sh" --run-dir "$run_dir" --pkg "$PKG" ${APDIF_SERIAL:+--serial "$APDIF_SERIAL"} >/dev/null
  "$APDIF_HOME/collectors/runtime/dynamic_snapshot.sh" --run-dir "$run_dir" --pkg "$PKG" ${APDIF_SERIAL:+--serial "$APDIF_SERIAL"} >/dev/null
  local pulled_apk
  pulled_apk="$("$APDIF_HOME/collectors/adb/pull_apk.sh" --run-dir "$run_dir" --pkg "$PKG" ${APDIF_SERIAL:+--serial "$APDIF_SERIAL"} | tail -n1)"
  "$APDIF_HOME/collectors/apk/manifest_badging.sh" --run-dir "$run_dir" --apk "$pulled_apk" >/dev/null
  "$APDIF_HOME/collectors/apk/manifest_tree.sh" --run-dir "$run_dir" --apk "$pulled_apk" >/dev/null
  "$APDIF_HOME/collectors/apk/strings_secrets.sh" --run-dir "$run_dir" --apk "$pulled_apk" >/dev/null
  "$APDIF_HOME/collectors/apk/strings_webview.sh" --run-dir "$run_dir" --apk "$pulled_apk" >/dev/null
}

collect_apk_run() {
  local run_dir="$1"
  "$APDIF_HOME/collectors/apk/manifest_badging.sh" --run-dir "$run_dir" --apk "$APK" >/dev/null
  "$APDIF_HOME/collectors/apk/manifest_tree.sh" --run-dir "$run_dir" --apk "$APK" >/dev/null
  "$APDIF_HOME/collectors/apk/strings_secrets.sh" --run-dir "$run_dir" --apk "$APK" >/dev/null
  "$APDIF_HOME/collectors/apk/strings_webview.sh" --run-dir "$run_dir" --apk "$APK" >/dev/null
}

build_outputs() {
  local run_dir="$1"
  python3 "$APDIF_HOME/normalizers/normalize_run.py" "$run_dir" >/dev/null
  python3 "$APDIF_HOME/engines/findings.py" "$run_dir" >/dev/null
  python3 "$APDIF_HOME/engines/confidence.py" "$run_dir" >/dev/null
  python3 "$APDIF_HOME/renderers/report_json.py" "$run_dir" > "${run_dir}/reports/report.json"
  python3 "$APDIF_HOME/renderers/report_markdown.py" "$run_dir" > "${run_dir}/reports/report.md"
}

case "$cmd" in
  run)
    [[ -n "$PKG" || -n "$APK" ]] || _die 'Use {--pkg PKG | --apk FILE}'
    need_python
    need strings
    need aapt
    if [[ -n "$PKG" ]]; then
      need adb
    fi
    local_target_kind="pkg"
    local_target_value="$PKG"
    if [[ -n "$APK" ]]; then
      local_target_kind="apk"
      local_target_value="$APK"
    fi
    run_dir="$(create_run_dir "$CASE_NAME" "triage.run" "$local_target_kind" "$local_target_value" "$PROFILE")"
    if [[ -n "$PKG" ]]; then
      collect_pkg_run "$run_dir"
    else
      collect_apk_run "$run_dir"
    fi
    build_outputs "$run_dir"
    finalize_run "$run_dir" "complete"
    trap - ERR
    if [[ "$JSON" -eq 1 ]]; then
      run_summary "$run_dir"
    else
      python3 - "$run_dir" <<'PY'
import json
import sys
from collections import Counter
from pathlib import Path

run_dir = Path(sys.argv[1])
run = json.loads((run_dir / "run.json").read_text(encoding="utf-8"))
evidence = [json.loads(line) for line in (run_dir / "evidence" / "index.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
findings = []
findings_path = run_dir / "findings" / "findings.jsonl"
if findings_path.exists():
    findings = [json.loads(line) for line in findings_path.read_text(encoding="utf-8").splitlines() if line.strip()]
collector_counts = Counter(item["collector_status"] for item in evidence)
severity_counts = Counter(item["severity"] for item in findings)
print(f"Target: {run['target']['value']}  Case: {run['case_id']}  Run: {run['run_id']}")
print(f"Collectors: {collector_counts.get('ok', 0)} succeeded, {collector_counts.get('error', 0)} failed")
print(f"Findings: critical={severity_counts.get('critical',0)} high={severity_counts.get('high',0)} medium={severity_counts.get('medium',0)} low={severity_counts.get('low',0)} info={severity_counts.get('info',0)}")
print(f"Report JSON: {run_dir / 'reports' / 'report.json'}")
print(f"Report MD: {run_dir / 'reports' / 'report.md'}")
PY
    fi
    ;;
  score)
    if [[ -n "$RUN_ID" ]]; then
      run_dir="$(ensure_case "$CASE_NAME")/runs/${RUN_ID}"
    else
      run_dir="$(case_latest_run_dir "$CASE_NAME")"
    fi
    [[ -n "${run_dir:-}" && -f "$run_dir/findings/confidence.json" ]] || _die "No completed run found for case ${CASE_NAME}"
    cat "$run_dir/findings/confidence.json"
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif triage run' '{--pkg PKG | --apk FILE}' '[--case NAME --profile PROFILE --json --serial SERIAL]' 'structured end-to-end collection, findings, and report generation'
    usage_triplet 'apdif triage score' '{--case NAME}' '[--run-id RUN_ID]' 'show confidence summary for the latest or selected run'
    ;;
esac
