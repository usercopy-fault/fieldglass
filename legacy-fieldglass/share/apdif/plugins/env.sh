#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

cmd="${1:-help}"
shift || true

JSON=0
COMMAND_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --command) COMMAND_NAME="$(parse_value_arg "$1" "${2-}")"; shift 2 ;;
    *) break ;;
  esac
done

emit_output() {
  local raw_file="$1"
  local status=0
  if [[ "$JSON" -eq 1 ]]; then
    render_module_json "env" "check" "${COMMAND_NAME:-host}" "" "$raw_file" || status=$?
  else
    cat "$raw_file" || status=$?
  fi
  rm -f "$raw_file"
  return "$status"
}

case "$cmd" in
  doctor|check)
    raw_file="$(mktemp)"
    {
      command_name="${COMMAND_NAME:-host}"
      declare -a required_tools optional_tools
      case "$command_name" in
        triage.run)
          required_tools=(python3 adb aapt strings)
          optional_tools=(frida jq)
          ;;
        report.build)
          required_tools=(python3)
          optional_tools=(jq)
          ;;
        parser.manifest)
          required_tools=(python3 aapt)
          optional_tools=()
          ;;
        *)
          required_tools=(python3)
          optional_tools=(jq rg fd sqlite3)
          ;;
      esac
      printf 'Target command: %s\n' "$command_name"
      printf '== REQUIRED ==\n'
      for tool in "${required_tools[@]}"; do
        if resolved="$(resolve_tool_path "$tool" 2>/dev/null)"; then
          printf '[FOUND] %s -> %s\n' "$tool" "$resolved"
        else
          printf '[MISSING] %s\n' "$tool"
        fi
      done
      printf '\n== OPTIONAL ==\n'
      for tool in "${optional_tools[@]}"; do
        if resolved="$(resolve_tool_path "$tool" 2>/dev/null)"; then
          printf '[FOUND] %s -> %s\n' "$tool" "$resolved"
        else
          printf '[OPTIONAL] %s\n' "$tool"
        fi
      done
    } > "$raw_file"
    emit_output "$raw_file"
    ;;
  install-hints)
    cat <<HINTS
Arch package hints:
  sudo pacman -S android-tools android-sdk-build-tools android-sdk-cmdline-tools-latest jq ripgrep fd sqlite
  yay -S jadx-bin
Ensure Android build-tools are on PATH if you want direct aapt/aapt2 invocation:
  export PATH="$HOME/Android/Sdk/build-tools/37.0.0:$HOME/Android/Sdk/cmdline-tools/latest/bin:$PATH"
Python tooling:
  python -m venv ~/venvs/mobile
  source ~/venvs/mobile/bin/activate
  pip install frida-tools objection
HINTS
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif env check' '{}' '[--command host|triage.run|report.build|parser.manifest --json]' 'show exact host dependencies for a command path'
    usage_triplet 'apdif env install-hints' '{}' '[]' 'Arch installation hints'
    ;;
esac
