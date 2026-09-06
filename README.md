# MCVS General Action

[![GitHub release](https://img.shields.io/github/v/release/schubergphilis/mcvs-general-action)](https://github.com/schubergphilis/mcvs-general-action/releases)
[![License](https://img.shields.io/github/license/schubergphilis/mcvs-general-action)](LICENSE)

<img src="./assets/logos/mcvs-general-action.png" width="250"></a>

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
  - Ensures feature branch is up-to-date with main (no commits behind)
  - Detects and blocks unwanted merges of main into feature branches
  - Identifies fixup/squash commits that should be squashed before merge

- **`security-file-system`**: Reserved for future use

- **`yamllint`**: Validates YAML file formatting
  - Checks all YAML files against formatting standards
  - Uses hash-pinned dependencies for security
  - Configuration: `configs/yamllint.yaml`

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
          - testing-type: security-file-system
          - testing-type: yamllint
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          persist-credentials: false
      - uses: schubergphilis/mcvs-general-action@v0.5.1
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
      - uses: schubergphilis/mcvs-general-action@v0.5.1
        with:
          testing-type: lint-commit
```

## Inputs

| Input                           | Description                                       | Required | Default |
| :------------------------------ | :------------------------------------------------ | :------- | :------ |
| testing-type                    | Type of test to run (see Available Testing Types) | Yes      | N/A     |
| zizmor-action-advanced-security | Disable advanced security report upload           | No       | true    |

### yamllint dependencies

yamllint and its dependencies are pinned with SHA256 hashes in
[`configs/requirements.txt`](configs/requirements.txt) and installed with
`pip install --require-hashes`. Dependabot keeps that file up to date; there
are no version or hash inputs to override.

## Security Considerations

- All GitHub Actions are pinned to commit SHAs for security
- Python dependencies (yamllint) are installed with `--require-hashes` flag for hash verification
- NPM packages (commitlint) are installed via `npm ci` with package-lock.json for integrity verification

## License

See [LICENSE](LICENSE) file for details.
