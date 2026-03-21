# MCVS-general-action

[![GitHub release](https://img.shields.io/github/v/release/schubergphilis/mcvs-general-action)](https://github.com/schubergphilis/mcvs-general-action/releases)
[![License](https://img.shields.io/github/license/schubergphilis/mcvs-general-action)](LICENSE)

## Overview

The Mission Critical Vulnerability Scanner (MCVS) General Action provides automated security and quality checks for your GitHub repository. This composite action runs multiple validation tests to ensure code quality, security standards, and proper Git workflow practices.

## Features

### Available Testing Types

- **`lint-commit`**: Validates commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) format

  - Checks all commits in pull request range
  - Enforces conventional commit standards (feat, fix, docs, etc.)
  - Configuration: `configs/commitlint.config.mjs`

- **`lint-git`**: Enforces Git workflow best practices

  - Ensures feature branch is up-to-date with main (no commits behind)
  - Detects and blocks unwanted merges of main into feature branches
  - Identifies fixup/squash commits that should be squashed before merge

- **`yamllint`**: Validates YAML file formatting

  - Checks all YAML files against formatting standards
  - Uses hash-pinned dependencies for security
  - Configuration: `configs/yamllint.yaml`

- **`security-file-system`**: (Not yet implemented - reserved for future use)

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
          - testing-type: lint-commit
          - testing-type: lint-git
          - testing-type: yamllint
    runs-on: ubuntu-slim
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
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

| Input        | Description                                       | Required | Default |
| :----------- | :------------------------------------------------ | :------- | :------ |
| testing-type | Type of test to run (see Available Testing Types) | Yes      | N/A     |

### Advanced Inputs (yamllint customization)

The following inputs allow customization of yamllint dependencies with hash pinning for security:

| Input                                    | Description             | Default                                                            |
| :--------------------------------------- | :---------------------- | :----------------------------------------------------------------- |
| yamllint-version                         | Version of yamllint     | `1.37.1`                                                           |
| yamllint-sha256-hash                     | SHA256 hash of yamllint | `364f0d79e81409f591e323725e6a9f4504c8699ddf2d7263d8d2b539cd66a583` |
| yamllint-dependency-pathspec-version     | Version of pathspec     | `1.0.4`                                                            |
| yamllint-dependency-pathspec-sha256-hash | SHA256 hash of pathspec | `fb6ae2fd4e7c921a165808a552060e722767cfa526f99ca5156ed2ce45a5c723` |
| yamllint-dependency-pyyaml-version       | Version of PyYAML       | `6.0.3`                                                            |
| yamllint-dependency-pyyaml-sha256-hash   | SHA256 hash of PyYAML   | `ba1cc08a7ccde2d2ec775841541641e4548226580ab850948cbfda66a1befcdc` |

**Note**: These inputs are optional and only needed if you want to use different versions than the defaults. All dependencies are hash-pinned for security using `pip install --require-hashes`.

## Security Considerations

- All GitHub Actions are pinned to commit SHAs for security
- Python dependencies (yamllint) are installed with `--require-hashes` flag for hash verification
- NPM packages (commitlint) are installed via `npm ci` with package-lock.json for integrity verification

## License

See [LICENSE](LICENSE) file for details.
