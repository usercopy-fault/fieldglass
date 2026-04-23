#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

_warn 'apdif static3 is deprecated; routing to apdif triage run --apk'
exec "${APDIF_HOME}/plugins/triage.sh" run "$@"
