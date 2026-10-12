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

A fork never auto-releases, even with `auto-release: "true"`: the upstream
repository is leading for tags and releases, which are mirrored into the fork.
Syncing a fork pushes to its default branch, so without this the fork would
create releases that do not match upstream's. The job logs a notice that
auto-release is skipped, passes, and leaves the `tag` output empty. There is
no input to override this.

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
      - uses: schubergphilis/mcvs-general-action@b6632aeb1211ae627878eda34660ddb8accbbcfb # v0.8.0
        with:
          auto-release: "true"
```

The job needs `contents: write`, and the `concurrency` group serialises two
pushes that land in quick succession. It needs no `actions/checkout` step:
on that push the action checks out the full history itself, with
`persist-credentials: false`. Keep it in its own workflow rather than adding
it to a matrix: matrix jobs that race to create the same tag do not fail, but
each of them needs `contents: write`.

This repository releases itself the same way, with a checkout because it uses
the action from its own checkout (`uses: $/`), see
[`.github/workflows/release.yml`](../.github/workflows/release.yml).

## Building release assets

The tag and the release are created with the workflow's `GITHUB_TOKEN`, and
GitHub starts no workflow for events caused by that token. A workflow that
builds release assets on a tag push, such as
[mcvs-golang-action's releases](https://raw.githubusercontent.com/schubergphilis/mcvs-golang-action/refs/heads/main/docs/releases.md),
therefore does not run for an auto-released tag. `GITHUB_TOKEN` may still
dispatch a workflow, so no personal access token is needed:

1. Add `workflow_dispatch` to the triggers of the workflow that builds the
   assets.
1. Give the `mcvs-general-action` step an `id`, grant the job
   `actions: write` and dispatch that workflow on the new tag, which the
   `tag` output holds. It is empty when nothing was released, so the
   dispatch only runs for a new release.

```yml
jobs:
  mcvs-general-action:
    permissions:
      actions: write
      contents: write
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    steps:
      - id: release
        uses: schubergphilis/mcvs-general-action@<sha> # v0.10.0
        with:
          auto-release: "true"
      - if: steps.release.outputs.tag != ''
        env:
          GH_REPO: ${{ github.repository }}
          GH_TOKEN: ${{ github.token }}
          TAG: ${{ steps.release.outputs.tag }}
        run: gh workflow run golang-releases.yml --ref "${TAG}"
```

The `tag` output is available from v0.10.0; with an older release it is
always empty and the dispatch never runs. The dispatched run has the tag as
its ref, so `github.ref_name` is the new version, as on a tag push.

Re-running a job whose dispatch failed does not retry it: the release then
already exists, so the `tag` output is empty. Dispatch the workflow by hand
instead, with `gh workflow run golang-releases.yml --ref <tag>`.
