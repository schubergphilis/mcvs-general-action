# MCVS General Action

[![GitHub release](https://img.shields.io/github/v/release/schubergphilis/mcvs-general-action)](https://github.com/schubergphilis/mcvs-general-action/releases)
[![License](https://img.shields.io/github/license/schubergphilis/mcvs-general-action)](LICENSE)

<img src="./assets/logos/mcvs-general-action.png" alt="MCVS General Action logo" width="250">

## Overview

The Mission Critical Vulnerability Scanner (MCVS) General Action provides automated security and quality checks for your GitHub repository. This composite action runs multiple validation tests to ensure code quality, security standards, and proper Git workflow practices.

## Features

### Available Testing Types

- **`lint-action`**: Validates GitHub Actions workflow files for security issues
  - Uses [zizmor](https://github.com/zizmorcore/zizmor) to detect security vulnerabilities
  - Checks at minimum `low` severity level

- **`lint-commit`**: Validates commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) format
  - Checks all commits in pull request range
  - Enforces conventional commit standards (feat, fix, docs, etc.)
  - Configuration: `configs/commitlint.config.mjs`

- **`lint-git`**: Enforces Git workflow best practices
  - Ensures the feature branch is up-to-date with the pull request base
    branch (no commits behind)
  - Detects and blocks unwanted merges of the base branch into feature
    branches
  - Compares against the base branch as fetched from the base repository, so
    the checks cannot be bypassed from a fork
  - Identifies fixup/squash commits that should be squashed before merge

- **`lychee`**: Checks that links in Markdown, HTML and reStructuredText
  files resolve
  - Uses [lychee](https://github.com/lycheeverse/lychee)
  - Fails the job on a broken link and writes a summary to the job page

- **`markdownlint`**: Validates Markdown formatting
  - Uses [markdownlint](https://github.com/DavidAnson/markdownlint)
  - Configuration: `configs/mcvs.markdownlint.yaml`

- **`yamllint`**: Validates YAML file formatting
  - Checks all YAML files against formatting standards
  - Uses hash-pinned dependencies for security
  - Configuration: `configs/yamllint.yaml`

### Automatic Tagging and Releases

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
upgrading. Set `tag-enabled: "false"` to opt out.

## Usage

### Basic Setup

Create a `.github/workflows/general.yml` file with the following content:

```yml
---
name: general
"on": pull_request
permissions:
  contents: read
  packages: read
jobs:
  mcvs-general-action:
    strategy:
      matrix:
        args:
          - testing-type: lint-action
          - testing-type: lint-commit
          - testing-type: lint-git
          - testing-type: lychee
          - testing-type: markdownlint
          - testing-type: yamllint
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          persist-credentials: false
      - uses: schubergphilis/mcvs-general-action@v0.7.0
        with:
          testing-type: ${{ matrix.args.testing-type }}
```

### Running Individual Tests

You can run a single test type instead of using a matrix:

```yml
jobs:
  commit-lint:
    runs-on: ubuntu-slim
    steps:
      - uses: actions/checkout@v6
      - uses: schubergphilis/mcvs-general-action@v0.7.0
        with:
          testing-type: lint-commit
```

### Tagging on Merge to Main

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
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          persist-credentials: false
      - uses: schubergphilis/mcvs-general-action@v0.7.0
```

The job needs `contents: write`, and the `concurrency` group serialises two
pushes that land in quick succession. Keep it in its own workflow rather
than adding it to the pull request matrix, otherwise every matrix job races
to create the same tag.

## Inputs

| Input                           | Description                                       | Required | Default |
| :------------------------------ | :------------------------------------------------ | :------- | :------ |
| tag-enabled                     | Tag and release on a push to default branch       | No       | true    |
| testing-type                    | Type of test to run (see Available Testing Types) | Yes      | N/A     |
| zizmor-action-advanced-security | Disable advanced security report upload           | No       | true    |

## Security Considerations

- All GitHub Actions are pinned to commit SHAs for security
- Python dependencies (yamllint) are installed with `--require-hashes` from
  [`configs/requirements.txt`](configs/requirements.txt)
- NPM packages (commitlint) are installed via `npm ci` with package-lock.json for integrity verification
- The internal checkout used by `lint-commit`, `lint-git` and the tagging
  step runs with `persist-credentials: false`, so the workflow token is never
  written to `.git/config` in the workspace
- The tag is created by `gh release create --target`, so tagging needs no
  pushable git remote in the workspace either

## License

See [LICENSE](LICENSE) file for details.
