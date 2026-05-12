from __future__ import annotations
import json, shutil, subprocess
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence
DEFAULT_CASE_ROOT = Path.home() / "cases" / "android"
@dataclass
class CommandResult:
    command: list[str]; returncode: int; stdout: str; stderr: str
    def to_dict(self) -> dict: return asdict(self)
def now_iso() -> str: return datetime.now(timezone.utc).replace(microsecond=0).isoformat()
def ensure_dir(path: Path) -> Path: path.mkdir(parents=True, exist_ok=True); return path
def command_exists(name: str) -> bool: return shutil.which(name) is not None
def run_cmd(args: Sequence[str], timeout: int = 30) -> CommandResult:
    try:
        p=subprocess.run(list(args), text=True, capture_output=True, timeout=timeout)
        return CommandResult(list(args), p.returncode, p.stdout, p.stderr)
    except FileNotFoundError as e: return CommandResult(list(args), 127, "", str(e))
    except subprocess.TimeoutExpired as e: return CommandResult(list(args), 124, e.stdout or "", e.stderr or f"timeout after {timeout}s")
def write_text(path: Path, content: str) -> Path: ensure_dir(path.parent); path.write_text(content, encoding='utf-8'); return path
def write_json(path: Path, data: object) -> Path: return write_text(path, json.dumps(data, indent=2, sort_keys=True)+"\n")
def read_json(path: Path, default: object) -> object:
    try: return json.loads(path.read_text(encoding='utf-8'))
    except Exception: return default
def append_jsonl(path: Path, row: dict) -> None:
    ensure_dir(path.parent)
    with path.open('a', encoding='utf-8') as f: f.write(json.dumps(row, sort_keys=True)+"\n")
def safe_name(name: str) -> str:
    cleaned=''.join(ch if ch.isalnum() or ch in '-_.' else '-' for ch in name.strip()).strip('.-_')
    return cleaned or 'case'
def case_path(case: str, root: Path|None=None) -> Path: return (root or DEFAULT_CASE_ROOT) / safe_name(case)
