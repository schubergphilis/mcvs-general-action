#!/usr/bin/env bash
# Download the pinned graphql-linter release binary, verify it against its
# pinned SHA-256 and lint the GraphQL schemas below the target path.
#
# Usage: graphql-lint.sh [target-path] [config-path]
#
# Bump GRAPHQL_LINTER_VERSION and the digests in sha256_for together. GitHub
# records the digest of every release asset:
#   gh api repos/schubergphilis/graphql-linter/releases/tags/<version> \
#     --jq '.assets[] | "\(.digest) \(.name)"'

GRAPHQL_LINTER_VERSION=v0.2.5
GRAPHQL_LINTER_RELEASES=https://github.com/schubergphilis/graphql-linter/releases

# Print the release asset suffix for this machine, e.g. linux-amd64.
platform() {
  local os arch
  os=$(uname -s)
  arch=$(uname -m)
  case "${os}/${arch}" in
  Linux/x86_64) echo linux-amd64 ;;
  Linux/aarch64 | Linux/arm64) echo linux-arm64 ;;
  Darwin/arm64) echo darwin-arm64 ;;
  *)
    echo "❗ graphql-linter ${GRAPHQL_LINTER_VERSION} has no binary for" \
      "${os}/${arch}" >&2
    return 1
    ;;
  esac
}

# Print the pinned SHA-256 of the release asset for <platform>. A case
# statement rather than an associative array: macOS runners ship bash 3.2.
sha256_for() {
  case "$1" in
  darwin-arm64) echo 0eb6445887bd1c9e7e366c5de4a4befd6449dc7c2cb6de807265a4e38c836813 ;;
  linux-amd64) echo c907549f31e16da2f9e44f74837f69acec715955cd4e2858e5f38c37210d8acf ;;
  linux-arm64) echo f5de8d201279dedd827b4562bc4331c83a6e6cc6d507a5b7b10aa50428e5add6 ;;
  *)
    echo "❗ no pinned graphql-linter digest for '$1'" >&2
    return 1
    ;;
  esac
}

# Print the SHA-256 of <file>: sha256sum on Linux, shasum on macOS.
file_sha256() {
  local sum
  if command -v sha256sum >/dev/null 2>&1; then
    sum=$(sha256sum "$1") || return 1
  else
    sum=$(shasum -a 256 "$1") || return 1
  fi
  echo "${sum%% *}"
}

# Download graphql-linter into <dir>, verify it and print the binary's path.
# A download that does not match the pinned digest is removed, never run.
install_graphql_linter() {
  local dir=$1 platform expected actual bin
  platform=$(platform) || return 1
  expected=$(sha256_for "$platform") || return 1
  bin="${dir}/graphql-linter"

  curl --fail --silent --show-error --location --retry 3 \
    --output "${bin}.download" \
    "${GRAPHQL_LINTER_RELEASES}/download/${GRAPHQL_LINTER_VERSION}/graphql-linter-${GRAPHQL_LINTER_VERSION}-${platform}" ||
    return 1

  actual=$(file_sha256 "${bin}.download") || return 1
  if [[ "$actual" != "$expected" ]]; then
    rm -f "${bin}.download"
    echo "❗ graphql-linter-${GRAPHQL_LINTER_VERSION}-${platform} has" \
      "SHA-256 ${actual}, expected ${expected}" >&2
    return 1
  fi

  # install_graphql_linter runs inside $(...), where set -e does not apply.
  mv "${bin}.download" "$bin" || return 1
  chmod +x "$bin" || return 1
  echo "$bin"
}

main() {
  set -euo pipefail

  local target=${1:-.} config=${2:-} bin
  GRAPHQL_LINTER_DIR=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/graphql-linter.XXXXXX")
  trap 'rm -rf "${GRAPHQL_LINTER_DIR}"' EXIT

  bin=$(install_graphql_linter "${GRAPHQL_LINTER_DIR}")

  local args=(-targetPath "$target")
  if [[ -n "$config" ]]; then
    args+=(-configPath "$config")
  fi
  "$bin" "${args[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
