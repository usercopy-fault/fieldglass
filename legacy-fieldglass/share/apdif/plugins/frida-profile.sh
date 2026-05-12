#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-help}"; shift || true
PKG=""; PROFILE="baseline"; SPAWN=0; PAUSE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --profile) PROFILE="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    --spawn) SPAWN=1; shift ;;
    --pause) PAUSE=1; shift ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  list) find "${APDIF_HOME}/frida/profiles" -maxdepth 1 -type f -name '*.js' -printf '%f\n' | sort ;;
  run)
    [[ -n "$PKG" ]] || _die 'Use {--pkg PKG}'
    script="${APDIF_HOME}/frida/profiles/${PROFILE}.js"
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
