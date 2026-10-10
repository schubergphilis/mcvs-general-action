#!/usr/bin/env bash
# Bump the graphql-linter release that scripts/graphql-lint.sh pins, the
# version and all three digests together, and open or update a fix: pull
# request for it, so merging it releases a patch through auto-release.
#
# Usage: graphql-linter-updater.sh
#
# Runs from .github/workflows/graphql-linter-updater.yml with GH_TOKEN set to
# the workflow's GITHUB_TOKEN. A pull request opened with that token starts no
# pull_request run, so general.yml is dispatched on the branch instead, which
# that token may do.

GRAPHQL_LINTER_REPOSITORY=schubergphilis/graphql-linter
GRAPHQL_LINT_SCRIPT=scripts/graphql-lint.sh
UPDATER_BRANCH=graphql-linter-updater
PLATFORMS="darwin-arm64 linux-amd64 linux-arm64"

# Print the GRAPHQL_LINTER_VERSION pinned in <script>.
pinned_version() {
  sed -n 's/^GRAPHQL_LINTER_VERSION=//p' "$1"
}

# Print the tag of the latest stable graphql-linter release. GitHub's latest
# release is never a draft or a prerelease.
latest_version() {
  local tag
  tag=$(gh api "repos/${GRAPHQL_LINTER_REPOSITORY}/releases/latest" \
    --jq .tag_name) || return 1
  if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❗ unexpected latest graphql-linter release '${tag}'" >&2
    return 1
  fi
  echo "$tag"
}

# Succeed when version <a> is newer than version <b>.
newer() {
  [[ "$1" != "$2" &&
    "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" == "$1" ]]
}

# Print "<platform> <sha256>" for every platform of release <tag>, from the
# digests GitHub records for its assets. Fails rather than pinning a partial
# set when an asset or its digest is missing.
release_digests() {
  local tag=$1 assets platform asset digest
  assets=$(gh api "repos/${GRAPHQL_LINTER_REPOSITORY}/releases/tags/${tag}" \
    --jq '.assets[] | "\(.name) \(.digest)"') || return 1
  for platform in $PLATFORMS; do
    asset="graphql-linter-${tag}-${platform}"
    digest=$(awk -v asset="$asset" \
      '$1 == asset { sub(/^sha256:/, "", $2); print $2 }' <<<"$assets")
    if [[ ! "$digest" =~ ^[0-9a-f]{64}$ ]]; then
      echo "❗ graphql-linter ${tag} has no SHA-256 for ${asset}" >&2
      return 1
    fi
    echo "${platform} ${digest}"
  done
}

# Pin <tag> in <script>, with the "<platform> <sha256>" lines on stdin.
pin() {
  local script=$1 tag=$2 platform digest
  sed -i "s/^GRAPHQL_LINTER_VERSION=.*/GRAPHQL_LINTER_VERSION=${tag}/" \
    "$script" || return 1
  while read -r platform digest; do
    sed -i "s/^\(  ${platform}) echo \)[0-9a-f]\{64\}/\1${digest}/" \
      "$script" || return 1
    if ! grep -q "^  ${platform}) echo ${digest} ;;" "$script"; then
      echo "❗ could not pin the ${platform} digest in ${script}" >&2
      return 1
    fi
  done
}

# Print the pull request body for the bump from <old> to <new>.
pr_body() {
  cat <<BODY
Bumps graphql-linter from ${1} to ${2}, the version and the SHA-256 of every
release binary together, taken from the digests GitHub records for the
[release assets](https://github.com/${GRAPHQL_LINTER_REPOSITORY}/releases/tag/${2}).

Opened by \`.github/workflows/graphql-linter-updater.yml\`. GitHub starts no
pull_request run for it, so that workflow dispatches \`general.yml\` on this
branch instead.
BODY
}

# Open a pull request from UPDATER_BRANCH, or update the open one, with
# <title> and <body>. REST rather than gh pr, which needs GraphQL scopes.
open_or_update_pr() {
  local title=$1 body=$2 number
  number=$(gh api "repos/${GITHUB_REPOSITORY}/pulls" -X GET \
    -f head="${GITHUB_REPOSITORY%%/*}:${UPDATER_BRANCH}" -f state=open \
    --jq '.[0].number // empty') || return 1
  if [[ -n "$number" ]]; then
    gh api "repos/${GITHUB_REPOSITORY}/pulls/${number}" -X PATCH \
      -f title="$title" -f body="$body" --jq .html_url
    return
  fi
  gh api "repos/${GITHUB_REPOSITORY}/pulls" -X POST \
    -f base=main -f head="$UPDATER_BRANCH" -f title="$title" -f body="$body" \
    --jq .html_url
}

main() {
  set -euo pipefail

  local pinned latest proposed digests title
  pinned=$(pinned_version "$GRAPHQL_LINT_SCRIPT")
  latest=$(latest_version)
  if ! newer "$latest" "$pinned"; then
    echo "✅ graphql-linter ${pinned} is the latest release"
    return
  fi

  # Skip a run that would only rewrite the open pull request's commit, which
  # would dispatch its checks again for nothing.
  proposed=$(gh api \
    "repos/${GITHUB_REPOSITORY}/contents/${GRAPHQL_LINT_SCRIPT}?ref=${UPDATER_BRANCH}" \
    --jq .content 2>/dev/null | base64 -d 2>/dev/null | pinned_version /dev/stdin) ||
    proposed=""
  if [[ "$proposed" == "$latest" ]]; then
    echo "✅ graphql-linter ${latest} is already proposed on ${UPDATER_BRANCH}"
    return
  fi

  digests=$(release_digests "$latest")
  pin "$GRAPHQL_LINT_SCRIPT" "$latest" <<<"$digests"

  title="fix: bump graphql-linter from ${pinned} to ${latest}"
  # Only the file this updater owns, never git add .
  git add "$GRAPHQL_LINT_SCRIPT"
  git -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit --quiet --message "$title"
  # The checkout keeps no credentials (persist-credentials: false), so gh
  # supplies GH_TOKEN for this push only. The branch belongs to the updater
  # and is rebuilt from main on every run, hence --force.
  git -c credential.helper= -c credential.helper='!gh auth git-credential' \
    push --force --quiet origin "HEAD:refs/heads/${UPDATER_BRANCH}"

  open_or_update_pr "$title" "$(pr_body "$pinned" "$latest")"
  gh workflow run general.yml --ref "$UPDATER_BRANCH"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
