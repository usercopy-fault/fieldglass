#!/usr/bin/env bash
set -euo pipefail

: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"

_warn 'apdif report4 is deprecated; routing to apdif report'
exec "${APDIF_HOME}/plugins/report.sh" "$@" --profile baseline
