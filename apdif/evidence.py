from __future__ import annotations
import hashlib
from pathlib import Path
from .core import append_jsonl, now_iso
def sha256_file(path: Path) -> str:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for c in iter(lambda:f.read(1024*1024), b''): h.update(c)
    return h.hexdigest()
def record_evidence(case_dir: Path, path: Path, kind: str, description: str='') -> dict:
    row={'time':now_iso(),'kind':kind,'path':str(path),'description':description}
    if path.exists() and path.is_file(): row |= {'sha256': sha256_file(path), 'size': path.stat().st_size}
    append_jsonl(case_dir/'evidence'/'evidence.jsonl', row); return row
