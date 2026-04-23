#!/usr/bin/env bash
set -euo pipefail

IFS=$'\n\t'
umask 077

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
: "${APDIF_REPO_ROOT:=$(cd "${APDIF_HOME}/../.." && pwd)}"
: "${APDIF_STATE:=${HOME}/.local/state/apdif}"
: "${APDIF_CASES:=${HOME}/cases/android}"
: "${APDIF_LOG:=${APDIF_STATE}/logs}"
: "${APDIF_RENDERER:=${APDIF_HOME}/lib/render.py}"

mkdir -p "$APDIF_HOME" "$APDIF_STATE" "$APDIF_CASES" "$APDIF_LOG"

export APDIF_VERSION="1.2.0"
export APDIF_REPO_ROOT
APDIF_DEFAULT_SERIAL="${ANDROID_SERIAL:-}"

source "${APDIF_HOME}/lib/ui/terminal.sh"
source "${APDIF_HOME}/lib/ui/markdown.sh"
source "${APDIF_HOME}/lib/cli/args.sh"
source "${APDIF_HOME}/lib/cli/deprecations.sh"
source "${APDIF_HOME}/lib/runtime/deps.sh"
source "${APDIF_HOME}/lib/runtime/adb.sh"
source "${APDIF_HOME}/lib/runtime/capture.sh"
source "${APDIF_HOME}/lib/cases.sh"
source "${APDIF_HOME}/lib/hash.sh"

arg_value_or_die() {
  local flag="$1"
  local value="${2-}"
  require_option_value "$flag" "$value"
  printf '%s' "$value"
}

set_serial_from_flag() {
  export APDIF_SERIAL
  APDIF_SERIAL="$(arg_value_or_die "$1" "${2-}")"
}

resolve_tool_path() {
  local tool="$1"
  local sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-${HOME}/Android/Sdk}}"
  local latest=""

  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    return 0
  fi

  case "$tool" in
    fd)
      if command -v fdfind >/dev/null 2>&1; then
        command -v fdfind
        return 0
      fi
      ;;
    aapt|aapt2)
      if [[ -d "${sdk_root}/build-tools" ]]; then
        latest="$(find "${sdk_root}/build-tools" -type f -name "$tool" 2>/dev/null | sort -V | tail -n1)"
      fi
      ;;
    apkanalyzer)
      latest="$(find "${sdk_root}" -type f -name apkanalyzer 2>/dev/null | sort -V | tail -n1)"
      ;;
  esac

  [[ -n "$latest" ]] || return 1
  printf '%s\n' "$latest"
}

need() {
  resolve_tool_path "$1" >/dev/null 2>&1 || _die "Missing dependency: $1"
}

run_tool() {
  local tool="$1"
  local resolved=""
  shift || true
  resolved="$(resolve_tool_path "$tool")" || _die "Missing dependency: ${tool}"
  "$resolved" "$@"
}

now() {
  date +"%Y-%m-%d_%H-%M-%S"
}

ensure_case() {
  local name="${1:-default}"
  mkdir -p \
    "${APDIF_CASES}/${name}/apk" \
    "${APDIF_CASES}/${name}/raw" \
    "${APDIF_CASES}/${name}/notes" \
    "${APDIF_CASES}/${name}/loot" \
    "${APDIF_CASES}/${name}/logs" \
    "${APDIF_CASES}/${name}/reports" \
    "${APDIF_CASES}/${name}/artifacts" \
    "${APDIF_CASES}/${name}/runs" \
    "${APDIF_CASES}/${name}/findings" \
    "${APDIF_CASES}/${name}/evidence"
  printf '%s\n' "${APDIF_CASES}/${name}"
}

usage_block() {
  printf 'APDIF command grammar\n'
  legend_triplet
  printf '\n'
  usage_triplet 'apdif cheat list' '{}' '[]' 'list supported command patterns'
  usage_triplet 'apdif device doctor' '{}' '[--serial SERIAL]' 'device, adb, toybox sanity'
  usage_triplet 'apdif app perms' '{--pkg PKG}' '[--json --serial SERIAL]' 'permission posture review'
  usage_triplet 'apdif parser manifest' '{--apk FILE}' '[]' 'normalize AndroidManifest into structured JSON'
  usage_triplet 'apdif triage run' '{--pkg PKG | --apk FILE}' '[--case NAME --profile PROFILE --json --serial SERIAL]' 'structured collection and findings pipeline'
  usage_triplet 'apdif report build' '{--case NAME --pkg PKG}' '[--format md|json --profile PROFILE]' 'build analyst-friendly report from latest run'
  usage_triplet 'apdif assurance class' '{--case NAME}' '[--run-id RUN_ID --json]' 'map confidence into an analyst-facing assurance class'
  usage_triplet 'apdif tui run' '{}' '[--rebuild]' 'launch the bundled operator TUI'
  usage_triplet 'apdif schema show' '{--type TYPE}' '[]' 'print bundled schemas'
  usage_triplet 'apdif compat list' '{}' '[]' 'list deprecated aliases and compatibility shims'
}

render_module_json() {
  local module="$1"
  local command_name="$2"
  local target="${3-}"
  local device_serial="${4-}"
  local raw_file="$5"
  python3 "$APDIF_RENDERER" module-json \
    --module "$module" \
    --command "$command_name" \
    --target "$target" \
    --device-serial "$device_serial" \
    --raw-file "$raw_file"
}

render_report_json() {
  local case_name="$1"
  local pkg="$2"
  local device_serial="${3-}"
  local raw_file="$4"
  python3 "$APDIF_RENDERER" report-json \
    --case "$case_name" \
    --pkg "$pkg" \
    --device-serial "$device_serial" \
    --raw-file "$raw_file"
}

render_report_markdown() {
  local case_name="$1"
  local pkg="$2"
  local device_serial="${3-}"
  local raw_file="$4"
  python3 "$APDIF_RENDERER" report-markdown \
    --case "$case_name" \
    --pkg "$pkg" \
    --device-serial "$device_serial" \
    --raw-file "$raw_file"
}
