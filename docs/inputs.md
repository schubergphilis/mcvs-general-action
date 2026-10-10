# Inputs

The `testing-type` values are listed under [Testing types](testing-types.md).
The action fails on a missing or unknown value rather than silently skipping
every check, unless `auto-release` is `"true"` and `testing-type` is left
out.

| Input                           | Description                                                                                              | Required                          | Default |
| :------------------------------ | :------------------------------------------------------------------------------------------------------- | :-------------------------------- | :------ |
| auto-release                    | Create the next tag and its release on a push to the default branch, see [Auto-release](auto-release.md) | No                                | false   |
| testing-type                    | Type of test to run                                                                                      | Unless `auto-release` is `"true"` | N/A     |
| zizmor-action-advanced-security | Upload `lint-action` results to Advanced Security                                                        | No                                | true    |

With `zizmor-action-advanced-security` set to `true`, zizmor writes SARIF that
is uploaded to code scanning, which needs the `security-events: write`
permission, as granted in the [Quickstart](../README.md#quickstart) workflow.
In that mode `lint-action` does **not** fail the job on findings; it only
blocks a pull request through a code scanning ruleset, see
[Set code scanning merge protection](https://docs.github.com/en/code-security/how-tos/find-and-fix-code-vulnerabilities/manage-your-configuration/set-code-scanning-merge-protection).
Set it to `false` to have `lint-action` fail the job on findings instead.
