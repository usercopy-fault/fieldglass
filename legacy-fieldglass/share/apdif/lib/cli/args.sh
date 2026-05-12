#!/usr/bin/env bash

require_option_value() {
  local opt="$1"
  local next="${2-}"
  if [[ -z "$next" || "$next" == --* ]]; then
    _die "Missing value for ${opt}"
  fi
}

parse_value_arg() {
  local opt="$1"
  local next="${2-}"
  require_option_value "$opt" "$next"
  printf '%s\n' "$next"
}
