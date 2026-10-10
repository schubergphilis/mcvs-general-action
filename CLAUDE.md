# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MCVS-general-action is a composite GitHub Action that provides multiple security and quality testing capabilities for repositories. It operates as a single action with different testing modes, selected via the `testing-type` input parameter.

User documentation is a lean `README.md` (intro and `## Quickstart`) plus pages
in `docs/` (testing types, usage, inputs, security), each linked from the
README's `## Documentation` section. Update those pages when behaviour changes,
and keep relative links and `#anchor` fragments valid, as lint-links checks
them.

## Architecture

### Composite Action Design

The action is defined in `action.yml` as a composite action (not a Docker or JavaScript action). All logic is implemented as bash that runs directly in the GitHub Actions runner environment: inline `run` blocks in `action.yml`, except the lint-git checks, which live in `scripts/lint-git.sh` so that `tests/lint-git.sh` can test them.

### Testing Types

The action implements seven distinct testing modes, each triggered by the
`testing-type` input. The first step fails on a missing or unknown value,
because GitHub does not enforce `required` on composite action inputs and an
unknown value would otherwise skip every step and pass. Keep its list in sync
when adding or renaming a testing type.

1. **lint-commit**: Validates commit messages using commitlint
   - Uses `@commitlint/config-conventional` for conventional commits format
   - Checks all commits in the PR range, `refs/mcvs/base..HEAD` (see the
     note under lint-git)
   - Configuration: `configs/commitlint.config.mjs`

1. **lint-git**: Enforces Git workflow standards
   - Checks branch is up-to-date with the base branch (no commits behind)
   - Detects unwanted merges of the base branch into feature branch
   - Identifies fixup/squash/amend commits that should be squashed
   - Implemented in `scripts/lint-git.sh` (one subcommand per check:
     `behind`, `merges`, `fixups`), covered by `tests/lint-git.sh`

   Note: the workspace is a clone of the *head* repository, checked out at
   the immutable `head.sha`, so `HEAD` is the pull request head and `origin`
   is the fork on a fork pull request, where `base.sha` may be absent. The
   lint-git checks and lint-commit therefore compare against
   `refs/mcvs/base`, which a dedicated step fetches from
   `base.repo.full_name` at `base.ref`. Never reintroduce `origin/main`,
   `base.sha` or `head.sha` here.

1. **lint-action**: Scans GitHub Actions workflows with
   [zizmor](https://github.com/zizmorcore/zizmor-action)
   - Runs `zizmorcore/zizmor-action` with `min-severity: low`
   - `advanced-security` is controlled by the
     `zizmor-action-advanced-security` input (default `"true"`). With
     `"true"` zizmor uploads SARIF and does not fail the job on findings, so
     the check only blocks through a code scanning ruleset; `"false"` fails
     the job on findings

1. **lint-links**: Checks links in Markdown, HTML and reStructuredText files
   with [lychee](https://github.com/lycheeverse/lychee)
   - Runs `lycheeverse/lychee-action`, which fails the job on a broken link
   - Passes `args` to add `--include-fragments` (validates `#anchor` targets).
     Because `args` replaces the upstream default wholesale, the action
     restates that default; re-sync the list on a `lychee-action` bump

1. **markdownlint**: Validates Markdown formatting with
   [markdownlint](https://github.com/DavidAnson/markdownlint)
   - Runs `DavidAnson/markdownlint-cli2-action` over `**/*.md`, excluding
     `node_modules`, which markdownlint-cli2 does not skip on its own
   - Configuration: `configs/mcvs.markdownlint.yaml`

1. **yamllint**: Validates YAML file formatting
   - Uses hash-pinned dependencies for security (see below)
   - Configuration: `configs/yamllint.yaml`

1. **graphql-lint**: Lints GraphQL schemas with
   [graphql-linter](https://github.com/schubergphilis/graphql-linter)
   - `scripts/graphql-lint.sh` downloads the release binary for the runner
     and refuses to run it unless its SHA-256 matches the digest pinned next
     to `GRAPHQL_LINTER_VERSION`
   - Dependabot cannot bump a downloaded binary: bump the version and all
     three digests together, taking the digests GitHub records for the
     release assets (`gh api repos/schubergphilis/graphql-linter/releases/tags/<version> --jq '.assets[] | "\(.digest) \(.name)"'`)
   - Needs graphql-linter `v0.2.5` or later; `v0.2.4` and older only run
     inside a Go module
   - Inputs: `graphql-linter-target-path` (default `.`) and
     `graphql-linter-config-path`

### Auto-release on Push to the Default Branch

Two steps at the end of `action.yml` run on `push` to the default branch,
gated by the opt-in `auto-release` input (default `"false"`) instead of by
`testing-type`. Keep the default `"false"`: turning it on for every caller
would make their push jobs fail on `contents: read`. With
`auto-release: "true"` the `testing-type` may be empty, which the validation
step at the top of `action.yml` allows for that case only. The release is
`gh release create "$tag" --generate-notes`, so the tag is `vX.Y.Z`, the title
equals the tag and the body is GitHub's generated "What's Changed" list, the
same as the releases drafted by hand before; do not add `--title` or
`--notes`. They check out the full history and then compute the next
version with `scripts/next-version.sh`, which reads NUL-separated commit
messages on stdin and prints `vX.Y.Z` (nothing when no commit warrants a
release). `feat!:`/`BREAKING CHANGE:` bumps the major even below `1.0.0`.

Three things in this step are load-bearing and have each already caused a
bug:

- Feed the script with `git log -z --format=%B`, never `--format=%B%x00`.
  The latter writes a newline *after* every NUL, so every record but the
  first arrives with a leading newline, loses its subject and is silently
  classified as no bump. The script strips that newline defensively, and
  `tests/next-version.bats` covers both framings.
- The read loop must not `break`. Closing stdin early makes `git log` die of
  SIGPIPE once its output passes the pipe buffer, and `shell: bash` runs
  with `-eo pipefail`, so the step fails with 141 instead of releasing.
- The baseline tag comes from `last_tag` in `scripts/next-version.sh`,
  which the step sources: `git tag --merged HEAD --list "v*"
  --sort=-v:refname` filtered through `SEMVER_TAG_PATTERN`, not `git
  describe --match`. `--match` is an fnmatch glob that also accepts
  `v1.0.0-rc1`, which the script rejects, failing every push to main. The
  pattern also rejects leading zeros, which bash arithmetic would read as
  octal. Use a here-string rather than piping into `grep -m1`, or grep's
  early exit SIGPIPEs `git tag`.

The release is created with `gh release create "$tag" --target
"$GITHUB_SHA" --generate-notes`, which creates the tag as a side effect.
Never replace this with `git push origin "$tag"`: the workspace checkout
uses `persist-credentials: false` and has no pushable remote. The guard
checks the *release*, not the tag, so a tag left behind by a half-finished
run still gets one. When `gh release create` fails, the step looks for the
release once more before failing, so matrix jobs that race to release the
same tag do not go red.

Self-tested by `.github/workflows/release.yml`, which sets
`auto-release: "true"` so this repository releases itself on every push to
`main`, and needs a `concurrency` group so two quick pushes do not race. The bump logic is unit tested with
BATS in `tests/next-version.bats` (run `bats tests/`; the `bats` job in
`general.yml` runs it on every pull request). The tests build throwaway
repositories so they exercise real `git log` output, and `source` the script,
so keep its logic in functions behind the `main` source guard.

### Hash-Pinned Dependencies

#### Yamllint (Python)

For security, Python dependencies are installed with `--require-hashes` from
`configs/requirements.txt`, which Dependabot keeps current
(`package-ecosystem: pip`, `directory: /configs`).

Note: the pinned pyyaml wheel is `cp312 manylinux x86_64`. It is tied to the
Python version and architecture of the runner, currently `ubuntu-24.04`.
Changing runners means re-pinning that hash.

#### Commitlint (NPM)

Commitlint dependencies are managed via `configs/package.json` and
`configs/package-lock.json`. The action installs them using `npm ci`, scoped to
the `configs/` directory:

```yaml
CONFIGS_PATH="${GITHUB_ACTION_PATH}/configs"
npm ci --prefix "${CONFIGS_PATH}"
npx --prefix "${CONFIGS_PATH}" commitlint --config "$CONFIGS_PATH/commitlint.config.mjs" ...
```

When updating commitlint versions:

- Update versions in `configs/package.json`
- Run `npm install --prefix configs` to regenerate `configs/package-lock.json`
- Commit both files together
- The `package-lock.json` contains integrity hashes automatically

## Testing the Action

### Self-Testing Workflow

The action tests itself using `.github/workflows/general.yml`, which:

- Runs on pull requests
- Uses a matrix strategy to test all testing-types
- Uses the action from the current checkout with GitHub's self-repository
  syntax (`uses: $/`, not `uses: ./`, which zizmor's `self-repository` audit
  rejects because it is subject to runtime filesystem state)
- Runs `tests/lint-git.sh` in the `lint-git-test` job

The lint-git self-test only proves the checks pass on a clean branch, so
`tests/lint-git.sh` builds fixture repositories (base-into-feature merge,
topic merges, fixup!/squash!/amend! commits, a branch behind its base, a clean
branch) and asserts the exit code of each check. Run it locally with
`tests/lint-git.sh`, and extend it when changing `scripts/lint-git.sh`.

To test changes locally:

1. Make changes to `action.yml`
1. Push to a feature branch
1. Open a PR to trigger the workflow
1. The workflow will test the action against itself

### Manual Testing

Apart from `tests/lint-git.sh`, you cannot easily run this action locally since it's a GitHub Actions composite action. Test by:

1. Creating a PR in this repository
1. Observing the workflow results in `.github/workflows/general.yml`

## Code Conventions

### YAML Formatting

All YAML files must:

- Start with `---` (document-start marker)
- Pass yamllint validation using `configs/yamllint.yaml`
- For unavoidably long lines (like GitHub Actions commit SHAs), add:

  ```yaml
  # yamllint disable-line rule:line-length
  ```

### Commit Messages

Follow Conventional Commits format:

- `feat:` - New features
- `fix:` - Bug fixes
- `refactor:` - Code improvements without behavior change
- `chore:` - Maintenance tasks

Configuration enforces this via commitlint in `configs/commitlint.config.mjs`.

### Git Workflow

- Never commit directly to `main`
- Feature branches should be up-to-date with main before merging
- Do not merge main into feature branches (rebase instead)
- Squash fixup commits before merging

## Configuration Files

- `action.yml`: Main action definition with the testing logic
- `scripts/lint-git.sh`: The lint-git checks, run by `action.yml`
- `scripts/graphql-lint.sh`: Downloads, verifies and runs the pinned
  graphql-linter, unit tested by `tests/graphql-lint.bats`; the self-test
  lints `tests/testdata/graphql/schema.graphql`
- `tests/lint-git.sh`: Fixture-repository tests of `scripts/lint-git.sh`
- `scripts/next-version.sh`: Conventional-commit semver bump, unit tested
  by `tests/next-version.bats`
- `configs/commitlint.config.mjs`: Commit message linting rules
- `configs/package.json` / `configs/package-lock.json`: Commitlint dependencies
- `configs/mcvs.markdownlint.yaml`: Markdown formatting rules
- `configs/yamllint.yaml`: YAML formatting rules
- `.github/workflows/general.yml`: Self-testing workflow
- `.github/workflows/release.yml`: Releases this repository on every push to
  `main` with `auto-release: "true"`
- `.github/workflows/mcvs-pr-validation.yml`: Additional PR validation

## Modifying Testing Logic

When changing testing behavior:

1. Edit the corresponding `if` block in `action.yml`
1. Each testing-type has its own conditional block:

   ```yaml
   - if: inputs.testing-type == 'lint-commit'
     run: |
       # bash script here
   ```

1. Test by opening a PR (triggers self-testing workflow)
1. Ensure all matrix jobs pass

## GitHub Actions Pinning

All GitHub Actions are pinned to commit SHAs for security:

```yaml
- uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
```

When updating:

- Use Dependabot suggestions from `.github/dependabot.yml`
- Keep version comment (e.g., `# v6.0.2`) for readability
- Long lines with SHAs should have yamllint exceptions
