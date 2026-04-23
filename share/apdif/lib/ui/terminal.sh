#!/usr/bin/env bash

is_tty() {
  [[ -t 1 ]]
}

c_reset=''
c_cmd=''
c_opt=''
c_flag=''
c_dim=''
c_ok=''
c_warn=''
c_err=''

if is_tty; then
  c_reset='\033[0m'
  c_cmd='\033[1;38;5;45m'
  c_opt='\033[1;38;5;214m'
  c_flag='\033[1;38;5;141m'
  c_dim='\033[2m'
  c_ok='\033[32m'
  c_warn='\033[33m'
  c_err='\033[31m'
fi

paint_cmd() { printf "${c_cmd}%s${c_reset}" "$1"; }
paint_opt() { printf "${c_opt}%s${c_reset}" "$1"; }
paint_flag() { printf "${c_flag}%s${c_reset}" "$1"; }
paint_dim() { printf "${c_dim}%s${c_reset}" "$1"; }
_ok() { printf "${c_ok}[+] %s${c_reset}\n" "$*"; }
_warn() { printf "${c_warn}[-] %s${c_reset}\n" "$*" >&2; }
_die() { printf "${c_err}[!] %s${c_reset}\n" "$*" >&2; exit 1; }

legend_triplet() {
  printf 'Legend: '
  paint_cmd '(cmd)'
  printf ' '
  paint_opt '{options}'
  printf ' '
  paint_flag '[flags]'
  printf '\n'
}

usage_triplet() {
  local c="$1"
  local o="$2"
  local f="$3"
  local d="$4"
  printf '  '
  paint_cmd "$c"
  paint_opt "$o"
  paint_flag "$f"
  printf ' '
  paint_dim "# $d"
  printf '\n'
}

cheat_entry() {
  usage_triplet "$1" "$2" "$3" "$4"
}
