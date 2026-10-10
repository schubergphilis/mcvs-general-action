# Auto-release

With `auto-release: "true"`, a push to the default branch creates the next
semver tag and a GitHub Release whose notes GitHub generates from the merged
pull requests, the same "What's Changed" list and "Full Changelog" link as a
release drafted by hand. It is off by default and not tied to a
`testing-type`, which may then be left out.

The bump is derived from the Conventional Commit messages since the latest
`vX.Y.Z` tag:

| Commit                                  | Bump   | Example           |
| :-------------------------------------- | :----- | :---------------- |
| `feat!:` or a `BREAKING CHANGE:` footer | major  | `0.5.1` → `1.0.0` |
| `feat:`                                 | minor  | `0.5.1` → `0.6.0` |
| `fix:`, `perf:`                         | patch  | `0.5.1` → `0.5.2` |
| anything else only                      | no tag | —                 |

Breaking changes bump the major even below `1.0.0`. When the version is
already released the step is a no-op, so a rerun cannot clobber a release.

With squash merges the commit on the default branch carries the pull
request title and, depending on the repository settings, every commit
message of the branch, so a `BREAKING CHANGE:` footer in any of them bumps
the major.

## Releasing on merge to main

Create a `.github/workflows/release.yml` file with the following content:

```yml
---
name: release
"on":
  push:
    branches:
      - main
concurrency:
  cancel-in-progress: false
  group: release
permissions:
  contents: read
jobs:
  mcvs-general-action:
    permissions:
      contents: write
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: schubergphilis/mcvs-general-action@b6632aeb1211ae627878eda34660ddb8accbbcfb # v0.8.0
        with:
          auto-release: "true"
```

The job needs `contents: write`, and the `concurrency` group serialises two
pushes that land in quick succession. Keep it in its own workflow rather
than adding it to a matrix: matrix jobs that race to create the same tag do
not fail, but each of them needs `contents: write`.

This repository releases itself the same way, see
[`.github/workflows/tag.yml`](../.github/workflows/tag.yml).

## Building release assets

The tag and the release are created with the workflow's `GITHUB_TOKEN`, and
GitHub starts no workflow for events caused by that token. A workflow that
builds release assets on a tag push, such as
[mcvs-golang-action's releases](https://raw.githubusercontent.com/schubergphilis/mcvs-golang-action/refs/heads/main/docs/releases.md),
therefore does not run for an auto-released tag. `GITHUB_TOKEN` may still
dispatch a workflow, so no personal access token is needed:

1. Add `workflow_dispatch` to the triggers of the workflow that builds the
   assets.
1. Give the release step an `id`, grant the job `actions: write` and dispatch
   that workflow on the new tag, which the `tag` output holds. It is empty
   when nothing was released, so the dispatch only runs for a new release.

```yml
jobs:
  mcvs-general-action:
    permissions:
      actions: write
      contents: write
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - id: release
        uses: schubergphilis/mcvs-general-action@4df2739030e57a41331bcf32d413a3c745561979 # v0.9.0
        with:
          auto-release: "true"
      - if: steps.release.outputs.tag != ''
        env:
          GH_TOKEN: ${{ github.token }}
          TAG: ${{ steps.release.outputs.tag }}
        run: gh workflow run golang-releases.yml --ref "${TAG}"
```

The dispatched run has the tag as its ref, so `github.ref_name` is the new
version, as on a tag push.
