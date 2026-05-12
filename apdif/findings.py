from __future__ import annotations
import json
from pathlib import Path
from .core import append_jsonl, now_iso
def add_finding(case_dir: Path, title: str, severity: str='info', status: str='observed', evidence: str='', category: str='general') -> dict:
    row={'time':now_iso(),'title':title,'severity':severity,'status':status,'evidence':evidence,'category':category}; append_jsonl(case_dir/'findings.jsonl', row); return row
def load_findings(case_dir: Path) -> list[dict]:
    p=case_dir/'findings.jsonl'; out=[]
    if not p.exists(): return out
    for l in p.read_text(encoding='utf-8').splitlines():
        try: out.append(json.loads(l))
        except Exception: pass
    return out
def findings_from_static(static_result: dict, case_dir: Path) -> list[dict]:
    out=[]
    for h in static_result.get('secrets',[]): out.append(add_finding(case_dir, f"Secret-like string: {h.get('type')}", 'medium', 'needs-review', h.get('value',''), 'static'))
    if static_result.get('webview_indicators'): out.append(add_finding(case_dir, 'WebView usage indicators present', 'info', 'observed', str(len(static_result['webview_indicators'])), 'static'))
    return out
