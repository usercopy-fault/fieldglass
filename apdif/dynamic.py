from __future__ import annotations
from pathlib import Path
from .adb import adb
from .core import command_exists, ensure_dir, run_cmd, write_text
def logcat_capture(outdir: Path, serial: str|None=None, seconds:int=10) -> dict:
    ensure_dir(outdir); r=adb(['logcat','-d','-v','time'], serial, timeout=max(seconds,10)); p=outdir/'logcat.txt'; write_text(p,r.stdout+r.stderr); return {'returncode':r.returncode,'path':str(p)}
def process_snapshot(outdir: Path, serial: str|None=None) -> dict:
    ensure_dir(outdir); r=adb(['shell','ps','-A'], serial); p=outdir/'processes.txt'; write_text(p,r.stdout+r.stderr); return {'returncode':r.returncode,'path':str(p)}
def storage_inventory(pkg: str, outdir: Path, serial: str|None=None) -> dict:
    ensure_dir(outdir); outs=[]
    for c in [['shell','run-as',pkg,'find','.','-maxdepth','4','-type','f','-printf','%p %s\\n'], ['shell','run-as',pkg,'ls','-laR']]:
        r=adb(c, serial); outs.append(f"$ adb {' '.join(c)}\nRC={r.returncode}\n{r.stdout}{r.stderr}\n")
        if r.returncode==0: break
    p=outdir/'storage_inventory.txt'; write_text(p,'\n'.join(outs)); return {'path':str(p),'attempts':len(outs)}
def frida_run(pkg: str, profile: Path, outdir: Path, serial: str|None=None) -> dict:
    ensure_dir(outdir)
    if not command_exists('frida'): return {'available':False,'message':'frida not found'}
    cmd=['frida','-U','-f',pkg,'-l',str(profile),'--no-pause']; r=run_cmd(cmd, timeout=120); p=outdir/'frida.txt'; write_text(p,r.stdout+r.stderr); return {'returncode':r.returncode,'path':str(p)}
