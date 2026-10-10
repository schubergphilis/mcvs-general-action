#!/usr/bin/env bash
# Print the next semver tag for the conventional commit messages read from
# stdin (NUL separated). Prints nothing when none of them warrants a release.
#
# Usage: git log -z --format=%B "$range" | next-version.sh v0.5.1
#
# Source it to use last_tag, which picks the baseline for "$range".

# A vX.Y.Z tag without leading zeros. Bash arithmetic reads 010 as octal and
# fails on 08, so such a tag is neither a baseline nor accepted by main.
SEMVER_TAG_PATTERN='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

# Print the highest vX.Y.Z tag reachable from HEAD, or nothing. --list "v*"
# also returns tags such as v1.0.0-rc1, hence the strict pattern; git
# describe --match is an fnmatch glob with the same problem.
last_tag() {
  local tags
  tags=$(git tag --merged HEAD --list "v*" --sort=-v:refname)
  # A here-string, not a pipe: grep -m1 exits early and would SIGPIPE git
  # on a repository with many tags.
  grep -m1 -E "$SEMVER_TAG_PATTERN" <<<"$tags" || true
}

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
  if [[ ! "$current" =~ $SEMVER_TAG_PATTERN ]]; then
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
