#!/usr/bin/env bash
# Tests scripts/lint-git.sh against fixture repositories.
#
# Usage: tests/lint-git.sh
set -euo pipefail

LINT_GIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lint-git.sh"
readonly LINT_GIT

# Keep the fixtures independent of the user's git configuration.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export BASE_REF=main HEAD_REF=feature

failures=0
commits=0

# Commits a new file, so that merges never conflict.
commit() {
  commits=$((commits + 1))
  echo "$1" >"file${commits}"
  git add "file${commits}"
  git commit --quiet --message "$1"
}

merge() {
  git merge --quiet --no-ff --no-edit "$1"
}

# Creates a repository with main at "base 1" and feature one commit ahead,
# checked out on feature.
new_fixture() {
  local dir
  dir="$(mktemp -d "${TMPDIR_ROOT}/fixture.XXXXXX")"
  cd "${dir}"
  git init --quiet --initial-branch=main
  commit "feat: base 1"
  git switch --quiet --create feature
  commit "feat: feature 1"
}

# Runs a check against main on the current fixture and asserts its exit
# code, and that a failure is reported as an error annotation.
assert_check() {
  local name="$1" check="$2" want="$3"
  local got=0 stderr

  stderr="$("${LINT_GIT}" "${check}" main 2>&1 >/dev/null)" || got=$?
  if ((got != want)); then
    echo "FAIL ${name}: ${check} exited ${got}, want ${want}: ${stderr}"
    failures=$((failures + 1))
  elif ((got != 0)) && [[ "${stderr}" != "::error::"* ]]; then
    echo "FAIL ${name}: ${check} did not report an error annotation"
    failures=$((failures + 1))
  else
    echo "ok   ${name}: ${check} exited ${got}"
  fi
}

test_clean() {
  new_fixture
  commit "feat: feature 2"
  assert_check clean behind 0
  assert_check clean merges 0
  assert_check clean fixups 0
}

test_behind_base() {
  new_fixture
  git switch --quiet main
  commit "feat: base 2"
  git switch --quiet feature
  assert_check behind-base behind 1
}

test_base_into_feature() {
  new_fixture
  git switch --quiet main
  commit "feat: base 2"
  git switch --quiet feature
  merge main
  assert_check base-into-feature behind 0
  assert_check base-into-feature merges 1
}

test_topic_merge() {
  new_fixture
  git switch --quiet --create topic main
  commit "feat: topic"
  git switch --quiet feature
  merge topic
  assert_check topic-merge merges 0
}

# The first parent of this merge is on main, which must not be mistaken
# for a merge of main.
test_topic_merge_without_own_commits() {
  new_fixture
  git reset --quiet --hard main
  git switch --quiet --create topic main
  commit "feat: topic"
  git switch --quiet feature
  merge topic
  assert_check topic-merge-without-own-commits merges 0
}

test_autosquash_commits() {
  local prefix
  for prefix in fixup squash amend; do
    new_fixture
    commit "${prefix}! feat: feature 1"
    assert_check "${prefix}-commit" fixups 1
  done
}

test_missing_base() {
  new_fixture
  git branch --quiet --delete --force main
  assert_check missing-base merges 2
}

main() {
  TMPDIR_ROOT="$(mktemp -d)"
  trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

  test_clean
  test_behind_base
  test_base_into_feature
  test_topic_merge
  test_topic_merge_without_own_commits
  test_autosquash_commits
  test_missing_base

  if ((failures > 0)); then
    echo "${failures} check(s) failed" >&2
    return 1
  fi
  echo "All checks passed"
}

main "$@"
