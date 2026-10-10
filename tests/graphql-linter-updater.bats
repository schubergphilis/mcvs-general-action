#!/usr/bin/env bats
# Tests for scripts/graphql-linter-updater.sh. gh is stubbed, so nothing is
# requested from GitHub. Run: bats tests/

setup() {
  # shellcheck source=scripts/graphql-linter-updater.sh
  source "${BATS_TEST_DIRNAME}/../scripts/graphql-linter-updater.sh"
  SCRIPT="${BATS_TEST_TMPDIR}/graphql-lint.sh"
  cp "${BATS_TEST_DIRNAME}/../scripts/graphql-lint.sh" "$SCRIPT"
}

# Make gh print <output>, as if its --jq filter had already run.
fake_gh() {
  FAKE_GH_OUTPUT=$1
  gh() { printf '%s\n' "$FAKE_GH_OUTPUT"; }
}

# Print the asset lines GitHub would return for release <tag>.
assets_of() {
  local tag=$1
  echo "graphql-linter-${tag}-darwin-arm64 sha256:$(printf 'a%.0s' {1..64})"
  echo "graphql-linter-${tag}-linux-amd64 sha256:$(printf 'b%.0s' {1..64})"
  echo "graphql-linter-${tag}-linux-arm64 sha256:$(printf 'c%.0s' {1..64})"
}

@test "pinned_version reads the version graphql-lint.sh pins" {
  run pinned_version "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "newer compares versions numerically" {
  newer v0.2.6 v0.2.5
  newer v0.10.0 v0.9.0
  newer v1.0.0 v0.99.99

  local older
  for older in "v0.2.5 v0.2.5" "v0.2.4 v0.2.5" "v0.9.0 v0.10.0"; do
    # shellcheck disable=SC2086
    run newer $older
    [ "$status" -eq 1 ]
  done
}

@test "latest_version prints the latest release tag" {
  fake_gh v0.3.0
  run latest_version
  [ "$status" -eq 0 ]
  [ "$output" = v0.3.0 ]
}

@test "latest_version rejects a tag that is not vX.Y.Z" {
  fake_gh v0.3.0-rc1
  run latest_version
  [ "$status" -eq 1 ]
  [[ "$output" == *"unexpected latest graphql-linter release 'v0.3.0-rc1'"* ]]
}

@test "release_digests prints the digest of every platform" {
  fake_gh "$(assets_of v0.3.0)"
  run release_digests v0.3.0
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "darwin-arm64 $(printf 'a%.0s' {1..64})" ]
  [ "${lines[1]}" = "linux-amd64 $(printf 'b%.0s' {1..64})" ]
  [ "${lines[2]}" = "linux-arm64 $(printf 'c%.0s' {1..64})" ]
}

@test "release_digests fails when a platform binary is missing" {
  fake_gh "$(assets_of v0.3.0 | grep -v linux-arm64)"
  run release_digests v0.3.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"has no SHA-256 for graphql-linter-v0.3.0-linux-arm64"* ]]
}

@test "release_digests fails when GitHub recorded no digest" {
  fake_gh "$(assets_of v0.3.0 | sed '/linux-amd64/s/ .*/ null/')"
  run release_digests v0.3.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"has no SHA-256 for graphql-linter-v0.3.0-linux-amd64"* ]]
}

@test "release_digests ignores assets of other platforms and releases" {
  fake_gh "$(assets_of v0.3.0; assets_of v0.2.9; echo "graphql-linter-v0.3.0-windows-amd64 sha256:$(printf 'd%.0s' {1..64})")"
  run release_digests v0.3.0
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [[ "$output" != *dddd* ]]
}

@test "pin rewrites the version and all three digests and nothing else" {
  local original=${BATS_TEST_TMPDIR}/original.sh
  cp "$SCRIPT" "$original"
  fake_gh "$(assets_of v0.3.0)"
  release_digests v0.3.0 | pin "$SCRIPT" v0.3.0

  [ "$(pinned_version "$SCRIPT")" = v0.3.0 ]
  [ "$(diff "$original" "$SCRIPT" | grep -c '^>')" -eq 4 ]

  # The pinned copy still works as graphql-lint.sh.
  run bash -c "source '$SCRIPT' && sha256_for linux-amd64"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'b%.0s' {1..64})" ]
}

@test "pin fails when a digest line cannot be found" {
  sed -i '/^  linux-arm64) echo/d' "$SCRIPT"
  run pin "$SCRIPT" v0.3.0 <<<"linux-arm64 $(printf 'c%.0s' {1..64})"
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not pin the linux-arm64 digest"* ]]
}

@test "pin fails when the version line cannot be found" {
  sed -i '/^GRAPHQL_LINTER_VERSION=/d' "$SCRIPT"
  run pin "$SCRIPT" v0.3.0 </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not pin GRAPHQL_LINTER_VERSION"* ]]
}

@test "latest_version fails when gh fails" {
  gh() { return 1; }
  run latest_version
  [ "$status" -ne 0 ]
}

@test "release_digests fails when gh fails" {
  gh() { return 1; }
  run release_digests v0.3.0
  [ "$status" -ne 0 ]
}

@test "pr_body names both versions and links the release" {
  run pr_body v0.2.5 v0.3.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"from v0.2.5 to v0.3.0"* ]]
  [[ "$output" == *"https://github.com/schubergphilis/graphql-linter/releases/tag/v0.3.0"* ]]
}

# Record every gh and git call in $CALLS and answer the gh calls of main:
# FAKE_LATEST is the latest release, FAKE_OPEN_PR the open pull request,
# FAKE_PROPOSED the version on the updater branch (none when empty) and
# FAKE_ASSETS_FAIL makes the release assets lookup fail.
fake_github() {
  export GITHUB_REPOSITORY=schubergphilis/mcvs-general-action
  CALLS=${BATS_TEST_TMPDIR}/calls
  : >"$CALLS"
  FAKE_LATEST=$1 FAKE_OPEN_PR=${2:-} FAKE_PROPOSED=${3:-} FAKE_ASSETS_FAIL=""
  gh() {
    echo "gh $*" >>"$CALLS"
    case "$*" in
    *releases/latest*) echo "$FAKE_LATEST" ;;
    *releases/tags/*)
      [ -z "$FAKE_ASSETS_FAIL" ] || return 1
      assets_of "$FAKE_LATEST"
      ;;
    *"pulls -X GET"*) echo "$FAKE_OPEN_PR" ;;
    *contents/*)
      [ -n "$FAKE_PROPOSED" ] || return 1
      printf 'GRAPHQL_LINTER_VERSION=%s\n' "$FAKE_PROPOSED" | base64 -w 0
      ;;
    esac
  }
  git() { echo "git $*" >>"$CALLS"; }
  GRAPHQL_LINT_SCRIPT=$SCRIPT
}

# Fail when a call matching <pattern> was recorded in $CALLS. A bare
# ! grep does not fail a BATS test.
refute_call() {
  if grep -q -- "$1" "$CALLS"; then
    echo "unexpected call matching '$1'" >&2
    return 1
  fi
}

@test "open_or_update_pr opens a pull request when none is open" {
  fake_github v0.3.0
  run open_or_update_pr "" "fix: bump" "body"
  [ "$status" -eq 0 ]
  grep -q "^gh api repos/schubergphilis/mcvs-general-action/pulls -X POST -f base=main -f head=graphql-linter-updater -f title=fix: bump -f body=body" "$CALLS"
  refute_call "PATCH"
}

@test "open_or_update_pr updates the open pull request" {
  fake_github v0.3.0
  run open_or_update_pr 42 "fix: bump" "body"
  [ "$status" -eq 0 ]
  grep -q "^gh api repos/schubergphilis/mcvs-general-action/pulls/42 -X PATCH -f title=fix: bump -f body=body" "$CALLS"
  refute_call "POST"
}

@test "open_pr_number looks up open pull requests from the updater branch" {
  fake_github v0.3.0 42
  run open_pr_number
  [ "$status" -eq 0 ]
  [ "$output" = 42 ]
  grep -q -- "-f head=schubergphilis:graphql-linter-updater -f state=open" "$CALLS"
}

@test "main stops when the pinned version is the latest release" {
  fake_github "$(pinned_version "$SCRIPT")"
  run main
  [ "$status" -eq 0 ]
  [[ "$output" == *"is the latest release"* ]]
  refute_call "^git"
}

@test "main stops when the open pull request already proposes the release" {
  fake_github v9.9.9 42 v9.9.9
  run main
  [ "$status" -eq 0 ]
  [[ "$output" == *"already proposed in #42"* ]]
  refute_call "^git"
}

@test "main proposes again when the branch pins the release but no pull request is open" {
  fake_github v9.9.9 "" v9.9.9
  run main
  [ "$status" -eq 0 ]
  grep -q "push --force --quiet origin HEAD:refs/heads/graphql-linter-updater" "$CALLS"
  grep -q "pulls -X POST" "$CALLS"
}

@test "main pins, pushes, opens the pull request and dispatches general.yml" {
  fake_github v9.9.9
  run main
  [ "$status" -eq 0 ]
  [ "$(pinned_version "$SCRIPT")" = v9.9.9 ]
  grep -q "^git add ${SCRIPT}$" "$CALLS"
  grep -q "commit --quiet --message fix: bump graphql-linter from v[0-9.]* to v9.9.9" "$CALLS"
  grep -q "push --force --quiet origin HEAD:refs/heads/graphql-linter-updater" "$CALLS"
  grep -q "pulls -X POST .*-f title=fix: bump graphql-linter from v[0-9.]* to v9.9.9" "$CALLS"
  [ "$(tail -n 1 "$CALLS")" = "gh workflow run general.yml --ref graphql-linter-updater" ]
}

@test "main updates the open pull request for a newer release" {
  fake_github v9.9.9 42 v9.9.8
  run main
  [ "$status" -eq 0 ]
  grep -q "pulls/42 -X PATCH" "$CALLS"
  refute_call "pulls -X POST"
}

@test "main stops before pushing when a release binary is missing" {
  fake_github v9.9.9
  FAKE_ASSETS_FAIL=1
  run main
  [ "$status" -ne 0 ]
  refute_call "^git"
  refute_call "workflow run"
}

@test "main fails when graphql-lint.sh pins no version" {
  fake_github v9.9.9
  sed -i '/^GRAPHQL_LINTER_VERSION=/d' "$SCRIPT"
  run main
  [ "$status" -eq 1 ]
  [[ "$output" == *"no GRAPHQL_LINTER_VERSION=vX.Y.Z"* ]]
  refute_call "^git"
}
