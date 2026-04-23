#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

RUN_DIR=""
APK=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir) RUN_DIR="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --apk) APK="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    *) _die "Unknown option: $1" ;;
  esac
done
[[ -n "$RUN_DIR" && -n "$APK" ]] || _die 'Use {--run-dir DIR --apk FILE}'
need strings

capture_command "$RUN_DIR" "apk.strings_webview" "apk:${APK}" "text/plain" \
  bash -lc "strings -n 6 \"\$0\" | grep -Eai '(WebView|addJavascriptInterface|setJavaScriptEnabled|onReceivedSslError|shouldOverrideUrlLoading|allowFileAccess|allowUniversalAccessFromFileURLs|file://|content://)' || true" "$APK"
