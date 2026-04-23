#!/usr/bin/env bash
set -euo pipefail

manifest_to_json() {
  local apk="$1"
  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN
  run_tool aapt dump xmltree "$apk" AndroidManifest.xml > "$tmp"
  python3 "${APDIF_HOME}/normalizers/manifest_aapt.py" "$tmp" "EV-PARSER" "$(basename "$apk")"
}
