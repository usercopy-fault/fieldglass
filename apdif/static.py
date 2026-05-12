from __future__ import annotations
import re
from pathlib import Path
from .core import command_exists, ensure_dir, run_cmd, write_json, write_text
SECRET_PATTERNS = {
    'aws_access_key': r'AKIA[0-9A-Z]{16}',
    'google_api_key': r'AIza[0-9A-Za-z_\\-]{20,}',
    'bearer_or_token': r'(?i)(bearer\\s+[A-Za-z0-9._\\-]{20,}|token[=:][A-Za-z0-9._\\-]{16,})',
    'private_key': r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    'url_with_secret': r"https?://[^\\s'\"]*(?:key|token|secret|password)[^\\s'\"]*",
}
WEBVIEW_PATTERNS=['WebView','addJavascriptInterface','setJavaScriptEnabled','shouldOverrideUrlLoading','loadUrl(']
def extract_strings(path: Path, limit:int=20000) -> list[str]:
    if command_exists('strings'):
        r=run_cmd(['strings', str(path)], timeout=60)
        if r.returncode==0: return r.stdout.splitlines()[:limit]
    data=path.read_bytes()[:10_000_000]
    return [m.decode('utf-8','ignore') for m in re.findall(rb'[ -~]{4,}', data)][:limit]
def secret_scan(strings: list[str]) -> list[dict]:
    return [{'type':n,'value':s[:300]} for s in strings for n,p in SECRET_PATTERNS.items() if re.search(p,s)]
def webview_scan(strings: list[str]) -> list[dict]:
    return [{'indicator':p,'value':s[:300]} for s in strings for p in WEBVIEW_PATTERNS if p in s]
def manifest_extract(apk: Path, outdir: Path) -> dict:
    ensure_dir(outdir)
    if command_exists('aapt'):
        r=run_cmd(['aapt','dump','badging',str(apk)], timeout=60); write_text(outdir/'manifest_aapt.txt', r.stdout+r.stderr); return {'tool':'aapt','returncode':r.returncode,'path':str(outdir/'manifest_aapt.txt')}
    return {'tool':'aapt','available':False,'message':'aapt not found'}
def jadx_decompile(apk: Path, outdir: Path) -> dict:
    if not command_exists('jadx'): return {'tool':'jadx','available':False,'message':'jadx not found'}
    dest=outdir/'jadx'; r=run_cmd(['jadx','-d',str(dest),str(apk)], timeout=300); return {'tool':'jadx','returncode':r.returncode,'path':str(dest),'stderr':r.stderr[-2000:]}
def analyze_file(apk: Path, outdir: Path) -> dict:
    ensure_dir(outdir); strings=extract_strings(apk); write_text(outdir/'strings.txt', '\n'.join(strings)+'\n')
    result={'apk':str(apk),'strings_count':len(strings),'strings_path':str(outdir/'strings.txt'),'secrets':secret_scan(strings),'webview_indicators':webview_scan(strings),'manifest':manifest_extract(apk,outdir),'jadx':jadx_decompile(apk,outdir)}
    write_json(outdir/'static.json', result); return result
