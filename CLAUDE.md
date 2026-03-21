# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MCVS-general-action is a composite GitHub Action that provides multiple security and quality testing capabilities for repositories. It operates as a single action with different testing modes, selected via the `testing-type` input parameter.

## Architecture

### Composite Action Design

The action is defined in `action.yml` as a composite action (not a Docker or JavaScript action). All logic is implemented as bash scripts that run directly in the GitHub Actions runner environment.

### Testing Types

The action supports four distinct testing modes, each triggered by the `testing-type` input:

1. **lint-commit**: Validates commit messages using commitlint
   - Uses `@commitlint/config-conventional` for conventional commits format
   - Checks all commits in the PR range (base.sha to head.sha)
   - Configuration: `configs/commitlint.config.mjs`

1. **lint-git**: Enforces Git workflow standards
   - Checks branch is up-to-date with main (no commits behind)
   - Detects unwanted merges of main into feature branch
   - Identifies fixup/squash commits that should be squashed

1. **security-file-system**: (Implementation details in action.yml)

1. **yamllint**: Validates YAML file formatting
   - Uses hash-pinned dependencies for security (see below)
   - Configuration: `configs/yamllint.yaml`

### Hash-Pinned Dependencies

For security, Python dependencies are installed with `--require-hashes`. The yamllint installation uses a heredoc to create a requirements file:

```yaml
cat > /tmp/req.txt <<EOF
yamllint==<version> --hash=sha256:<hash>
pathspec==<version> --hash=sha256:<hash>
pyyaml==<version> --hash=sha256:<hash>
EOF
python3 -m pip install --require-hashes --user -r /tmp/req.txt
```

When updating versions:

- Update the version input (e.g., `yamllint-version`)
- Update the corresponding SHA256 hash input
- Update all dependency versions and hashes together

## Testing the Action

### Self-Testing Workflow

The action tests itself using `.github/workflows/general.yml`, which:

- Runs on pull requests
- Uses a matrix strategy to test all testing-types
- Uses the action from the current checkout (`uses: ./`)

To test changes locally:

1. Make changes to `action.yml`
1. Push to a feature branch
1. Open a PR to trigger the workflow
1. The workflow will test the action against itself

### Manual Testing

You cannot easily run this action locally since it's a GitHub Actions composite action. Test by:

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

- `action.yml`: Main action definition with all testing logic
- `configs/commitlint.config.mjs`: Commit message linting rules
- `configs/yamllint.yaml`: YAML formatting rules
- `.github/workflows/general.yml`: Self-testing workflow
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
