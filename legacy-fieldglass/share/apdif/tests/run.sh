#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/dopamine/Downloads/apdif/share/apdif"
BIN="/home/dopamine/Downloads/apdif/bin/apdif"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_HOME="$TMP_DIR/home"
FAKE_STATE="$TMP_DIR/state"
FAKE_CASES="$TMP_DIR/cases"
FAKEBIN="$TMP_DIR/fakebin"
FAKE_SDK="$TMP_DIR/sdk"
FAKE_APK_FILE="$TMP_DIR/fake.apk"
mkdir -p "$FAKE_HOME" "$FAKE_STATE" "$FAKE_CASES" "$FAKEBIN" "$FAKE_SDK/build-tools/37.0.0" "$FAKE_SDK/cmdline-tools/latest/bin"
printf 'WebView addJavascriptInterface shouldOverrideUrlLoading fake-token-value\n' > "$FAKE_APK_FILE"

cat > "$FAKEBIN/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1-}" == "-s" ]]; then
  shift 2
fi

cmd="${1-}"
shift || true

dump_package(){
  local pkg="$1"
  cat <<PKG
Packages:
  Package [$pkg] (123abc):
    requested permissions:
      android.permission.INTERNET
      android.permission.WRITE_SECURE_SETTINGS
      moe.shizuku.manager.permission.MANAGER
    install permissions:
      android.permission.INTERNET: granted=true
    runtime permissions:
      android.permission.POST_NOTIFICATIONS: granted=true, flags=[ USER_SENSITIVE_WHEN_GRANTED ]
    sharedUserId:
Activity Resolver Table:
        aaaa111 $pkg/com.example.MainActivity filter 123
Receiver Resolver Table:
        bbbb222 $pkg/com.example.BootReceiver filter 456
Service Resolver Table:
        cccc333 $pkg/com.example.SyncService filter 789
Registered ContentProviders:
  $pkg/com.example.Provider:
    Provider{111111 $pkg/com.example.Provider}
ContentProvider Authorities:
    Provider{111111 $pkg/com.example.Provider}
    scheme=https
    host=example.test
    path=/open
    android.intent.category.BROWSABLE
    android.intent.action.VIEW
PKG
}

case "$cmd" in
  version)
    echo "Android Debug Bridge version 1.0.41"
    ;;
  devices)
    echo "List of devices attached"
    echo "FAKE123 device usb:1-1 product:test model:Pixel_Test device:test transport_id:1"
    ;;
  pull)
    src="${1-}"
    dest="${2-}"
    cp "${FAKE_APK_FILE:?}" "$dest"
    ;;
  shell)
    joined="$*"
    case "$joined" in
      "getprop ro.product.manufacturer") echo "Google" ;;
      "getprop ro.product.model") echo "Pixel Test" ;;
      "getprop ro.build.version.release") echo "16" ;;
      "getprop ro.build.version.sdk") echo "36" ;;
      "id") echo "uid=2000(shell) gid=2000(shell) groups=2000(shell)" ;;
      "toybox | head -n 40") printf 'ls\nps\nfind\n' ;;
      "dumpsys window"*) echo "mCurrentFocus=Window{12345 u0 com.example.app/com.example.MainActivity}" ;;
      "pm list packages -3") printf 'package:com.example.app\npackage:moe.shizuku.privileged.api\n' ;;
      "pm list packages") printf 'package:android\npackage:com.example.app\npackage:moe.shizuku.privileged.api\n' ;;
      "pm path com.example.app") echo "package:/data/app/com.example.app/base.apk" ;;
      "pm path moe.shizuku.privileged.api") echo "package:/data/app/moe.shizuku.privileged.api/base.apk" ;;
      "cmd appops get com.example.app"|"cmd appops get moe.shizuku.privileged.api")
        cat <<'APPOPS'
Uid mode: COARSE_LOCATION: ignore
START_FOREGROUND: allow; time=+2m ago; duration=+1s
APPOPS
        ;;
      "run-as com.example.app sh -c ls -la shared_prefs 2>/dev/null; for f in shared_prefs/*.xml; do [ -f \"\$f\" ] && echo \"--- \$f\" && sed -n \"1,200p\" \"\$f\"; done")
        printf 'total 4\n--- shared_prefs/session.xml\n<map><string name="token">abc</string></map>\n'
        ;;
      "run-as com.example.app sh -c ls -la databases 2>/dev/null")
        printf 'total 4\n-rw------- 1 app app 4096 app.db\n'
        ;;
      "run-as com.example.app sh -c find files -maxdepth 3 -type f 2>/dev/null | sort | head -n 300")
        printf 'files/config.json\nfiles/cache/session.txt\n'
        ;;
      "run-as com.example.app sh -c find . -maxdepth 3 -type f 2>/dev/null | sort | head -n 500")
        printf './files/config.json\n./databases/app.db\n'
        ;;
      "run-as moe.shizuku.privileged.api sh -c ls -la shared_prefs 2>/dev/null; for f in shared_prefs/*.xml; do [ -f \"\$f\" ] && echo \"--- \$f\" && sed -n \"1,200p\" \"\$f\"; done")
        printf 'total 0\n'
        ;;
      "run-as moe.shizuku.privileged.api sh -c ls -la databases 2>/dev/null")
        printf 'total 0\n'
        ;;
      "run-as moe.shizuku.privileged.api sh -c find files -maxdepth 3 -type f 2>/dev/null | sort | head -n 300")
        printf 'files/shizuku.log\n'
        ;;
      "run-as moe.shizuku.privileged.api sh -c find . -maxdepth 3 -type f 2>/dev/null | sort | head -n 500")
        printf './files/shizuku.log\n'
        ;;
      "ps -A")
        printf 'u0_a123 1234 1 com.example.app\n'
        ;;
      "dumpsys package com.example.app")
        dump_package "com.example.app"
        ;;
      "dumpsys package moe.shizuku.privileged.api")
        dump_package "moe.shizuku.privileged.api"
        ;;
      "am start "*)
        echo "Starting: Intent { act=android.intent.action.VIEW }"
        ;;
      *)
        printf 'Unhandled fake adb shell command: %s\n' "$joined" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    printf 'Unhandled fake adb command: %s %s\n' "$cmd" "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$FAKEBIN/adb"

cat > "$FAKE_SDK/build-tools/37.0.0/aapt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "package: name='com.example.app' versionName='1.0'"
EOF
chmod +x "$FAKE_SDK/build-tools/37.0.0/aapt"

cat > "$FAKE_SDK/build-tools/37.0.0/aapt2" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "aapt2 fake"
EOF
chmod +x "$FAKE_SDK/build-tools/37.0.0/aapt2"

cat > "$FAKE_SDK/cmdline-tools/latest/bin/apkanalyzer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "apkanalyzer fake"
EOF
chmod +x "$FAKE_SDK/cmdline-tools/latest/bin/apkanalyzer"

cat > "$FAKEBIN/frida" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "frida fake"
EOF
chmod +x "$FAKEBIN/frida"

test_env(){
  env \
    HOME="$FAKE_HOME" \
    APDIF_HOME="$ROOT" \
    APDIF_STATE="$FAKE_STATE" \
    APDIF_CASES="$FAKE_CASES" \
    ANDROID_SDK_ROOT="$FAKE_SDK" \
    FAKE_APK_FILE="$FAKE_APK_FILE" \
    PATH="$FAKEBIN:$PATH" \
    "$@"
}

run_apdif(){
  test_env "$BIN" "$@"
}

run_plugin(){
  test_env "$@"
}

assert_contains(){
  local haystack="$1" needle="$2" label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'ASSERTION FAILED: %s\nExpected to find: %s\n--- output ---\n%s\n' "$label" "$needle" "$haystack" >&2
    exit 1
  fi
}

assert_json_keys(){
  local file="$1"
  python3 - "$file" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
required = ["module", "target", "device", "summary", "findings", "sections", "raw", "errors"]
missing = [key for key in required if key not in data]
if missing:
    raise SystemExit(f"Missing JSON keys: {missing}")
PY
}

doctor_help="$(run_apdif doctor--help)"
assert_contains "$doctor_help" "apdif doctor" "doctor--help should route to guidance"

bad_module_output="$(run_apdif nope 2>&1 || true)"
assert_contains "$bad_module_output" "Unknown module: nope" "unknown modules should stay explicit"
assert_contains "$bad_module_output" "APDIF command grammar" "unknown modules should include guidance"

inventory_json="$TMP_DIR/inventory.json"
run_apdif inventory --json > "$inventory_json"
assert_json_keys "$inventory_json"
python3 - "$inventory_json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["module"] == "device"
assert data["target"] == "third-party"
PY

shizuku_json="$TMP_DIR/shizuku.json"
run_apdif Shizuku --json > "$shizuku_json"
assert_json_keys "$shizuku_json"
python3 - "$shizuku_json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["module"] == "app"
assert data["target"] == "moe.shizuku.privileged.api"
PY

triage_arg_error="$(run_plugin "$ROOT/plugins/triage.sh" run --pkg 2>&1 || true)"
assert_contains "$triage_arg_error" "Missing value for --pkg" "triage parser should guard missing values"

report_arg_error="$(run_plugin "$ROOT/plugins/report.sh" build --pkg 2>&1 || true)"
assert_contains "$report_arg_error" "Missing value for --pkg" "report parser should guard missing values"

doctor_json="$TMP_DIR/doctor.json"
run_apdif doctor --json > "$doctor_json"
assert_json_keys "$doctor_json"
python3 - "$doctor_json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["module"] == "env"
assert data["summary"]["highest_severity"] in {"critical", "review", "info", "raw"}
PY

triage_json="$TMP_DIR/triage.json"
run_apdif triage run --pkg com.example.app --case case-1 --json > "$triage_json"
python3 - "$triage_json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["target"]["kind"] == "pkg"
assert data["target"]["value"] == "com.example.app"
assert data["collector_counts"]["ok"] >= 1
assert data["run_dir"].endswith(data["run_id"])
PY

run_apdif report build --case case-1 --pkg com.example.app --format md > /dev/null
report_file="$(find "$FAKE_CASES/case-1/reports" -maxdepth 1 -type f -name 'com.example.app_*.md' | sort | tail -n1)"
[[ -n "$report_file" ]] || { echo "Expected markdown report to be created" >&2; exit 1; }
report_contents="$(cat "$report_file")"
assert_contains "$report_contents" "## Executive Summary" "markdown report should include executive summary"
assert_contains "$report_contents" "### MEDIUM" "markdown report should include severity labels"
assert_contains "$report_contents" "## Raw Evidence Appendix" "markdown report should append raw evidence"
assert_contains "$report_contents" "## Exported Components" "markdown report should use friendly section titles"

overlay_help="$(run_apdif parser help)"
assert_contains "$overlay_help" "apdif parser manifest" "overlay parser module should stay wired in"

schema_help="$(run_apdif schema help)"
assert_contains "$schema_help" "apdif schema validate" "overlay schema module should stay wired in"

frida_profiles="$(run_apdif frida-profile list)"
assert_contains "$frida_profiles" "baseline.js" "overlay frida profiles should stay wired in"

hidden_short="$(run_apdif -intC)"
assert_contains "$hidden_short" "APDIF CHEAT" "hidden short alias should print the hidden cheat block"

hidden_long="$(run_apdif --intC)"
assert_contains "$hidden_long" "APDIF CHEAT" "hidden long alias should print the hidden cheat block"

hidden_named="$(run_apdif intheCloset)"
assert_contains "$hidden_named" "MOST VALUABLE COMMANDS" "hidden named command should print the full cheat block"

help_text="$(run_apdif -h)"
if [[ "$help_text" == *"intheCloset"* ]]; then
  printf 'ASSERTION FAILED: hidden command leaked into help\n%s\n' "$help_text" >&2
  exit 1
fi

tui_help="$(run_apdif tui help)"
assert_contains "$tui_help" "apdif tui run" "tui module should be exposed through the main CLI"

printf 'All APDIF regression tests passed.\n'
