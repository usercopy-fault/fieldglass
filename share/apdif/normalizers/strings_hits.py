#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def normalize_strings(raw_text: str, evidence_id: str, package_name: str, category: str):
    observations = []
    for line in raw_text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        observations.append({
            "type": f"android.strings.{category}",
            "subject": {"kind": "package", "id": package_name},
            "attributes": {"value": stripped},
            "source_evidence_ids": [evidence_id],
            "normalizer_id": "android.strings.scan.v1",
            "confidence": "medium",
            "notes": "",
        })
    return observations


def main():
    raw_path, evidence_id, package_name, category = sys.argv[1:5]
    raw_text = Path(raw_path).read_text(encoding="utf-8", errors="replace")
    print(json.dumps(normalize_strings(raw_text, evidence_id, package_name, category), indent=2))


if __name__ == "__main__":
    main()
