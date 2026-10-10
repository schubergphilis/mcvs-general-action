# Tagging and releases

On a push to the default branch, the action creates the next semver tag and a
GitHub Release with auto-generated notes. No `testing-type` is involved: the
step is enabled by default and only runs on that event. Set
`tag-enabled: "false"` to turn it off.

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

Because this is on by default and is not tied to a `testing-type`, a
repository that already calls this action on a push to its default branch —
for `yamllint`, for instance — starts creating tags and releases after
upgrading. If that job runs with `contents: read`, it now fails when it
tries to create the release. Grant `contents: write` or set
`tag-enabled: "false"` to opt out.

## Tagging on merge to main

Create a `.github/workflows/tag.yml` file with the following content:

```yml
---
name: tag
"on":
  push:
    branches:
      - main
concurrency:
  cancel-in-progress: false
  group: tag
permissions:
  contents: read
jobs:
  mcvs-general-action:
    permissions:
      contents: write
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: schubergphilis/mcvs-general-action@v1.0.0
```

The job needs `contents: write`, and the `concurrency` group serialises two
pushes that land in quick succession. Keep it in its own workflow rather
than adding it to a matrix: matrix jobs that race to create the same tag do
not fail, but each of them needs `contents: write`.
