#!/usr/bin/env bash
# Lint every YAML file below the working directory with the company yamllint
# configuration, skipping the paths the caller lists.
#
# Usage: yamllint.sh <company-config> [work-dir]
#
# YAMLLINT_IGNORE holds the caller's extra ignore patterns, one per line,
# gitignore style; blank lines and lines starting with # are skipped. They
# are added to the company configuration's own ignore list, never replace
# it. yamllint's `extends` cannot do that: a parent's ignore wins over the
# child's, so the merged configuration is written out in full.
set -euo pipefail

# Print the caller's ignore patterns, one per line, without blanks and
# comments.
ignore_patterns() {
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    printf '%s\n' "$line"
  done <<<"${YAMLLINT_IGNORE:-}"
}

# Write <company-config> to <out> with the patterns on stdin appended to its
# ignore list. Needs pyyaml, which the pinned yamllint brings.
write_config() {
  python3 -I -c '
import sys

import yaml

with open(sys.argv[1]) as source:
    config = yaml.safe_load(source)
ignore = config.get("ignore") or []
if isinstance(ignore, str):
    ignore = ignore.splitlines()
config["ignore"] = [*ignore, *sys.stdin.read().splitlines()]


class Dumper(yaml.SafeDumper):
    # Indent list items under their key, as the company rules require.
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)


with open(sys.argv[2], "w") as target:
    yaml.dump(config, target, Dumper=Dumper, explicit_start=True, sort_keys=False)
' "$1" "$2"
}

main() {
  if (($# < 1 || $# > 2)); then
    echo "usage: ${0##*/} <company-config> [work-dir]" >&2
    return 2
  fi
  local config="$1" work_dir="${2:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}}"
  local patterns
  patterns=$(ignore_patterns)
  if [[ -n "$patterns" ]]; then
    local merged="${work_dir}/mcvs-yamllint.yaml"
    write_config "$config" "$merged" <<<"$patterns"
    echo "Ignoring, besides the company ignore list:"
    local pattern
    while IFS= read -r pattern; do
      printf '  %s\n' "$pattern"
    done <<<"$patterns"
    config="$merged"
  fi
  yamllint -c "$config" .
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
