#!/usr/bin/env bash
# Print the next semver tag for the conventional commit messages read from
# stdin (NUL separated). Prints nothing when none of them warrants a release.
#
# Usage: git log -z --format=%B "$range" | next-version.sh v0.5.1
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
  # git log --format=%B%x00 puts a newline after the NUL, git log -z does
  # not. Tolerate both, otherwise every record but the first loses its
  # subject and is silently classified as no bump at all.
  message=${message#$'\n'}
  subject=${message%%$'\n'*}

  # No break: stdin has to be drained. Closing it early makes git die of
  # SIGPIPE once its output exceeds the pipe buffer, which fails the whole
  # step under `set -o pipefail`.
  if [[ "$subject" =~ ^[a-zA-Z]+(\([^\)]*\))?!: ]] ||
    grep -qE '^BREAKING[ -]CHANGE:' <<<"$message"; then
    bump=major
  elif [[ "$subject" =~ ^feat(\([^\)]*\))?: ]] && [ "$bump" != major ]; then
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
