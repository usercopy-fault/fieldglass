#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

cmd="${1:-run}"
shift || true

TUI_DIR="${APDIF_REPO_ROOT}/tui"
BIN_DIR="${APDIF_STATE}/bin"
TUI_BIN="${BIN_DIR}/apdif-tui"
REBUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rebuild) REBUILD=1; shift ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) break ;;
  esac
done

build_tui() {
  command -v go >/dev/null 2>&1 || _die 'go not found in PATH'
  [[ -d "$TUI_DIR" ]] || _die "Bundled TUI source not found at ${TUI_DIR}"
  mkdir -p "$BIN_DIR"
  (
    cd "$TUI_DIR"
    go build -o "$TUI_BIN" .
  )
}

case "$cmd" in
  path)
    printf '%s\n' "$TUI_BIN"
    ;;
  build)
    build_tui
    printf '%s\n' "$TUI_BIN"
    ;;
  run)
    if [[ "$REBUILD" -eq 1 || ! -x "$TUI_BIN" ]]; then
      build_tui
    fi
    exec "$TUI_BIN"
    ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif tui run' '{}' '[--rebuild]' 'launch the bundled Bubble Tea operator console'
    usage_triplet 'apdif tui build' '{}' '[]' 'compile the bundled TUI into the APDIF state directory'
    usage_triplet 'apdif tui path' '{}' '[]' 'print the cached TUI binary path'
    ;;
esac
