from __future__ import annotations
import json
from pathlib import Path
from .confidence import calculate_confidence
from .core import now_iso, read_json, write_json, write_text
from .findings import load_findings
def load_jsonl(path: Path) -> list[dict]:
    out=[]
    if not path.exists(): return out
    for l in path.read_text(encoding='utf-8').splitlines():
        try: out.append(json.loads(l))
        except Exception: pass
    return out
def build_report(case_dir: Path) -> dict:
    findings=load_findings(case_dir); evidence=load_jsonl(case_dir/'evidence'/'evidence.jsonl'); controls=read_json(case_dir/'controls.json', {'completed':[]}); confidence=calculate_confidence(controls.get('completed',[]) if isinstance(controls,dict) else [], findings); artifacts=[str(p.relative_to(case_dir)) for p in case_dir.rglob('*') if p.is_file()]
    return {'case':case_dir.name,'generated_at':now_iso(),'case_dir':str(case_dir),'findings':findings,'evidence':evidence,'coverage':controls,'confidence':confidence,'artifacts':sorted(artifacts)}
def write_reports(case_dir: Path) -> dict:
    data=build_report(case_dir); jp=case_dir/'reports'/'report.json'; mp=case_dir/'reports'/'report.md'; write_json(jp,data)
    lines=[f"# APDIF Report: {data['case']}",'',f"Generated: {data['generated_at']}",f"Case directory: {data['case_dir']}",'','## Confidence','',f"Score: {data['confidence']['score']}",f"Assurance class: {data['confidence']['assurance_class']}",'','## Findings','']
    lines += [f"- [{f.get('severity','info')}] {f.get('title')} ({f.get('status')})" for f in data['findings']] or ['No findings recorded.']
    lines += ['','## Evidence',''] + ([f"- {e.get('kind')}: {e.get('path')}" for e in data['evidence']] or ['No evidence recorded.']) + ['','## Artifacts',''] + [f"- {a}" for a in data['artifacts']]
    write_text(mp, '\n'.join(lines)+'\n'); return {'json':str(jp),'markdown':str(mp),'data':data}
