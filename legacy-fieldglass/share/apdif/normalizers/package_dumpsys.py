#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


def normalize_package_dump(raw_text: str, evidence_id: str, package_name: str):
    observations = []
    lines = raw_text.splitlines()

    section = None
    for line in lines:
        stripped = line.strip()
        if stripped.endswith(":"):
            lower = stripped.lower()
            if lower == "requested permissions:":
                section = "requested_permissions"
                continue
            if lower == "install permissions:":
                section = "install_permissions"
                continue
            if lower == "runtime permissions:":
                section = "runtime_permissions"
                continue
            if lower == "queries:":
                section = "queries"
                continue
            if section and not stripped.startswith("android.permission."):
                section = None
        if section == "requested_permissions":
            if stripped.startswith("android.permission.") or stripped.startswith(package_name):
                observations.append({
                    "type": "android.permission.requested",
                    "subject": {"kind": "package", "id": package_name},
                    "attributes": {"name": stripped},
                    "source_evidence_ids": [evidence_id],
                    "normalizer_id": "android.dumpsys.package.v1",
                    "confidence": "medium",
                    "notes": "",
                })
            continue

        exported_match = re.search(r'(\S+)\s+filter .*exported=(true|false)', stripped)
        if exported_match:
            observations.append({
                "type": "android.package.exported_hint",
                "subject": {"kind": "package", "id": package_name},
                "attributes": {
                    "line": stripped,
                    "component_name": exported_match.group(1),
                    "exported": exported_match.group(2) == "true",
                },
                "source_evidence_ids": [evidence_id],
                "normalizer_id": "android.dumpsys.package.v1",
                "confidence": "medium",
                "notes": "",
            })

        if any(token in stripped for token in ("BROWSABLE", "scheme=", "host=", "path=", "Action:", "Category:")):
            observations.append({
                "type": "android.package.intent_hint",
                "subject": {"kind": "package", "id": package_name},
                "attributes": {"line": stripped},
                "source_evidence_ids": [evidence_id],
                "normalizer_id": "android.dumpsys.package.v1",
                "confidence": "medium",
                "notes": "",
            })

    return observations


def main():
    raw_path, evidence_id, package_name = sys.argv[1:4]
    raw_text = Path(raw_path).read_text(encoding="utf-8", errors="replace")
    print(json.dumps(normalize_package_dump(raw_text, evidence_id, package_name), indent=2))


if __name__ == "__main__":
    main()
