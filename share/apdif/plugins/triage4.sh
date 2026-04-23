#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

_warn 'apdif triage4 is deprecated; routing to apdif triage'
exec "${APDIF_HOME}/plugins/triage.sh" "$@" --profile baseline
