#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def load_jsonl(path: Path):
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def main():
    run_dir = Path(sys.argv[1])
    run = json.loads((run_dir / "run.json").read_text(encoding="utf-8"))
    evidence = load_jsonl(run_dir / "evidence" / "index.jsonl")
    observations = load_jsonl(run_dir / "normalized" / "observations.jsonl")
    findings = load_jsonl(run_dir / "findings" / "findings.jsonl")
    confidence = json.loads((run_dir / "findings" / "confidence.json").read_text(encoding="utf-8"))

    report = {
        "report_id": f'report::{run["run_id"]}',
        "run": run,
        "summary_counts": {
            "evidence": len(evidence),
            "observations": len(observations),
            "findings": len(findings),
        },
        "confidence": confidence,
        "evidence": evidence,
        "observations": observations,
        "findings": findings,
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
