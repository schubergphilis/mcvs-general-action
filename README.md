# MCVS General Action

[![GitHub release](https://img.shields.io/github/v/release/schubergphilis/mcvs-general-action)](https://github.com/schubergphilis/mcvs-general-action/releases)
[![License](https://img.shields.io/github/license/schubergphilis/mcvs-general-action)](LICENSE)

<img src="./assets/logos/mcvs-general-action.png" alt="MCVS General Action logo" width="250">

The Mission Critical Vulnerability Scanner (MCVS) General Action provides automated security and quality checks for your GitHub repository. This composite action runs multiple validation tests to ensure code quality, security standards, and proper Git workflow practices.

## Quickstart

1. Pick the checks you need from the [testing types](docs/testing-types.md);
   the workflow below runs all of them except `graphql-lint`, which only
   applies to repositories with GraphQL schemas.
1. Keep `security-events: write` if you run `lint-action` with the default
   Advanced Security upload, see [Inputs](docs/inputs.md).
1. Create `.github/workflows/general.yml` with the following content:

   ```yml
   ---
   name: general
   "on": pull_request
   permissions:
     contents: read
   jobs:
     mcvs-general-action:
       permissions:
         contents: read
         # Only needed by lint-action to upload results to Advanced Security.
         security-events: write
       strategy:
         matrix:
           args:
             - testing-type: lint-action
             - testing-type: lint-commit
             - testing-type: lint-git
             - testing-type: lint-links
             - testing-type: markdownlint
             - testing-type: yamllint
       runs-on: ubuntu-24.04
       steps:
         - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
           with:
             persist-credentials: false
         - uses: schubergphilis/mcvs-general-action@b6632aeb1211ae627878eda34660ddb8accbbcfb # v0.8.0
           with:
             testing-type: ${{ matrix.args.testing-type }}
   ```

## Documentation

- [Testing types](docs/testing-types.md)
- [Usage](docs/usage.md)
- [Inputs](docs/inputs.md)
- [Auto-release](docs/auto-release.md)
- [Security considerations](docs/security.md)
