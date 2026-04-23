#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-review}"; shift || true
PKG=""; APK=""; JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --apk) APK="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --json) JSON=1; shift ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) break ;;
  esac
done
emit_output(){
  local target="$1" raw_file="$2" status=0
  if [[ "$JSON" -eq 1 ]]; then
    render_module_json "webview" "$cmd" "$target" "${APDIF_SERIAL:-}" "$raw_file" || status=$?
  else
    cat "$raw_file" || status=$?
  fi
  rm -f "$raw_file"
  return "$status"
}
case "$cmd" in
  review)
    raw_file="$(mktemp)"
    if [[ -n "$APK" ]]; then
      run_tool strings -n 6 "$APK" | grep -Eai '(WebView|addJavascriptInterface|setJavaScriptEnabled|onReceivedSslError|shouldOverrideUrlLoading|allowFileAccess|allowUniversalAccessFromFileURLs|file://|content://)' > "$raw_file" || true
    elif [[ -n "$PKG" ]]; then
      pick_device
      while read -r p; do
        [[ -n "$p" ]] || continue
        tmp="$(mktemp)"
        adbq pull "$p" "$tmp" >/dev/null 2>&1 || true
        run_tool strings -n 6 "$tmp" | grep -Eai '(WebView|addJavascriptInterface|setJavaScriptEnabled|onReceivedSslError|shouldOverrideUrlLoading|allowFileAccess|allowUniversalAccessFromFileURLs|file://|content://)' >> "$raw_file" || true
        rm -f "$tmp"
      done < <(apk_paths "$PKG")
    else _die 'Use {--pkg PKG | --apk FILE}'; fi
    emit_output "${PKG:-$APK}" "$raw_file"
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif webview review' '{--pkg PKG | --apk FILE}' '[--json --serial SERIAL]' 'WebView indicator review'
    ;;
esac
