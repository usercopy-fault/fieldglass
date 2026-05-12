#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def normalize_storage(raw_text: str, evidence_id: str, package_name: str):
    observations = []
    section = None
    for line in raw_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("== ") and stripped.endswith(" =="):
            section = stripped.strip("= ").lower().replace(" ", "_")
            continue
        if not stripped:
            continue
        observations.append({
            "type": "android.storage.entry",
            "subject": {"kind": "package", "id": package_name},
            "attributes": {"section": section or "unknown", "line": stripped},
            "source_evidence_ids": [evidence_id],
            "normalizer_id": "android.storage.run_as.v1",
            "confidence": "medium",
            "notes": "",
        })
    return observations


def main():
    raw_path, evidence_id, package_name = sys.argv[1:4]
    raw_text = Path(raw_path).read_text(encoding="utf-8", errors="replace")
    print(json.dumps(normalize_storage(raw_text, evidence_id, package_name), indent=2))


if __name__ == "__main__":
    main()
