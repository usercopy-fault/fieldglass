from __future__ import annotations
from pathlib import Path
from .core import DEFAULT_CASE_ROOT, append_jsonl, case_path, ensure_dir, now_iso, read_json, write_json, write_text
SUBDIRS=['apk','static','dynamic','reports','evidence','frida','notes']
def create_case(name: str, root: Path|None=None, metadata: dict|None=None) -> Path:
    p=case_path(name, root); ensure_dir(p)
    for s in SUBDIRS: ensure_dir(p/s)
    if not (p/'case.json').exists(): write_json(p/'case.json', {'case':p.name,'created_at':now_iso(),'metadata':metadata or {}})
    return p
def list_cases(root: Path|None=None) -> list[dict]:
    b=root or DEFAULT_CASE_ROOT
    if not b.exists(): return []
    return [{'case':p.name,'path':str(p),'metadata':read_json(p/'case.json',{})} for p in sorted(b.iterdir()) if p.is_dir()]
def add_note(case: str, note: str, root: Path|None=None) -> Path:
    p=create_case(case, root); row={'time':now_iso(),'note':note}; append_jsonl(p/'notes'/'notes.jsonl', row)
    md=p/'notes'/'notes.md'; old=md.read_text(encoding='utf-8') if md.exists() else f'# Notes for {p.name}\n\n'; write_text(md, old+f"- {row['time']}: {note}\n"); return md
def artifact_paths(case: str, root: Path|None=None) -> dict:
    p=create_case(case, root); return {'root':str(p),'case_json':str(p/'case.json')} | {s:str(p/s) for s in SUBDIRS}
