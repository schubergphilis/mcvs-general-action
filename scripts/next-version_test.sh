#!/usr/bin/env bash
# Self-check for next-version.sh. The messages are piped in from a real
# throwaway repository, because the framing git produces is exactly what the
# script has to cope with. Run: bash scripts/next-version_test.sh
set -euo pipefail
cd "$(dirname "$0")"
script="${PWD}/next-version.sh"

# check <expected> <current version> <message>... in oldest-first order.
check() {
  local expected=$1 current=$2
  shift 2

  local repo actual message
  repo=$(mktemp -d)
  git -c init.defaultBranch=main init -q "$repo"
  for message in "$@"; do
    git -C "$repo" -c user.email=t@example.com -c user.name=t \
      commit -q --allow-empty -m "$message"
  done
  actual=$(git -C "$repo" log -z --format=%B | bash "$script" "$current")
  rm -rf "$repo"

  if [ "$actual" != "$expected" ]; then
    echo "❗ expected '${expected}', got '${actual}' from: $*" >&2
    exit 1
  fi
}

check v1.0.0 v0.5.1 "feat!: drop the old input"
check v1.0.0 v0.5.1 "fix(tag)!: rename the output"
check v1.0.0 v0.5.1 "feat: add x" $'fix: y\n\nBREAKING CHANGE: z'
check v0.6.0 v0.5.1 "chore: bump deps" "feat(tag): tag on merge"
check v0.5.2 v0.5.1 "fix: broken link" "docs: rewrite the readme"
check v0.5.2 v0.5.1 "perf: cache the clone"
check "" v0.5.1 "chore: bump deps" "docs: fix a typo"
check v0.1.0 v0.0.0 "feat: initial release"

# A commit that is not the newest one still counts.
check v0.6.0 v0.5.1 "feat: add x" "chore: bump deps"
# A later feat: must not downgrade an earlier breaking change.
check v1.0.0 v0.5.1 "feat!: break the input" "feat: add x"

# The %x00 framing, which appends a newline after each record, must give
# the same answer as the -z framing above.
legacy=$(printf 'feat: add x\0\nchore: bump deps\0\n' | bash "$script" v0.5.1)
if [ "$legacy" != v0.6.0 ]; then
  echo "❗ expected v0.6.0 for the %x00 framing, got '${legacy}'" >&2
  exit 1
fi

if printf "" | bash "$script" v1.2 2>/dev/null; then
  echo "❗ expected a malformed version to fail" >&2
  exit 1
fi

echo "✅ all next-version checks passed"
