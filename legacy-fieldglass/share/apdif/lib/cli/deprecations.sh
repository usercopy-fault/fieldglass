#!/usr/bin/env bash

resolve_module_alias() {
  local module="$1"
  local alias_file="${APDIF_HOME}/compat/aliases.tsv"
  [[ -f "$alias_file" ]] || {
    printf '%s\t\t\t\n' "$module"
    return 0
  }
  python3 - "$alias_file" "$module" <<'PY'
import csv
import sys

alias_file, module = sys.argv[1:3]
with open(alias_file, newline="", encoding="utf-8") as fh:
    reader = csv.DictReader(fh, delimiter="\t")
    for row in reader:
        if row["alias"] == module:
            print("\t".join([
                row["canonical"],
                row.get("deprecated_in", ""),
                row.get("remove_after", ""),
                row.get("note", ""),
            ]))
            raise SystemExit(0)
print("\t".join([module, "", "", ""]))
PY
}

warn_deprecated_module() {
  local original="$1"
  local canonical="$2"
  local deprecated_in="$3"
  local remove_after="$4"
  local note="$5"
  [[ "$original" == "$canonical" ]] && return 0
  local msg="Deprecated: apdif ${original} -> apdif ${canonical}"
  if [[ -n "$deprecated_in" || -n "$remove_after" ]]; then
    msg="${msg} (deprecated in ${deprecated_in:-unknown}"
    [[ -n "$remove_after" ]] && msg="${msg}, removal after ${remove_after}"
    msg="${msg})"
  fi
  [[ -n "$note" ]] && msg="${msg}: ${note}"
  _warn "$msg"
}

compat_list() {
  local alias_file="${APDIF_HOME}/compat/aliases.tsv"
  [[ -f "$alias_file" ]] || _die "Missing alias file: ${alias_file}"
  python3 - "$alias_file" <<'PY'
import csv
import sys

with open(sys.argv[1], newline="", encoding="utf-8") as fh:
    reader = csv.DictReader(fh, delimiter="\t")
    for row in reader:
        if row["alias"] == row["canonical"]:
            continue
        print(
            f'{row["alias"]}\t-> {row["canonical"]}\t'
            f'deprecated={row.get("deprecated_in", "")}\t'
            f'remove_after={row.get("remove_after", "")}\t'
            f'note={row.get("note", "")}'
        )
PY
}
