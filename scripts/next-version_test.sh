#!/usr/bin/env bash
# Self-check for next-version.sh. Run: bash scripts/next-version_test.sh
set -euo pipefail
cd "$(dirname "$0")"

check() {
  local expected=$1 current=$2
  shift 2
  local actual
  actual=$(printf "%s\0" "$@" | bash ./next-version.sh "$current")
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

if printf "" | bash ./next-version.sh v1.2 2>/dev/null; then
  echo "❗ expected a malformed version to fail" >&2
  exit 1
fi

echo "✅ all next-version checks passed"
