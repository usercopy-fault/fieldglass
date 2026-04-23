#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-help}"; shift || true
PKG=""; APK=""; PERM=""; CASE_NAME="default"; JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --apk) APK="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --activity) arg_value_or_die "$1" "${2-}" >/dev/null; shift 2 ;;
    --perm) PERM="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --case|--name) CASE_NAME="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --json) JSON=1; shift ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) break ;;
  esac
done
req_pkg(){ [[ -n "$PKG" ]] || _die 'Use {--pkg PKG}'; }
emit_output(){
  local target="$1" raw_file="$2" status=0
  if [[ "$JSON" -eq 1 ]]; then
    render_module_json "app" "$cmd" "$target" "${APDIF_SERIAL:-}" "$raw_file" || status=$?
  else
    cat "$raw_file" || status=$?
  fi
  rm -f "$raw_file"
  return "$status"
}
case "$cmd" in
  focus)
    pick_device
    raw_file="$(mktemp)"
    printf '%s\n' "$(current_focus_pkg || true)" > "$raw_file"
    emit_output "${APDIF_SERIAL:-}" "$raw_file"
    ;;
  info)
    req_pkg
    pick_device
    raw_file="$(mktemp)"
    shellq dumpsys package "$PKG" > "$raw_file"
    emit_output "$PKG" "$raw_file"
    ;;
  perms)
    req_pkg
    pick_device
    raw_file="$(mktemp)"
    shellq dumpsys package "$PKG" | sed -n '/requested permissions:/,/install permissions:/p' > "$raw_file"
    emit_output "$PKG" "$raw_file"
    ;;
  runtime-perms)
    req_pkg
    pick_device
    raw_file="$(mktemp)"
    shellq dumpsys package "$PKG" | sed -n '/runtime permissions:/,/sharedUserId:/p' > "$raw_file"
    emit_output "$PKG" "$raw_file"
    ;;
  appops)
    req_pkg
    pick_device
    raw_file="$(mktemp)"
    shellq cmd appops get "$PKG" > "$raw_file"
    emit_output "$PKG" "$raw_file"
    ;;
  path)
    req_pkg
    pick_device
    raw_file="$(mktemp)"
    apk_paths "$PKG" > "$raw_file"
    emit_output "$PKG" "$raw_file"
    ;;
  pull-apk)
    req_pkg
    pick_device
    dir="$(ensure_case "$CASE_NAME")"
    mkdir -p "$dir/apk"
    raw_file="$(mktemp)"
    while read -r p; do
      [[ -n "$p" ]] || continue
      adbq pull "$p" "$dir/apk/$(basename "$p")" >/dev/null
      printf '%s/%s\n' "$dir/apk" "$(basename "$p")"
    done < <(apk_paths "$PKG") > "$raw_file"
    emit_output "$PKG" "$raw_file"
    ;;
  manifest)
    [[ -n "$APK" ]] || _die 'Use {--apk FILE}'
    raw_file="$(mktemp)"
    run_tool aapt dump badging "$APK" > "$raw_file"
    emit_output "$APK" "$raw_file"
    ;;
  exported)
    req_pkg
    pick_device
    raw_file="$(mktemp)"
    shellq dumpsys package "$PKG" | grep -Ei 'exported=|Activity|Service|Receiver|Provider|scheme=|host=|path=' > "$raw_file" || true
    emit_output "$PKG" "$raw_file"
    ;;
  deep-links)
    req_pkg
    pick_device
    raw_file="$(mktemp)"
    shellq dumpsys package "$PKG" | grep -Ei 'BROWSABLE|VIEW|scheme=|host=|path=' > "$raw_file" || true
    emit_output "$PKG" "$raw_file"
    ;;
  grant)
    req_pkg
    [[ -n "$PERM" ]] || _die 'Use {--perm PERM}'
    pick_device
    raw_file="$(mktemp)"
    status=0
    shellq pm grant "$PKG" "$PERM" > "$raw_file" 2>&1 || status=$?
    [[ -s "$raw_file" ]] || printf 'Granted %s to %s\n' "$PERM" "$PKG" > "$raw_file"
    emit_output "$PKG" "$raw_file"
    [[ "$status" -eq 0 ]] || exit "$status"
    ;;
  revoke)
    req_pkg
    [[ -n "$PERM" ]] || _die 'Use {--perm PERM}'
    pick_device
    raw_file="$(mktemp)"
    status=0
    shellq pm revoke "$PKG" "$PERM" > "$raw_file" 2>&1 || status=$?
    [[ -s "$raw_file" ]] || printf 'Revoked %s from %s\n' "$PERM" "$PKG" > "$raw_file"
    emit_output "$PKG" "$raw_file"
    [[ "$status" -eq 0 ]] || exit "$status"
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif app focus' '{}' '[--serial SERIAL]' 'focused package'
    usage_triplet 'apdif app info' '{--pkg PKG}' '[--json --serial SERIAL]' 'full package dump'
    usage_triplet 'apdif app perms' '{--pkg PKG}' '[--json --serial SERIAL]' 'requested permissions'
    usage_triplet 'apdif app runtime-perms' '{--pkg PKG}' '[--json --serial SERIAL]' 'runtime permission state'
    usage_triplet 'apdif app appops' '{--pkg PKG}' '[--json --serial SERIAL]' 'appops posture'
    usage_triplet 'apdif app path' '{--pkg PKG}' '[--serial SERIAL]' 'apk paths'
    usage_triplet 'apdif app pull-apk' '{--pkg PKG --case NAME}' '[--serial SERIAL]' 'pull installed apk'
    usage_triplet 'apdif app manifest' '{--apk FILE}' '[--json]' 'manifest badging'
    usage_triplet 'apdif app exported' '{--pkg PKG}' '[--json --serial SERIAL]' 'component surface hints'
    usage_triplet 'apdif app deep-links' '{--pkg PKG}' '[--json --serial SERIAL]' 'browsable surface hints'
    usage_triplet 'apdif app grant' '{--pkg PKG --perm PERM}' '[--serial SERIAL]' 'grant runtime perm'
    usage_triplet 'apdif app revoke' '{--pkg PKG --perm PERM}' '[--serial SERIAL]' 'revoke runtime perm'
    ;;
esac
