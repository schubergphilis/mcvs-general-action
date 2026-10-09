#!/usr/bin/env bash
# Print the next semver tag for the conventional commit messages read from
# stdin (NUL separated). Prints nothing when none of them warrants a release.
#
# Usage: git log -z --format=%B "$range" | next-version.sh v0.5.1

# Print the bump (major, minor, patch or nothing) for one commit message.
classify_message() {
  local message=$1 subject
  subject=${message%%$'\n'*}

  if [[ "$subject" =~ ^[a-zA-Z]+(\([^\)]*\))?!: ]] ||
    grep -qE '^BREAKING[ -]CHANGE:' <<<"$message"; then
    echo major
  elif [[ "$subject" =~ ^feat(\([^\)]*\))?: ]]; then
    echo minor
  elif [[ "$subject" =~ ^(fix|perf)(\([^\)]*\))?: ]]; then
    echo patch
  fi
}

# Print the highest bump of the NUL-separated messages on stdin.
highest_bump() {
  local bump='' message
  while IFS= read -r -d '' message; do
    # git log --format=%B%x00 puts a newline after the NUL, git log -z does
    # not. Tolerate both, otherwise every record but the first loses its
    # subject and is silently classified as no bump at all.
    message=${message#$'\n'}

    # No break: stdin has to be drained. Closing it early makes git die of
    # SIGPIPE once its output exceeds the pipe buffer, which fails the whole
    # step under `set -o pipefail`.
    case "$(classify_message "$message")" in
    major) bump="major" ;;
    minor) [ "$bump" = major ] || bump="minor" ;;
    patch) [ -n "$bump" ] || bump="patch" ;;
    esac
  done
  echo "$bump"
}

main() {
  set -euo pipefail

  local current=${1:-v0.0.0}
  if [[ ! "$current" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "❗ '${current}' is not a vX.Y.Z version" >&2
    return 1
  fi
  local major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]}
  local patch=${BASH_REMATCH[3]}

  case "$(highest_bump)" in
  major) echo "v$((major + 1)).0.0" ;;
  minor) echo "v${major}.$((minor + 1)).0" ;;
  patch) echo "v${major}.${minor}.$((patch + 1))" ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
