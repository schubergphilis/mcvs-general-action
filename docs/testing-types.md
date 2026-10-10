# Testing types

Set one of these values as the `testing-type` input, see
[Inputs](inputs.md).

- **`graphql-lint`**: Lints GraphQL schemas (`.graphql`, `.graphqls`)
  - Available from mcvs-general-action `v0.9.0`; earlier releases reject it as
    an unknown testing-type
  - Uses [graphql-linter](https://github.com/schubergphilis/graphql-linter):
    the `graphql-schema-linter` rules plus Apollo Federation validation
  - Downloads a pinned release binary and verifies its SHA-256 before running
    it, on `linux/amd64`, `linux/arm64` and `darwin/arm64` runners
  - Lints `graphql-linter-target-path` (default: the repository root); the
    files of each directory are checked together as one schema
  - Configuration: `.graphql-linter.yml` or `.graphql-linter.yaml`, or
    `graphql-linter-config-path`, see `configuration.md` in the graphql-linter
    [documentation](https://github.com/schubergphilis/graphql-linter/tree/v0.2.5/docs)
  - Fails when no schema file is found, so only add it where there are
    schemas

  ```yml
  - uses: schubergphilis/mcvs-general-action@<sha> # v0.9.0
    with:
      testing-type: graphql-lint
      graphql-linter-target-path: schema
  ```

- **`lint-action`**: Validates GitHub Actions workflow files for security issues
  - Uses [zizmor](https://github.com/zizmorcore/zizmor) to detect security vulnerabilities
  - Checks at minimum `low` severity level

- **`lint-commit`**: Validates commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) format
  - Checks all commits in the pull request, compared against the base branch
    as fetched from the base repository, so it also works on a fork that is
    not synced with the base
  - Enforces conventional commit standards (feat, fix, docs, etc.)
  - Configuration: `configs/commitlint.config.mjs`

- **`lint-git`**: Enforces Git workflow best practices
  - Ensures the feature branch is up-to-date with the pull request base
    branch (no commits behind)
  - Detects and blocks unwanted merges of the base branch into feature
    branches
  - Compares against the base branch as fetched from the base repository, so
    the checks cannot be bypassed from a fork
  - Identifies `fixup!`, `squash!` and `amend!` commits that should be
    squashed before merge

- **`lint-links`**: Checks that links in Markdown, HTML and reStructuredText
  files resolve
  - Uses [lychee](https://github.com/lycheeverse/lychee)
  - Also validates `#anchor` fragments in link targets, so a link left behind
    by a renamed heading is caught
  - Fails the job on a broken link and writes a summary to the job page

- **`markdownlint`**: Validates Markdown formatting
  - Uses [markdownlint](https://github.com/DavidAnson/markdownlint)
  - Configuration: `configs/mcvs.markdownlint.yaml`

- **`yamllint`**: Validates YAML file formatting
  - Checks all YAML files against formatting standards
  - Uses hash-pinned dependencies for security
  - Configuration: `configs/yamllint.yaml`
