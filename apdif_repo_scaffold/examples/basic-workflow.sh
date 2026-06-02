#!/usr/bin/env bash
set -euo pipefail

PKG="${1:-com.example.app}"
CASE="${2:-example_case}"
PROFILE="${3:-default}"

apdif device doctor
apdif triage run --pkg "$PKG" --case "$CASE" --profile "$PROFILE"
apdif report build --case "$CASE" --pkg "$PKG" --profile "$PROFILE" --format md
