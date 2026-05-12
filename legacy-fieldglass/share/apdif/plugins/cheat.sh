#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

cmd="${1:-list}"
shift || true

case "$cmd" in
  list)
    legend_triplet
    printf '\n'
    cheat_entry 'apdif env check' '{}' '[--json]' 'dependency and SDK doctor'
    cheat_entry 'apdif device doctor' '{}' '[--serial SERIAL]' 'device and transport sanity'
    cheat_entry 'apdif app info' '{--pkg PKG}' '[--json --serial SERIAL]' 'full package dump'
    cheat_entry 'apdif app perms' '{--pkg PKG}' '[--json --serial SERIAL]' 'requested permissions'
    cheat_entry 'apdif parser manifest' '{--apk FILE}' '[]' 'normalize AndroidManifest into JSON'
    cheat_entry 'apdif triage run' '{--pkg PKG | --apk FILE}' '[--case NAME --profile PROFILE --json --serial SERIAL]' 'structured collection, findings, and report generation'
    cheat_entry 'apdif triage score' '{--case NAME}' '[--run-id RUN_ID]' 'latest run confidence summary'
    cheat_entry 'apdif report build' '{--case NAME --pkg PKG}' '[--format md|json --profile PROFILE --run-id RUN_ID]' 'render analyst-friendly report from the latest run'
    cheat_entry 'apdif assurance class' '{--case NAME}' '[--run-id RUN_ID --json]' 'assurance class derived from confidence and findings'
    cheat_entry 'apdif tui run' '{}' '[--rebuild]' 'launch the bundled Bubble Tea operator console'
    cheat_entry 'apdif compat list' '{}' '[]' 'deprecated aliases and compatibility shims'
    ;;
  grep)
    pat="${1:-}"
    [[ -n "$pat" ]] || _die 'Use {PATTERN}'
    grep -i --color=always "$pat" "${APDIF_HOME}/docs/cheatsheet.txt" || true
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif cheat list' '{}' '[]' 'list supported command patterns'
    usage_triplet 'apdif cheat grep' '{PATTERN}' '[]' 'search the local cheat sheet'
    ;;
esac
