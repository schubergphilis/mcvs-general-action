#!/usr/bin/env bash
# Print the next semver tag for the conventional commit messages read from
# stdin (NUL separated). Prints nothing when none of them warrants a release.
#
# Usage: git log --format=%B%x00 "$range" | next-version.sh v0.5.1
set -euo pipefail

current=${1:-v0.0.0}
if [[ ! "$current" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "❗ '${current}' is not a vX.Y.Z version" >&2
  exit 1
fi
major=${BASH_REMATCH[1]}
minor=${BASH_REMATCH[2]}
patch=${BASH_REMATCH[3]}

bump=
while IFS= read -r -d '' message; do
  subject=${message%%$'\n'*}
  if [[ "$subject" =~ ^[a-zA-Z]+(\([^\)]*\))?!: ]] ||
    grep -qE '^BREAKING[ -]CHANGE:' <<<"$message"; then
    bump=major
    break
  elif [[ "$subject" =~ ^feat(\([^\)]*\))?: ]]; then
    bump=minor
  elif [[ "$subject" =~ ^(fix|perf)(\([^\)]*\))?: ]] && [ -z "$bump" ]; then
    bump=patch
  fi
done

case "$bump" in
major) echo "v$((major + 1)).0.0" ;;
minor) echo "v${major}.$((minor + 1)).0" ;;
patch) echo "v${major}.${minor}.$((patch + 1))" ;;
esac
