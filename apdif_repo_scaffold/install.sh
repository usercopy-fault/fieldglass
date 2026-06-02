#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$ROOT_DIR/apdif"
DEST="$HOME/.local/bin/apdif"

if [[ ! -f "$CLI" ]]; then
  echo "[-] Missing CLI at: $CLI"
  echo "    Place the apdif executable at the repository root, then rerun install.sh."
  exit 1
fi

mkdir -p "$HOME/.local/bin"
chmod +x "$CLI"
ln -sf "$CLI" "$DEST"

echo "[+] Installed: $DEST"
echo "[+] Verify with: apdif --help"
