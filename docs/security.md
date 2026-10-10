# Security considerations

- All GitHub Actions are pinned to commit SHAs for security
- Python dependencies (yamllint) are installed with `--require-hashes` from
  [`configs/requirements.txt`](../configs/requirements.txt)
- NPM packages (commitlint) are installed via `npm ci` with package-lock.json for integrity verification
- The internal checkout used by `lint-commit`, `lint-git` and the auto-release
  step runs with `persist-credentials: false`, so the workflow token is never
  written to `.git/config` in the workspace
- The tag is created by `gh release create --target`, so releasing needs no
  pushable git remote in the workspace either
