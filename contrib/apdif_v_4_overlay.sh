#!/usr/bin/env bash
set -euo pipefail

APDIF_HOME="${HOME}/.local/share/apdif"
APDIF_BIN="${HOME}/.local/bin"
mkdir -p "$APDIF_HOME/schemas" "$APDIF_HOME/frida/profiles" "$APDIF_HOME/lib" "$APDIF_HOME/plugins"

cat > "$APDIF_HOME/schemas/finding.schema.json" <<'EOF'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "APDIF Finding",
  "type": "object",
  "required": ["id","package","severity","title","status","generated_at","evidence"],
  "properties": {
    "id": {"type":"string"},
    "package": {"type":"string"},
    "severity": {"type":"string","enum":["critical","high","medium","low","info","unknown","gate"]},
    "title": {"type":"string"},
    "status": {"type":"string","enum":["observed","not_observed","needs_review","pass","fail"]},
    "generated_at": {"type":"string"},
    "evidence": {"type":"string"},
    "control_id": {"type":"string"},
    "source_type": {"type":"string"},
    "source_path": {"type":"string"},
    "line_refs": {"type":"array","items":{"type":"string"}},
    "tags": {"type":"array","items":{"type":"string"}}
  },
  "additionalProperties": true
}
EOF

cat > "$APDIF_HOME/schemas/evidence.schema.json" <<'EOF'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "APDIF Evidence Item",
  "type": "object",
  "required": ["kind","path","timestamp"],
  "properties": {
    "kind": {"type":"string"},
    "path": {"type":"string"},
    "note": {"type":"string"},
    "timestamp": {"type":"string"},
    "control_id": {"type":"string"},
    "sha256": {"type":"string"}
  },
  "additionalProperties": true
}
EOF

cat > "$APDIF_HOME/frida/profiles/baseline.js" <<'EOF'
Java.perform(function () {
  const Log = function(msg) { console.log('[APDIF][baseline] ' + msg); };
  try {
    const WebView = Java.use('android.webkit.WebView');
    WebView.loadUrl.overload('java.lang.String').implementation = function (u) {
      Log('WebView.loadUrl(String): ' + u);
      return this.loadUrl(u);
    };
  } catch (e) { Log('WebView hook unavailable: ' + e); }
  try {
    const Intent = Java.use('android.content.Intent');
    Intent.setData.overload('android.net.Uri').implementation = function (u) {
      Log('Intent.setData: ' + u);
      return this.setData(u);
    };
  } catch (e) { Log('Intent hook unavailable: ' + e); }
});
EOF

cat > "$APDIF_HOME/frida/profiles/sslpin-observe.js" <<'EOF'
Java.perform(function () {
  const Log = function(msg) { console.log('[APDIF][sslpin-observe] ' + msg); };
  try {
    const HttpsURLConnection = Java.use('javax.net.ssl.HttpsURLConnection');
    HttpsURLConnection.setDefaultHostnameVerifier.implementation = function(v) {
      Log('setDefaultHostnameVerifier invoked');
      return this.setDefaultHostnameVerifier(v);
    };
  } catch (e) { Log('HttpsURLConnection hook unavailable: ' + e); }
  try {
    const SSLContext = Java.use('javax.net.ssl.SSLContext');
    SSLContext.init.implementation = function(km, tm, sr) {
      Log('SSLContext.init invoked');
      return this.init(km, tm, sr);
    };
  } catch (e) { Log('SSLContext hook unavailable: ' + e); }
});
EOF

cat > "$APDIF_HOME/lib/hash.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    python3 - "$1" <<'PY'
import hashlib,sys
h=hashlib.sha256()
with open(sys.argv[1],'rb') as f:
    for b in iter(lambda:f.read(1024*1024),b''):
        h.update(b)
print(h.hexdigest())
PY
  fi
}
EOF
chmod +x "$APDIF_HOME/lib/hash.sh"

cat > "$APDIF_HOME/lib/parser.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
manifest_to_json() {
  local apk="$1"
  python3 - "$apk" <<'PY'
import json,re,subprocess,sys
apk=sys.argv[1]
try:
    out=subprocess.check_output(['aapt','dump','xmltree',apk,'AndroidManifest.xml'], text=True, stderr=subprocess.DEVNULL)
except Exception:
    print(json.dumps({'components':[], 'deeplinks':[], 'permissions':[]}))
    raise SystemExit
components=[]
permissions=[]
deeplinks=[]
current=None
for line in out.splitlines():
    s=line.strip()
    m=re.match(r'E: (activity|activity-alias|service|receiver|provider) ', s)
    if m:
        current={'type':m.group(1), 'attrs':{}}
        components.append(current)
        continue
    if s.startswith('E: uses-permission'):
        current={'type':'uses-permission','attrs':{}}
        continue
    am=re.match(r'A: android:([\w.]+).*?="([^"]*)"', s)
    if am:
        k,v=am.group(1),am.group(2)
        if current and current.get('type') in {'activity','activity-alias','service','receiver','provider'}:
            current['attrs'][k]=v
            if k in {'scheme','host','path'}:
                deeplinks.append({k:v})
        elif current and current.get('type')=='uses-permission' and k=='name':
            permissions.append(v)
print(json.dumps({'components':components,'deeplinks':deeplinks,'permissions':permissions}, indent=2))
PY
}
EOF
chmod +x "$APDIF_HOME/lib/parser.sh"

cat > "$APDIF_HOME/plugins/schema.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "${HOME}/.local/share/apdif/lib/common.sh"
cmd="${1:-help}"; shift || true
FILE=""; TYPE="finding"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  show) cat "${HOME}/.local/share/apdif/schemas/${TYPE}.schema.json" ;;
  validate)
    [[ -n "$FILE" ]] || _die 'Use {--file FILE}'
    python3 - "$FILE" "$TYPE" <<'PY'
import json,sys
obj=json.load(open(sys.argv[1]))
type_=sys.argv[2]
required={
 'finding':['id','package','severity','title','status','generated_at','evidence'],
 'evidence':['kind','path','timestamp']
}[type_]
missing=[k for k in required if k not in obj]
if missing:
    print('invalid')
    print('missing:', ', '.join(missing))
    raise SystemExit(1)
print('valid')
PY
    ;;
  *)
    legend_triplet
    usage_triplet 'apdif schema show' '{--type finding|evidence}' '[]' 'print bundled schema'
    usage_triplet 'apdif schema validate' '{--file FILE --type finding|evidence}' '[]' 'validate minimum required fields'
    ;;
esac
EOF
chmod +x "$APDIF_HOME/plugins/schema.sh"

cat > "$APDIF_HOME/plugins/parser.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "${HOME}/.local/share/apdif/lib/common.sh"
source "${HOME}/.local/share/apdif/lib/parser.sh"
cmd="${1:-help}"; shift || true
APK=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk) APK="$2"; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  manifest)
    [[ -n "$APK" ]] || _die 'Use {--apk FILE}'
    manifest_to_json "$APK"
    ;;
  *)
    legend_triplet
    usage_triplet 'apdif parser manifest' '{--apk FILE}' '[]' 'parse AndroidManifest into normalized JSON'
    ;;
esac
EOF
chmod +x "$APDIF_HOME/plugins/parser.sh"

cat > "$APDIF_HOME/plugins/frida-profile.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "${HOME}/.local/share/apdif/lib/common.sh"
cmd="${1:-help}"; shift || true
PKG=""; PROFILE="baseline"; SPAWN=0; PAUSE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --spawn) SPAWN=1; shift ;;
    --pause) PAUSE=1; shift ;;
    --serial) export APDIF_SERIAL="$2"; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  list) find "${HOME}/.local/share/apdif/frida/profiles" -maxdepth 1 -type f -name '*.js' -printf '%f\n' | sort ;;
  run)
    [[ -n "$PKG" ]] || _die 'Use {--pkg PKG}'
    script="${HOME}/.local/share/apdif/frida/profiles/${PROFILE}.js"
    [[ -f "$script" ]] || _die "Unknown profile: $PROFILE"
    command -v frida >/dev/null 2>&1 || _die 'frida not found in PATH'
    if [[ "$SPAWN" -eq 1 ]]; then exec frida -U ${PAUSE:+--pause} -f "$PKG" -l "$script"; else exec frida -U -n "$PKG" -l "$script"; fi
    ;;
  *)
    legend_triplet
    usage_triplet 'apdif frida-profile list' '{}' '[]' 'list bundled Frida profiles'
    usage_triplet 'apdif frida-profile run' '{--pkg PKG --profile PROFILE}' '[--spawn --pause --serial SERIAL]' 'run a bundled Frida profile'
    ;;
esac
EOF
chmod +x "$APDIF_HOME/plugins/frida-profile.sh"

cat > "$APDIF_HOME/plugins/finding.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "${HOME}/.local/share/apdif/lib/common.sh"
source "${HOME}/.local/share/apdif/lib/findings.sh"
cmd="${1:-help}"; shift || true
CASE_NAME="default"; PKG=""; ID=""; SEV="unknown"; TITLE=""; STATUS="observed"; EVID=""; CONTROL_ID=""; SOURCE_TYPE=""; SOURCE_PATH=""; TAGS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case|--name) CASE_NAME="$2"; shift 2 ;;
    --pkg) PKG="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --severity) SEV="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --evidence) EVID="$2"; shift 2 ;;
    --control-id) CONTROL_ID="$2"; shift 2 ;;
    --source-type) SOURCE_TYPE="$2"; shift 2 ;;
    --source-path) SOURCE_PATH="$2"; shift 2 ;;
    --tags) TAGS="$2"; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  add)
    [[ -n "$PKG" && -n "$ID" && -n "$TITLE" ]] || _die 'Use {--case NAME --pkg PKG --id ID --title TITLE}'
    out="$(finding_emit "$CASE_NAME" "$PKG" "$ID" "$SEV" "$TITLE" "$STATUS" "$EVID")"
    python3 - "$out" "$CONTROL_ID" "$SOURCE_TYPE" "$SOURCE_PATH" "$TAGS" <<'PY'
import json,sys
p,cid,stype,spath,tags=sys.argv[1:6]
obj=json.load(open(p))
if cid: obj['control_id']=cid
if stype: obj['source_type']=stype
if spath: obj['source_path']=spath
if tags: obj['tags']=[x.strip() for x in tags.split(',') if x.strip()]
open(p,'w').write(json.dumps(obj, indent=2))
print(p)
PY
    ;;
  list) finding_summary "$CASE_NAME" ;;
  *)
    legend_triplet
    usage_triplet 'apdif finding add' '{--case NAME --pkg PKG --id ID --title TITLE}' '[--severity SEV --status STATUS --evidence TEXT --control-id ID --source-type TYPE --source-path FILE --tags a,b]' 'add normalized finding'
    usage_triplet 'apdif finding list' '{--case NAME}' '[]' 'list case findings as JSON'
    ;;
esac
EOF
chmod +x "$APDIF_HOME/plugins/finding.sh"

cat > "$APDIF_HOME/plugins/static3.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "${HOME}/.local/share/apdif/lib/common.sh"
source "${HOME}/.local/share/apdif/lib/evidence.sh"
cmd="${1:-help}"; shift || true
APK=""; CASE_NAME="default"; JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk) APK="$2"; shift 2 ;;
    --case|--name) CASE_NAME="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) break ;;
  esac
done
case "$cmd" in
  run)
    [[ -n "$APK" ]] || _die 'Use {--apk FILE}'
    dir="$(ensure_case "$CASE_NAME")"
    pjson="$dir/artifacts/parser_manifest.json"
    sjson="$dir/artifacts/static2_run.json"
    "$APDIF_HOME/plugins/parser.sh" manifest --apk "$APK" > "$pjson"
    "$APDIF_HOME/plugins/static2.sh" run --apk "$APK" --case "$CASE_NAME" --json > "$sjson"
    case_add_evidence "$CASE_NAME" parser "$pjson" 'normalized manifest json' >/dev/null
    case_add_evidence "$CASE_NAME" static "$sjson" 'static2 structured json' >/dev/null
    python3 - "$pjson" "$CASE_NAME" "$(basename "$APK")" <<'PY'
import json,sys,subprocess
p=json.load(open(sys.argv[1]))
case_name,pkg=sys.argv[2],sys.argv[3]
for c in p.get('components',[]):
    attrs=c.get('attrs',{})
    if attrs.get('exported')=='true':
        ev=json.dumps(c)
        subprocess.run(['bash','-lc', f'''apdif finding add --case {case_name!r} --pkg {pkg!r} --id STATIC-COMP-EXPORTED-001 --title "Exported component in parsed manifest" --severity medium --status observed --evidence {ev!r} --control-id CTRL-EXPORT-001 --source-type manifest-json --source-path {sys.argv[1]!r} --tags exported,manifest'''], check=True)
        break
PY
    if [[ "$JSON" -eq 1 ]]; then
      python3 - "$pjson" "$sjson" <<'PY'
import json,sys
print(json.dumps({'manifest':json.load(open(sys.argv[1])), 'static':json.load(open(sys.argv[2]))}, indent=2))
PY
    else
      printf 'Manifest JSON: %s\nStatic JSON: %s\n' "$pjson" "$sjson"
    fi
    ;;
  *)
    legend_triplet
    usage_triplet 'apdif static3 run' '{--apk FILE --case NAME}' '[--json]' 'parser-backed static assessment with evidence'
    ;;
esac
EOF
chmod +x "$APDIF_HOME/plugins/static3.sh"

cat > "$APDIF_HOME/plugins/assurance.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "${HOME}/.local/share/apdif/lib/common.sh"
cmd="${1:-help}"; shift || true
CASE_NAME="default"; PROFILE="baseline"; JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case|--name) CASE_NAME="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) break ;;
  esac
done
case "$cmd" in
  class)
    conf="$($APDIF_HOME/plugins/confidence.sh score --case "$CASE_NAME" --profile "$PROFILE" --json)"
    APDIF_CONF="$conf" python3 - <<'PY'
import json,os
c=json.loads(os.environ['APDIF_CONF'])
score=c['score']; unmet=len(c['unmet_controls']); sev=c['severity_counts']
if score < 50 or sev.get('critical',0) or sev.get('high',0)>=2:
    cls='insufficient'
elif score < 70 or unmet > 3:
    cls='baseline-reviewed'
elif score < 90 or unmet > 0:
    cls='deep-reviewed'
else:
    cls='high-confidence-in-scope'
out={'assurance_class':cls,'confidence':c}
if os.environ.get('APDIF_JSON')=='1':
    print(json.dumps(out, indent=2))
else:
    print(f'Assurance class: {cls}')
    print(f'Score: {score}/100')
    print(f'Unmet controls: {unmet}')
PY
    ;;
  *)
    legend_triplet
    usage_triplet 'apdif assurance class' '{--case NAME --profile PROFILE}' '[--json]' 'map confidence into an assurance class'
    ;;
esac
EOF
chmod +x "$APDIF_HOME/plugins/assurance.sh"

cat > "$APDIF_HOME/plugins/report4.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "${HOME}/.local/share/apdif/lib/common.sh"
source "${HOME}/.local/share/apdif/lib/findings.sh"
source "${HOME}/.local/share/apdif/lib/evidence.sh"
cmd="${1:-help}"; shift || true
CASE_NAME="default"; PKG=""; PROFILE="baseline"; FORMAT="md"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case|--name) CASE_NAME="$2"; shift 2 ;;
    --pkg) PKG="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  build)
    conf="$($APDIF_HOME/plugins/confidence.sh score --case "$CASE_NAME" --profile "$PROFILE" --json)"
    assur="$(APDIF_JSON=1 $APDIF_HOME/plugins/assurance.sh class --case "$CASE_NAME" --profile "$PROFILE")"
    evid="$(case_list_evidence "$CASE_NAME")"
    fins="$(finding_summary "$CASE_NAME")"
    if [[ "$FORMAT" == "json" ]]; then
      APDIF_CONF="$conf" APDIF_ASSUR="$assur" APDIF_EVID="$evid" APDIF_FINS="$fins" python3 - <<'PY'
import json,os
print(json.dumps({'confidence': json.loads(os.environ['APDIF_CONF']), 'assurance': json.loads(os.environ['APDIF_ASSUR']), 'evidence': json.loads(os.environ['APDIF_EVID']), 'findings': json.loads(os.environ['APDIF_FINS'])}, indent=2))
PY
      exit 0
    fi
    dir="$(ensure_case "$CASE_NAME")"
    out="$dir/reports/${PKG:-case}_v4_$(date +%Y%m%d_%H%M%S).md"
    report_header 'APDIF v4 Assurance Report' > "$out"
    cat >> "$out" <<REPORT
Case: ${CASE_NAME}
Package: ${PKG}
Profile: ${PROFILE}

## Assurance

\`\`\`json
${assur}
\`\`\`

## Confidence

\`\`\`json
${conf}
\`\`\`

## Evidence Index

\`\`\`json
${evid}
\`\`\`

## Findings

\`\`\`json
${fins}
\`\`\`

## Decision boundary
This report is in-scope assurance only.
It does not claim universal safety, absence of unknown vulnerabilities, or correctness outside completed controls.
REPORT
    _ok "Wrote $out"
    ;;
  *)
    legend_triplet
    usage_triplet 'apdif report4 build' '{--case NAME --pkg PKG --profile PROFILE}' '[--format md|json]' 'build v4 assurance report'
    ;;
esac
EOF
chmod +x "$APDIF_HOME/plugins/report4.sh"

cat > "$APDIF_HOME/plugins/triage4.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source "${HOME}/.local/share/apdif/lib/common.sh"
source "${HOME}/.local/share/apdif/lib/evidence.sh"
cmd="${1:-help}"; shift || true
PKG=""; APK=""; CASE_NAME="default"; PROFILE="baseline"; JSON=0; OLD_APK=""; NEW_APK=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$2"; shift 2 ;;
    --apk) APK="$2"; shift 2 ;;
    --old-apk) OLD_APK="$2"; shift 2 ;;
    --new-apk) NEW_APK="$2"; shift 2 ;;
    --case|--name) CASE_NAME="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --serial) export APDIF_SERIAL="$2"; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  run)
    dir="$(ensure_case "$CASE_NAME")"
    if [[ -n "$PKG" || -n "$APK" ]]; then
      "$APDIF_HOME/plugins/triage3.sh" run ${PKG:+--pkg "$PKG"} ${APK:+--apk "$APK"} --case "$CASE_NAME" --profile "$PROFILE" ${JSON:+--json} ${APDIF_SERIAL:+--serial "$APDIF_SERIAL"} > "$dir/artifacts/triage3_run.txt"
      case_add_evidence "$CASE_NAME" triage "$dir/artifacts/triage3_run.txt" 'triage3 pipeline output' >/dev/null
    fi
    if [[ -n "$APK" ]]; then
      "$APDIF_HOME/plugins/static3.sh" run --apk "$APK" --case "$CASE_NAME" ${JSON:+--json} > "$dir/artifacts/static3_run.txt"
      case_add_evidence "$CASE_NAME" static "$dir/artifacts/static3_run.txt" 'static3 pipeline output' >/dev/null
    fi
    if [[ -n "$PKG" ]] && command -v frida >/dev/null 2>&1; then
      printf 'Frida profiles available:\n' > "$dir/artifacts/frida_profiles.txt"
      "$APDIF_HOME/plugins/frida-profile.sh" list >> "$dir/artifacts/frida_profiles.txt"
      case_add_evidence "$CASE_NAME" frida "$dir/artifacts/frida_profiles.txt" 'bundled frida profile list' >/dev/null
    fi
    if [[ -n "$OLD_APK" && -n "$NEW_APK" ]]; then
      "$APDIF_HOME/plugins/diff.sh" apk --old-apk "$OLD_APK" --new-apk "$NEW_APK" --case "$CASE_NAME" ${JSON:+--json} > "$dir/artifacts/apk_diff_v4.txt"
      case_add_evidence "$CASE_NAME" diff "$dir/artifacts/apk_diff_v4.txt" 'apk diff v4' >/dev/null
    fi
    if [[ "$JSON" -eq 1 ]]; then
      APDIF_JSON=1 "$APDIF_HOME/plugins/assurance.sh" class --case "$CASE_NAME" --profile "$PROFILE"
    else
      "$APDIF_HOME/plugins/assurance.sh" class --case "$CASE_NAME" --profile "$PROFILE"
    fi
    ;;
  *)
    legend_triplet
    usage_triplet 'apdif triage4 run' '{--pkg PKG | --apk FILE --case NAME --profile PROFILE}' '[--json --serial SERIAL]' 'run v4 parser-backed assurance workflow'
    usage_triplet 'apdif triage4 run' '{--old-apk FILE --new-apk FILE --case NAME --profile PROFILE}' '[--json]' 'run version-aware assurance workflow'
    ;;
esac
EOF
chmod +x "$APDIF_HOME/plugins/triage4.sh"

python3 - "$APDIF_BIN/apdif" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1])
s=p.read_text()
old='device|app|net|trace|raw|static|dynamic|storage|webview|intent|triage|report|cheat|env|case|static2|dynamic2|triage2|report2|jadx|control|evidence|diff|confidence|report3|triage3'
new='device|app|net|trace|raw|static|dynamic|storage|webview|intent|triage|report|cheat|env|case|static2|dynamic2|triage2|report2|jadx|control|evidence|diff|confidence|report3|triage3|schema|parser|frida-profile|finding|static3|assurance|report4|triage4'
s=s.replace(old,new)
p.write_text(s)
PY

python3 - "$APDIF_HOME/docs/cheatsheet.txt" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1])
append='''

APDIF v4 Assurance Layer
------------------------
apdif schema show{--type finding|evidence}[]
apdif schema validate{--file FILE --type finding|evidence}[]
apdif parser manifest{--apk FILE}[]
apdif frida-profile list{}[]
apdif frida-profile run{--pkg PKG --profile PROFILE}[--spawn --pause --serial SERIAL]
apdif finding add{--case NAME --pkg PKG --id ID --title TITLE}[--severity SEV --status STATUS --evidence TEXT --control-id ID --source-type TYPE --source-path FILE --tags a,b]
apdif finding list{--case NAME}[]
apdif static3 run{--apk FILE --case NAME}[--json]
apdif assurance class{--case NAME --profile PROFILE}[--json]
apdif triage4 run{--pkg PKG | --apk FILE --case NAME --profile PROFILE}[--json --serial SERIAL]
apdif triage4 run{--old-apk FILE --new-apk FILE --case NAME --profile PROFILE}[--json]
apdif report4 build{--case NAME --pkg PKG --profile PROFILE}[--format md|json]
'''
p.write_text(p.read_text()+append)
PY

echo 'APDIF v4 overlay added: schemas, parser-backed manifest analysis, Frida profiles, assurance classes, report4, triage4.'
