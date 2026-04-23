#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-help}"; shift || true
APK=""; MINLEN=6; JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk) APK="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --min-len) MINLEN="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --json) JSON=1; shift ;;
    --save) shift ;;
    *) break ;;
  esac
done
[[ -n "$APK" || "$cmd" == "help" ]] || _die 'Use {--apk FILE}'
need strings
emit_output(){
  local target="$1" raw_file="$2" status=0
  if [[ "$JSON" -eq 1 ]]; then
    render_module_json "static" "$cmd" "$target" "" "$raw_file" || status=$?
  else
    cat "$raw_file" || status=$?
  fi
  rm -f "$raw_file"
  return "$status"
}
case "$cmd" in
  manifest)
    raw_file="$(mktemp)"
    run_tool aapt dump badging "$APK" > "$raw_file"
    emit_output "$APK" "$raw_file"
    ;;
  strings)
    raw_file="$(mktemp)"
    run_tool strings -n "$MINLEN" "$APK" > "$raw_file"
    emit_output "$APK" "$raw_file"
    ;;
  secrets)
    raw_file="$(mktemp)"
    run_tool strings -n 6 "$APK" | grep -Eai '(api[_-]?key|secret|token|bearer|authorization|client[_-]?secret|aws|firebase|password|passwd)' > "$raw_file" || true
    emit_output "$APK" "$raw_file"
    ;;
  webview)
    raw_file="$(mktemp)"
    run_tool strings -n 6 "$APK" | grep -Eai '(WebView|addJavascriptInterface|setJavaScriptEnabled|onReceivedSslError|shouldOverrideUrlLoading|allowFileAccess|allowUniversalAccessFromFileURLs|file://|content://)' > "$raw_file" || true
    emit_output "$APK" "$raw_file"
    ;;
  components)
    raw_file="$(mktemp)"
    run_tool aapt dump xmltree "$APK" AndroidManifest.xml | grep -E 'E: (activity|activity-alias|service|receiver|provider)|A: android:(exported|permission|authorities|scheme|host|path|name)' > "$raw_file" || true
    emit_output "$APK" "$raw_file"
    ;;
  summary)
    raw_file="$(mktemp)"
    {
      printf '== manifest ==\n'; run_tool aapt dump badging "$APK" || true
      printf '\n== components ==\n'; run_tool aapt dump xmltree "$APK" AndroidManifest.xml | grep -E 'E: (activity|activity-alias|service|receiver|provider)|A: android:(exported|permission|authorities|scheme|host|path|name)' || true
      printf '\n== secret-like strings ==\n'; run_tool strings -n 6 "$APK" | grep -Eai '(api[_-]?key|secret|token|bearer|authorization|client[_-]?secret|aws|firebase|password|passwd)' || true
      printf '\n== webview indicators ==\n'; run_tool strings -n 6 "$APK" | grep -Eai '(WebView|addJavascriptInterface|setJavaScriptEnabled|onReceivedSslError|shouldOverrideUrlLoading|allowFileAccess|allowUniversalAccessFromFileURLs|file://|content://)' || true
    } > "$raw_file"
    emit_output "$APK" "$raw_file"
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif static manifest' '{--apk FILE}' '[--json]' 'manifest review'
    usage_triplet 'apdif static strings' '{--apk FILE}' '[--min-len N --json]' 'extract strings'
    usage_triplet 'apdif static secrets' '{--apk FILE}' '[--json]' 'secret-like constants'
    usage_triplet 'apdif static webview' '{--apk FILE}' '[--json]' 'webview risk indicators'
    usage_triplet 'apdif static components' '{--apk FILE}' '[--json]' 'component extraction'
    usage_triplet 'apdif static summary' '{--apk FILE}' '[--json --save]' 'static rollup'
    ;;
esac
