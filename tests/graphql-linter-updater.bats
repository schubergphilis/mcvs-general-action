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
