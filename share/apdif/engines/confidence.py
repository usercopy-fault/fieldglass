#!/usr/bin/env python3
import json
import sys
from collections import Counter
from pathlib import Path


REQUIRED_BY_TARGET = {
    "pkg": [
        "adb.device_info",
        "adb.package_dump",
        "adb.appops",
        "adb.storage_inventory",
        "runtime.dynamic_snapshot",
        "adb.pull_apk",
        "apk.manifest_badging",
        "apk.manifest_tree",
        "apk.strings_secrets",
        "apk.strings_webview",
    ],
    "apk": [
        "apk.manifest_badging",
        "apk.manifest_tree",
        "apk.strings_secrets",
        "apk.strings_webview",
    ],
}


def load_jsonl(path: Path):
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def main():
    run_dir = Path(sys.argv[1])
    run = json.loads((run_dir / "run.json").read_text(encoding="utf-8"))
    evidence = load_jsonl(run_dir / "evidence" / "index.jsonl")
    findings = load_jsonl(run_dir / "findings" / "findings.jsonl")
    target_kind = run["target"]["kind"]
    required = REQUIRED_BY_TARGET.get(target_kind, [])
    by_collector = {item["collector_id"]: item for item in evidence}
    completed = [collector for collector in required if by_collector.get(collector, {}).get("collector_status") == "ok"]
    unmet = [collector for collector in required if collector not in completed]
    collector_counts = Counter(item["collector_status"] for item in evidence)
    severity_counts = Counter(item["severity"] for item in findings)
    score = int(round((len(completed) / len(required)) * 100)) if required else 0
    if collector_counts.get("error"):
        score = max(score - (collector_counts["error"] * 5), 0)

    payload = {
        "score": score,
        "target_kind": target_kind,
        "required_collectors": required,
        "completed_collectors": completed,
        "unmet_controls": unmet,
        "collector_counts": dict(collector_counts),
        "severity_counts": dict(severity_counts),
    }
    out_path = run_dir / "findings" / "confidence.json"
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(str(out_path))


if __name__ == "__main__":
    main()
