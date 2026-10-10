#!/usr/bin/env bash
# Git workflow checks of the lint-git testing type.
#
# Usage: lint-git.sh <behind|merges|fixups> <base>
#
# Compares HEAD against <base>, the base branch ref. BASE_REF and HEAD_REF
# name the base and head branches in the messages.
set -euo pipefail

check_behind() {
  local base="$1"
  local commits_behind

  commits_behind=$(git rev-list --count "HEAD..${base}")
  if ((commits_behind > 0)); then
    echo "::error::Branch is behind ${BASE_REF} by" \
      "${commits_behind} commits" >&2
    return 1
  fi
  echo "✅ Branch is up to date with ${BASE_REF}"
}

check_merges() {
  local base="$1"
  local sha

  # Merging the base branch into the feature branch yields a merge whose
  # first parent is the feature branch and whose second parent is on the
  # base branch. A merge of another topic, whose second parent is not on
  # the base branch, is fine.
  while read -r sha; do
    if git merge-base --is-ancestor "${sha}^2" "${base}" &&
      ! git merge-base --is-ancestor "${sha}^1" "${base}"; then
      echo "::error::Detected a merge of ${BASE_REF} into ${HEAD_REF}" \
        "at commit ${sha}: $(git log --format=%s -n 1 "${sha}")" >&2
      return 1
    fi
  done < <(git rev-list --merges "${base}..HEAD")

  echo "✅ No merges of ${BASE_REF} detected in ${HEAD_REF}"
}

check_fixups() {
  local base="$1"
  local fixup_commits

  fixup_commits=$(git log --oneline --grep="^fixup!" --grep="^squash!" \
    --grep="^amend!" "${base}..HEAD")
  if [[ -n "${fixup_commits}" ]]; then
    echo "::error::Found fixup, squash or amend commits that should be" \
      "squashed" >&2
    echo "${fixup_commits}"
    return 1
  fi
  echo "✅ No fixup, squash or amend commits found"
}

main() {
  if (($# != 2)); then
    echo "usage: ${0##*/} <behind|merges|fixups> <base>" >&2
    return 2
  fi

  # The merge check reads git rev-list through a process substitution, whose
  # failure set -e does not catch, so it would pass on a missing base.
  if ! git rev-parse --verify --quiet "$2^{commit}" >/dev/null; then
    echo "::error::Base '$2' is not a commit" >&2
    return 2
  fi

  case "$1" in
    behind) check_behind "$2" ;;
    merges) check_merges "$2" ;;
    fixups) check_fixups "$2" ;;
    *)
      echo "::error::Unknown lint-git check '$1'" >&2
      return 2
      ;;
  esac
}

main "$@"
