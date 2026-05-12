from __future__ import annotations
import re
from .core import command_exists, run_cmd
def adb_available() -> bool: return command_exists('adb')
def adb(args: list[str], serial: str|None=None, timeout: int=30):
    cmd=['adb'];
    if serial: cmd += ['-s', serial]
    return run_cmd(cmd+args, timeout=timeout)
def list_devices() -> list[dict]:
    if not adb_available(): return []
    res=adb(['devices','-l']); out=[]
    for line in res.stdout.splitlines()[1:]:
        if not line.strip(): continue
        parts=line.split(); d={'serial':parts[0], 'state': parts[1] if len(parts)>1 else 'unknown'}
        for p in parts[2:]:
            if ':' in p:
                k,v=p.split(':',1); d[k]=v
        out.append(d)
    return out
def getprop(prop: str, serial: str|None=None) -> str:
    r=adb(['shell','getprop',prop], serial); return r.stdout.strip() if r.returncode==0 else ''
def device_info(serial: str|None=None) -> dict:
    return {'adb_available': adb_available(), 'serial': serial, 'android_version': getprop('ro.build.version.release', serial), 'sdk': getprop('ro.build.version.sdk', serial), 'model': getprop('ro.product.model', serial), 'manufacturer': getprop('ro.product.manufacturer', serial)}
def package_path(pkg: str, serial: str|None=None) -> str:
    r=adb(['shell','pm','path',pkg], serial); m=re.search(r'package:(\S+)', r.stdout); return m.group(1) if m else ''
