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
[`.github/workflows/tag.yml`](../.github/workflows/tag.yml).
