#!/usr/bin/env bats
# Tests for scripts/next-version.sh. The messages are piped in from a real
# throwaway repository, because the framing git produces is exactly what the
# script has to cope with. Run: bats tests/

setup() {
  # Keep a developer's commit signing, hooks or other global git settings out
  # of the throwaway repositories.
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  # shellcheck source=scripts/next-version.sh
  source "${BATS_TEST_DIRNAME}/../scripts/next-version.sh"
}

# Commit <message>... in oldest-first order to a fresh repository and write
# its NUL-separated log to ${BATS_TEST_TMPDIR}/log.
commits() {
  local repo="${BATS_TEST_TMPDIR}/repo" message
  git -c init.defaultBranch=main init -q "$repo"
  for message in "$@"; do
    git -C "$repo" -c user.email=t@example.com -c user.name=t \
      commit -q --allow-empty -m "$message"
  done
  git -C "$repo" log -z --format=%B >"${BATS_TEST_TMPDIR}/log"
}

@test "feat! bumps the major below 1.0.0" {
  commits "feat!: drop the old input"
  run main v0.5.1 <"${BATS_TEST_TMPDIR}/log"
  [ "$status" -eq 0 ]
  [ "$output" = v1.0.0 ]
}

@test "a scoped breaking fix bumps the major" {
  commits "fix(tag)!: rename the output"
  run main v0.5.1 <"${BATS_TEST_TMPDIR}/log"
  [ "$status" -eq 0 ]
  [ "$output" = v1.0.0 ]
}

@test "a BREAKING CHANGE footer bumps the major" {
  commits "feat: add x" $'fix: y\n\nBREAKING CHANGE: z'
  run main v0.5.1 <"${BATS_TEST_TMPDIR}/log"
  [ "$status" -eq 0 ]
  [ "$output" = v1.0.0 ]
}

@test "feat bumps the minor" {
  commits "chore: bump deps" "feat(tag): tag on merge"
  run main v0.5.1 <"${BATS_TEST_TMPDIR}/log"
  [ "$status" -eq 0 ]
  [ "$output" = v0.6.0 ]
}

@test "fix bumps the patch" {
  commits "fix: broken link" "docs: rewrite the readme"
  run main v0.5.1 <"${BATS_TEST_TMPDIR}/log"
  [ "$status" -eq 0 ]
  [ "$output" = v0.5.2 ]
}

@test "perf bumps the patch" {
  commits "perf: cache the clone"
  run main v0.5.1 <"${BATS_TEST_TMPDIR}/log"
  [ "$status" -eq 0 ]
  [ "$output" = v0.5.2 ]
}

@test "chore and docs only print nothing" {
  commits "chore: bump deps" "docs: fix a typo"
  run main v0.5.1 <"${BATS_TEST_TMPDIR}/log"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the first feat from v0.0.0 is v0.1.0" {
  commits "feat: initial release"
  run main v0.0.0 <"${BATS_TEST_TMPDIR}/log"
  [ "$status" -eq 0 ]
  [ "$output" = v0.1.0 ]
}

@test "a commit that is not the newest one still counts" {
  commits "feat: add x" "chore: bump deps"
  run main v0.5.1 <"${BATS_TEST_TMPDIR}/log"
  [ "$status" -eq 0 ]
  [ "$output" = v0.6.0 ]
}

@test "a later feat does not downgrade an earlier breaking change" {
  commits "feat!: break the input" "feat: add x"
  run main v0.5.1 <"${BATS_TEST_TMPDIR}/log"
  [ "$status" -eq 0 ]
  [ "$output" = v1.0.0 ]
}

@test "the %x00 framing gives the same answer as -z" {
  run main v0.5.1 < <(printf 'feat: add x\0\nchore: bump deps\0\n')
  [ "$status" -eq 0 ]
  [ "$output" = v0.6.0 ]
}

@test "a malformed version fails" {
  run main v1.2 </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not a vX.Y.Z version"* ]]
}

@test "classify_message reads only the subject for the type" {
  run classify_message $'chore: x\n\nfeat: not a subject'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the script runs main when executed" {
  run bash "${BATS_TEST_DIRNAME}/../scripts/next-version.sh" v0.5.1 \
    < <(printf 'fix: y\0')
  [ "$status" -eq 0 ]
  [ "$output" = v0.5.2 ]
}

@test "a version with a leading zero fails" {
  run main v1.08.0 </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not a vX.Y.Z version"* ]]
}

# Tag every commit of a fresh repository with the next argument, oldest
# first, and cd into it.
tagged_repo() {
  local repo="${BATS_TEST_TMPDIR}/tagged" tag
  git -c init.defaultBranch=main init -q "$repo"
  for tag in "$@"; do
    git -C "$repo" -c user.email=t@example.com -c user.name=t \
      commit -q --allow-empty -m "chore: ${tag}"
    git -C "$repo" tag "$tag"
  done
  cd "$repo"
}

@test "last_tag picks the highest strict semver tag, not the newest" {
  tagged_repo v0.9.0 v0.10.0 v1.0.0-rc1 v1.08.0 v0.2.0
  run last_tag
  [ "$status" -eq 0 ]
  [ "$output" = v0.10.0 ]
}

@test "last_tag ignores tags that are not reachable from HEAD" {
  tagged_repo v0.1.0 v0.2.0
  git checkout -q HEAD~1
  run last_tag
  [ "$status" -eq 0 ]
  [ "$output" = v0.1.0 ]
}

@test "last_tag prints nothing without a semver tag" {
  tagged_repo latest v1.0.0-rc1
  run last_tag
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
