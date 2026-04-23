#!/usr/bin/env bash
set -euo pipefail
: "${APDIF_HOME:=${HOME}/.local/share/apdif}"
source "${APDIF_HOME}/lib/common.sh"
cmd="${1:-help}"; shift || true
HOST_PORT=""; DEVICE_PORT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-port) HOST_PORT="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --device-port) DEVICE_PORT="$(arg_value_or_die "$1" "${2-}")"; shift 2 ;;
    --serial) set_serial_from_flag "$1" "${2-}"; shift 2 ;;
    *) break ;;
  esac
done
case "$cmd" in
  forwards) pick_device; adbq forward --list; printf '\n'; adbq reverse --list || true ;;
  forward) pick_device; [[ -n "$HOST_PORT" && -n "$DEVICE_PORT" ]] || _die 'Use {--host-port PORT --device-port PORT}'; adbq forward "tcp:${HOST_PORT}" "tcp:${DEVICE_PORT}" ;;
  reverse) pick_device; [[ -n "$HOST_PORT" && -n "$DEVICE_PORT" ]] || _die 'Use {--host-port PORT --device-port PORT}'; adbq reverse "tcp:${DEVICE_PORT}" "tcp:${HOST_PORT}" ;;
  sockets) pick_device; shellq ss -tulpen 2>/dev/null || shellq netstat -tulpen 2>/dev/null || true ;;
  routes) pick_device; shellq ip route ;;
  ip) pick_device; shellq ip addr ;;
  help|*)
    legend_triplet
    usage_triplet 'apdif net forwards' '{}' '[--serial SERIAL]' 'show forward and reverse rules'
    usage_triplet 'apdif net forward' '{--host-port PORT --device-port PORT}' '[--serial SERIAL]' 'host -> device TCP bridge'
    usage_triplet 'apdif net reverse' '{--host-port PORT --device-port PORT}' '[--serial SERIAL]' 'device -> host TCP bridge'
    usage_triplet 'apdif net sockets' '{}' '[--serial SERIAL]' 'socket review'
    usage_triplet 'apdif net routes' '{}' '[--serial SERIAL]' 'routing table'
    usage_triplet 'apdif net ip' '{}' '[--serial SERIAL]' 'interface inventory'
    ;;
esac
