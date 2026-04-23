#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-help}"; shift || true
JSON=0
THIRD_PARTY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial)
      set_serial_from_flag "$1" "${2-}"
      shift 2
      ;;
    --json)
      JSON=1
      shift
      ;;
    --third-party)
      THIRD_PARTY=1
      shift
      ;;
    *)
      break
      ;;
  esac
done

emit_output(){
  local target="$1" raw_file="$2" status=0
  if [[ "$JSON" -eq 1 ]]; then
    render_module_json "device" "$cmd" "$target" "${APDIF_SERIAL:-}" "$raw_file" || status=$?
  else
    cat "$raw_file" || status=$?
  fi
  rm -f "$raw_file"
  return "$status"
}

case "$cmd" in
  doctor)
    pick_device
    raw_file="$(mktemp)"
    {
      printf '== adb ==\n'; adb version
      printf '\n== devices ==\n'; adb devices -l
      printf '\n== build ==\n'; shellq getprop ro.product.manufacturer; shellq getprop ro.product.model; shellq getprop ro.build.version.release; shellq getprop ro.build.version.sdk
      printf '\n== shell id ==\n'; shellq id
      printf '\n== toybox ==\n'; shellq 'toybox | head -n 40' || true
    } > "$raw_file"
    emit_output "${APDIF_SERIAL:-}" "$raw_file"
    ;;
  info)
    pick_device
    raw_file="$(mktemp)"
    {
      printf 'Serial: %s\n' "${APDIF_SERIAL:-unknown}"
      printf 'Manufacturer: %s\n' "$(shellq getprop ro.product.manufacturer)"
      printf 'Model: %s\n' "$(shellq getprop ro.product.model)"
      printf 'Android: %s\n' "$(shellq getprop ro.build.version.release)"
      printf 'SDK: %s\n' "$(shellq getprop ro.build.version.sdk)"
      printf 'Focus: %s\n' "$(current_focus_pkg || true)"
    } > "$raw_file"
    emit_output "${APDIF_SERIAL:-}" "$raw_file"
    ;;
  props)
    pick_device
    raw_file="$(mktemp)"
    shellq getprop | sort > "$raw_file"
    emit_output "${APDIF_SERIAL:-}" "$raw_file"
    ;;
  packages)
    pick_device
    raw_file="$(mktemp)"
    if [[ "$THIRD_PARTY" -eq 1 ]]; then
      shellq pm list packages -3 | sed 's/^package://' > "$raw_file"
    else
      shellq pm list packages | sed 's/^package://' > "$raw_file"
    fi
    emit_output "$([[ "$THIRD_PARTY" -eq 1 ]] && printf 'third-party' || printf 'all')" "$raw_file"
    ;;
  toybox)
    pick_device
    raw_file="$(mktemp)"
    shellq toybox > "$raw_file"
    emit_output "${APDIF_SERIAL:-}" "$raw_file"
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif device doctor' '{}' '[--serial SERIAL]' 'device and transport sanity'
    usage_triplet 'apdif device info' '{}' '[--serial SERIAL]' 'device identity summary'
    usage_triplet 'apdif device props' '{}' '[--serial SERIAL]' 'all getprop values'
    usage_triplet 'apdif device packages' '{}' '[--third-party --serial SERIAL]' 'installed packages'
    usage_triplet 'apdif device toybox' '{}' '[--serial SERIAL]' 'available toybox applets'
    ;;
esac
