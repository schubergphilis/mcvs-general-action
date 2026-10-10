#!/usr/bin/env bats
# Tests for scripts/graphql-lint.sh. uname, curl and the linter are stubbed,
# so nothing is downloaded. Run: bats tests/

setup() {
  # shellcheck source=scripts/graphql-lint.sh
  source "${BATS_TEST_DIRNAME}/../scripts/graphql-lint.sh"
}

# Pretend to run on <os> <arch>.
fake_uname() {
  FAKE_OS=$1 FAKE_ARCH=$2
  uname() {
    case "$1" in
    -s) echo "$FAKE_OS" ;;
    -m) echo "$FAKE_ARCH" ;;
    esac
  }
}

# Make curl write <content> to its --output file instead of downloading.
fake_download() {
  FAKE_CONTENT=$1
  curl() {
    local output
    while [ $# -gt 0 ]; do
      [ "$1" = --output ] && output=$2
      shift
    done
    printf '%s' "$FAKE_CONTENT" >"$output"
  }
}

# Make sha256_for return the SHA-256 of <content> for every platform.
fake_digest_of() {
  local sum
  sum=$(printf '%s' "$1" | sha256sum)
  FAKE_SHA=${sum%% *}
  sha256_for() { echo "$FAKE_SHA"; }
}

@test "platform maps Linux x86_64 to linux-amd64" {
  fake_uname Linux x86_64
  run platform
  [ "$status" -eq 0 ]
  [ "$output" = linux-amd64 ]
}

@test "platform maps Linux aarch64 and arm64 to linux-arm64" {
  fake_uname Linux aarch64
  run platform
  [ "$status" -eq 0 ]
  [ "$output" = linux-arm64 ]

  fake_uname Linux arm64
  run platform
  [ "$status" -eq 0 ]
  [ "$output" = linux-arm64 ]
}

@test "platform maps Darwin arm64 to darwin-arm64" {
  fake_uname Darwin arm64
  run platform
  [ "$status" -eq 0 ]
  [ "$output" = darwin-arm64 ]
}

@test "platform fails on a machine without a release binary" {
  fake_uname Darwin x86_64
  run platform
  [ "$status" -eq 1 ]
  [[ "$output" == *"has no binary for Darwin/x86_64"* ]]
}

@test "every released platform has a pinned SHA-256" {
  local platform
  for platform in darwin-arm64 linux-amd64 linux-arm64; do
    run sha256_for "$platform"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-f]{64}$ ]]
  done
}

@test "sha256_for fails on an unknown platform" {
  run sha256_for windows-amd64
  [ "$status" -eq 1 ]
  [[ "$output" == *"no pinned graphql-linter digest"* ]]
}

@test "install_graphql_linter installs a download that matches the digest" {
  fake_uname Linux x86_64
  fake_download "a linter"
  fake_digest_of "a linter"

  run install_graphql_linter "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
  [ "$output" = "${BATS_TEST_TMPDIR}/graphql-linter" ]
  [ -x "${BATS_TEST_TMPDIR}/graphql-linter" ]
}

@test "install_graphql_linter removes a download that does not match" {
  fake_uname Linux x86_64
  fake_download "a tampered linter"

  run install_graphql_linter "$BATS_TEST_TMPDIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"expected c907549f"* ]]
  [ ! -e "${BATS_TEST_TMPDIR}/graphql-linter" ]
  [ ! -e "${BATS_TEST_TMPDIR}/graphql-linter.download" ]
}

@test "install_graphql_linter downloads the pinned version for the platform" {
  fake_uname Linux aarch64
  curl() {
    echo "$@" >"${BATS_TEST_TMPDIR}/curl-args"
    return 22
  }

  run install_graphql_linter "$BATS_TEST_TMPDIR"
  [ "$status" -eq 1 ]
  grep -q "/download/v0.2.5/graphql-linter-v0.2.5-linux-arm64$" \
    "${BATS_TEST_TMPDIR}/curl-args"
}

@test "install_graphql_linter fails when the download cannot be moved" {
  fake_uname Linux x86_64
  fake_download "a linter"
  fake_digest_of "a linter"
  mv() { return 1; }

  run install_graphql_linter "$BATS_TEST_TMPDIR"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "file_sha256 prints only the digest" {
  printf 'a linter' >"${BATS_TEST_TMPDIR}/file"
  run file_sha256 "${BATS_TEST_TMPDIR}/file"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9a-f]{64}$ ]]
}

@test "file_sha256 falls back to shasum where sha256sum is missing" {
  command() {
    if [ "$1" = -v ] && [ "$2" = sha256sum ]; then
      return 1
    fi
    builtin command "$@"
  }
  shasum() {
    echo "$*" >"${BATS_TEST_TMPDIR}/shasum-args"
    echo "0123abcd  $3"
  }

  run file_sha256 "${BATS_TEST_TMPDIR}/file"
  [ "$status" -eq 0 ]
  [ "$output" = 0123abcd ]
  [ "$(cat "${BATS_TEST_TMPDIR}/shasum-args")" = "-a 256 ${BATS_TEST_TMPDIR}/file" ]
}

@test "file_sha256 fails when sha256sum fails" {
  sha256sum() { return 1; }
  run file_sha256 "${BATS_TEST_TMPDIR}/file"
  [ "$status" -ne 0 ]
}

@test "file_sha256 fails when the shasum fallback fails" {
  command() {
    if [ "$1" = -v ] && [ "$2" = sha256sum ]; then
      return 1
    fi
    builtin command "$@"
  }
  shasum() { return 1; }
  run file_sha256 "${BATS_TEST_TMPDIR}/file"
  [ "$status" -ne 0 ]
}

# Replace the install with a fake linter that records its arguments and
# exits with <status>.
fake_linter() {
  FAKE_STATUS=$1
  install_graphql_linter() {
    printf '#!/usr/bin/env bash\necho "$@"\nexit %s\n' "$FAKE_STATUS" \
      >"$1/graphql-linter"
    chmod +x "$1/graphql-linter"
    echo "$1/graphql-linter"
  }
}

@test "main lints the current directory by default" {
  fake_linter 0
  RUNNER_TEMP=$BATS_TEST_TMPDIR run main
  [ "$status" -eq 0 ]
  [ "$output" = "-targetPath ." ]
}

@test "main passes the target and config paths" {
  fake_linter 0
  RUNNER_TEMP=$BATS_TEST_TMPDIR run main schema "config/.graphql-linter.yml"
  [ "$status" -eq 0 ]
  [ "$output" = "-targetPath schema -configPath config/.graphql-linter.yml" ]
}

@test "main treats an empty target path as the current directory" {
  fake_linter 0
  RUNNER_TEMP=$BATS_TEST_TMPDIR run main "" ""
  [ "$status" -eq 0 ]
  [ "$output" = "-targetPath ." ]
}

@test "main fails when the linter reports findings" {
  fake_linter 1
  RUNNER_TEMP=$BATS_TEST_TMPDIR run main
  [ "$status" -eq 1 ]
}

@test "main removes the downloaded linter afterwards" {
  fake_linter 0
  RUNNER_TEMP=$BATS_TEST_TMPDIR run main
  [ "$status" -eq 0 ]
  run compgen -G "${BATS_TEST_TMPDIR}/graphql-linter.*"
  [ "$status" -ne 0 ]
}

@test "main stops and cleans up when the install fails" {
  install_graphql_linter() { return 3; }
  RUNNER_TEMP=$BATS_TEST_TMPDIR run main
  # 3 is the install's status; 127 would mean an empty path was executed.
  [ "$status" -eq 3 ]
  [[ "$output" != *"command not found"* ]]
  run compgen -G "${BATS_TEST_TMPDIR}/graphql-linter.*"
  [ "$status" -ne 0 ]
}
