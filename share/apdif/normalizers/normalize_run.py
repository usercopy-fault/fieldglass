#!/usr/bin/env python3
import json
import sys
from pathlib import Path

from appops import normalize_appops
from dynamic_snapshot import normalize_dynamic
from manifest_aapt import normalize_manifest_text
from package_dumpsys import normalize_package_dump
from storage_listing import normalize_storage
from strings_hits import normalize_strings


HANDLERS = {
    "apk.manifest_tree": lambda text, evidence_id, package_name: normalize_manifest_text(text, evidence_id, package_name),
    "adb.package_dump": lambda text, evidence_id, package_name: normalize_package_dump(text, evidence_id, package_name),
    "apk.strings_secrets": lambda text, evidence_id, package_name: normalize_strings(text, evidence_id, package_name, "secret_like"),
    "apk.strings_webview": lambda text, evidence_id, package_name: normalize_strings(text, evidence_id, package_name, "webview_indicator"),
    "adb.storage_inventory": lambda text, evidence_id, package_name: normalize_storage(text, evidence_id, package_name),
    "runtime.dynamic_snapshot": lambda text, evidence_id, package_name: normalize_dynamic(text, evidence_id, package_name),
    "adb.appops": lambda text, evidence_id, package_name: normalize_appops(text, evidence_id, package_name),
}


def main():
    run_dir = Path(sys.argv[1])
    run = json.loads((run_dir / "run.json").read_text(encoding="utf-8"))
    package_name = run["target"]["value"]
    evidence_index = run_dir / "evidence" / "index.jsonl"
    observations = []
    obs_counter = 1

    for line in evidence_index.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        evidence = json.loads(line)
        observations.append({
            "observation_id": f"OBS-{obs_counter:06d}",
            "type": "collector.status",
            "subject": {"kind": "collector", "id": evidence["collector_id"]},
            "attributes": {
                "collector_status": evidence["collector_status"],
                "exit_code": evidence["exit_code"],
                "raw_path": evidence["raw_path"],
            },
            "source_evidence_ids": [evidence["evidence_id"]],
            "normalizer_id": "apdif.collector.status.v1",
            "confidence": "high",
            "notes": "",
        })
        obs_counter += 1

        handler = HANDLERS.get(evidence["collector_id"])
        if not handler:
            continue
        raw_path = Path(evidence["raw_path"])
        try:
            raw_text = raw_path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        normalized = handler(raw_text, evidence["evidence_id"], package_name)
        for item in normalized:
            item["observation_id"] = f"OBS-{obs_counter:06d}"
            observations.append(item)
            obs_counter += 1

    out_path = run_dir / "normalized" / "observations.jsonl"
    with out_path.open("w", encoding="utf-8") as fh:
        for item in observations:
            fh.write(json.dumps(item, sort_keys=True))
            fh.write("\n")
    print(str(out_path))


if __name__ == "__main__":
    main()
