from __future__ import annotations
import argparse, json
from pathlib import Path
from . import __version__
from . import adb as adbmod
from .cases import add_note, artifact_paths, create_case, list_cases
from .confidence import calculate_confidence
from .core import DEFAULT_CASE_ROOT, command_exists, write_json, write_text
from .dynamic import frida_run, logcat_capture, process_snapshot, storage_inventory
from .evidence import record_evidence
from .findings import findings_from_static, load_findings
from .report import write_reports
from .static import analyze_file
HELP_GRAMMAR='Command grammar: (cmd){options}[flags], e.g. apdif triage run {--pkg PKG --case CASE} [--profile deep --json --serial SERIAL]'
def emit(data, as_json=False): print(json.dumps(data, indent=2, sort_keys=True) if as_json or isinstance(data,(dict,list)) else str(data))
def add_common(p): p.add_argument('--json', action='store_true'); p.add_argument('--serial')
def cmd_device(a):
    ds=[d | adbmod.device_info(d.get('serial')) for d in adbmod.list_devices()]; emit({'adb_available':adbmod.adb_available(),'devices':ds,'ok':bool(ds)}, a.json); return 0 if adbmod.adb_available() else 2
def cmd_app(a):
    cd=create_case(a.case) if a.case else None; out={'pkg':a.pkg}; controls=[]
    def save(n,r):
        out[n]=r.to_dict()
        if cd:
            p=cd/'evidence'/f'{n}.txt'; write_text(p,r.stdout+r.stderr); record_evidence(cd,p,n)
    if a.action in ('permissions','dump','all'): save('package_dump', adbmod.adb(['shell','dumpsys','package',a.pkg], a.serial)); controls+=['permissions','runtime-permissions','package-dump']
    if a.action in ('runtime-permissions','all'): save('runtime_permissions', adbmod.adb(['shell','cmd','package','list','permissions','-g','-d'], a.serial)); controls.append('runtime-permissions')
    if a.action in ('appops','all'): save('appops', adbmod.adb(['shell','cmd','appops','get',a.pkg], a.serial)); controls.append('appops')
    if a.action in ('apk-path','pull-apk','all'):
        path=adbmod.package_path(a.pkg,a.serial); out['apk_path']=path
        if path and a.action in ('pull-apk','all') and cd:
            dest=cd/'apk'/f'{a.pkg}.apk'; r=adbmod.adb(['pull',path,str(dest)], a.serial, timeout=120); out['pull_apk']=r.to_dict()
            if dest.exists(): record_evidence(cd,dest,'apk'); controls.append('apk-pulled')
    if cd and controls: write_json(cd/'controls.json', {'completed':sorted(set(controls))})
    emit(out,a.json); return 0
def cmd_static(a):
    outdir=Path(a.out) if a.out else (create_case(a.case)/'static' if a.case else Path.cwd()/'apdif-static'); res=analyze_file(Path(a.apk), outdir)
    if a.case:
        cd=create_case(a.case); findings_from_static(res, cd); record_evidence(cd, Path(res['strings_path']), 'static-strings')
    emit(res,a.json); return 0
def cmd_dynamic(a):
    cd=create_case(a.case); out={}; controls=[]
    if a.action in ('logcat','all'): out['logcat']=logcat_capture(cd/'dynamic',a.serial,a.seconds); controls.append('dynamic-logcat')
    if a.action in ('processes','all'): out['processes']=process_snapshot(cd/'dynamic',a.serial); controls.append('process-snapshot')
    if a.action in ('storage','all'):
        if not a.pkg: raise SystemExit('--pkg required for storage')
        out['storage']=storage_inventory(a.pkg,cd/'dynamic',a.serial); controls.append('storage-inventory')
    if a.frida_profile:
        if not a.pkg: raise SystemExit('--pkg required for frida')
        out['frida']=frida_run(a.pkg,Path(a.frida_profile),cd/'frida',a.serial); controls.append('frida-profile')
    write_json(cd/'controls.json', {'completed':sorted(set(controls))}); emit(out,a.json); return 0
def cmd_intent(a):
    if a.action=='hints':
        r=adbmod.adb(['shell','dumpsys','package',a.pkg], a.serial); hints=[l.strip() for l in r.stdout.splitlines() if any(x in l.lower() for x in ('scheme=','android.intent.action.view','filter','data'))]; emit({'pkg':a.pkg,'hints':hints},a.json)
    else:
        cmd=['shell','am','start','-W','-a',a.action_name];
        if a.data: cmd += ['-d',a.data]
        if a.pkg: cmd += [a.pkg]
        emit(adbmod.adb(cmd,a.serial).to_dict(),a.json)
    return 0
def cmd_case(a):
    if a.action=='create': emit({'path':str(create_case(a.case))},a.json)
    elif a.action=='list': emit(list_cases(),a.json)
    elif a.action=='note': emit({'note_path':str(add_note(a.case,a.note))},a.json)
    else: emit(artifact_paths(a.case),a.json)
    return 0
def cmd_triage(a):
    cd=create_case(a.case); completed=['device-info']; out={'case_dir':str(cd),'pkg':a.pkg,'profile':a.profile,'device':adbmod.device_info(a.serial)}
    dump=adbmod.adb(['shell','dumpsys','package',a.pkg], a.serial); p=cd/'evidence'/'package_dump.txt'; write_text(p,dump.stdout+dump.stderr); record_evidence(cd,p,'package-dump'); completed+=['permissions','runtime-permissions','package-dump']
    appops=adbmod.adb(['shell','cmd','appops','get',a.pkg], a.serial); p2=cd/'evidence'/'appops.txt'; write_text(p2,appops.stdout+appops.stderr); record_evidence(cd,p2,'appops'); completed.append('appops')
    apk_path=adbmod.package_path(a.pkg,a.serial); out['apk_path']=apk_path
    if apk_path:
        dest=cd/'apk'/f'{a.pkg}.apk'; pull=adbmod.adb(['pull',apk_path,str(dest)],a.serial,timeout=120); out['pull']=pull.to_dict()
        if dest.exists():
            record_evidence(cd,dest,'apk'); completed.append('apk-pulled'); st=analyze_file(dest,cd/'static'); findings_from_static(st,cd); out['static']=st; completed+=['static-strings','manifest']
    if a.profile=='deep': out['dynamic']={'logcat':logcat_capture(cd/'dynamic',a.serial),'processes':process_snapshot(cd/'dynamic',a.serial),'storage':storage_inventory(a.pkg,cd/'dynamic',a.serial)}; completed+=['dynamic-logcat','process-snapshot','storage-inventory']
    write_json(cd/'controls.json', {'completed':sorted(set(completed))}); rep=write_reports(cd); out['reports']={'json':rep['json'],'markdown':rep['markdown']}; emit(out,a.json); return 0
def cmd_report(a):
    r=write_reports(create_case(a.case)); emit({'json':r['json'],'markdown':r['markdown'],'confidence':r['data']['confidence']},a.json); return 0
def cmd_confidence(a):
    import json as _j
    cd=Path(a.case_dir) if a.case_dir else create_case(a.case); controls=[]; cp=cd/'controls.json'
    if cp.exists(): controls=_j.loads(cp.read_text()).get('completed',[])
    emit(calculate_confidence(controls, load_findings(cd)), a.json); return 0
def cmd_doctor(a): emit({'version':__version__,'adb':command_exists('adb'),'strings':command_exists('strings'),'aapt':command_exists('aapt'),'jadx':command_exists('jadx'),'frida':command_exists('frida'),'case_root':str(DEFAULT_CASE_ROOT),'syntax':'use python -m compileall apdif' if a.topic=='syntax' else 'ok'},a.json); return 0
def cmd_release(a): emit({'pyproject':Path('pyproject.toml').exists(),'readme':Path('README.md').exists(),'license':Path('LICENSE').exists(),'entrypoint':'apdif = apdif.cli:main'},a.json); return 0
def build_parser():
    p=argparse.ArgumentParser(prog='apdif', description='APDIF: Android Permissions Debugging & Information Framework. '+HELP_GRAMMAR); p.add_argument('--version', action='version', version=f'apdif {__version__}'); sub=p.add_subparsers(dest='cmd', required=True)
    sp=sub.add_parser('device'); add_common(sp); sp.set_defaults(func=cmd_device)
    sp=sub.add_parser('app'); sp.add_argument('action', choices=['permissions','runtime-permissions','appops','apk-path','pull-apk','dump','all']); sp.add_argument('--pkg', required=True); sp.add_argument('--case'); add_common(sp); sp.set_defaults(func=cmd_app)
    sp=sub.add_parser('static'); sp.add_argument('apk'); sp.add_argument('--case'); sp.add_argument('--out'); sp.add_argument('--json', action='store_true'); sp.set_defaults(func=cmd_static)
    sp=sub.add_parser('dynamic'); sp.add_argument('action', choices=['logcat','processes','storage','all']); sp.add_argument('--pkg'); sp.add_argument('--case', required=True); sp.add_argument('--seconds', type=int, default=10); sp.add_argument('--frida-profile'); add_common(sp); sp.set_defaults(func=cmd_dynamic)
    sp=sub.add_parser('intent'); sp.add_argument('action', choices=['hints','fire']); sp.add_argument('--pkg'); sp.add_argument('--action-name', default='android.intent.action.VIEW'); sp.add_argument('--data'); add_common(sp); sp.set_defaults(func=cmd_intent)
    sp=sub.add_parser('case'); sp.add_argument('action', choices=['create','list','note','paths']); sp.add_argument('--case'); sp.add_argument('--note'); sp.add_argument('--json', action='store_true'); sp.set_defaults(func=cmd_case)
    sp=sub.add_parser('triage'); tsp=sp.add_subparsers(dest='triage_cmd', required=True); run=tsp.add_parser('run', help='apdif triage run {--pkg PKG --case CASE} [--profile deep --json --serial SERIAL]'); run.add_argument('--pkg', required=True); run.add_argument('--case', required=True); run.add_argument('--profile', choices=['baseline','deep'], default='baseline'); add_common(run); run.set_defaults(func=cmd_triage)
    sp=sub.add_parser('report'); sp.add_argument('--case', required=True); sp.add_argument('--json', action='store_true'); sp.set_defaults(func=cmd_report)
    sp=sub.add_parser('confidence'); sp.add_argument('--case'); sp.add_argument('--case-dir'); sp.add_argument('--json', action='store_true'); sp.set_defaults(func=cmd_confidence)
    sp=sub.add_parser('doctor'); sp.add_argument('topic', nargs='?', default='all'); sp.add_argument('--json', action='store_true'); sp.set_defaults(func=cmd_doctor)
    sp=sub.add_parser('release'); rsp=sp.add_subparsers(dest='release_cmd', required=True); chk=rsp.add_parser('check'); chk.add_argument('--json', action='store_true'); chk.set_defaults(func=cmd_release)
    return p
def main(argv=None):
    args=build_parser().parse_args(argv); return args.func(args)
if __name__=='__main__': raise SystemExit(main())
