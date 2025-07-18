# MCVS-general-action

Create a `.github/workflows/general.yml` file with the following content:

```yml
---
name: General
"on": pull_request
permissions:
  contents: read
  packages: read
jobs:
  MCVS-general-action:
    strategy:
      matrix:
        args:
          - testing-type: lint-commit
          - testing-type: lint-git
          - testing-type: security-file-system
          - testing-type: yamllint
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4.2.2
      - uses: schubergphilis/mcvs-general-action@v0.5.1
        with:
          testing-type: ${{ matrix.args.testing-type }}
```

| Option               | Default | Required |
| :------------------- | :------ | -------- |
| testing-type         |         |          |
| token                |         |          |
| trivy-action-db      | x       |          |
| trivy-action-java-db | x       |          |
| yamllint-version     | x       |          |
| username-token       |         |          |

**Note:** To download TrivyDBs from a private registry, be sure to set both the
token and the username-token.

```yml
steps:
  - uses: actions/checkout@v4.2.2
  - uses: schubergphilis/mcvs-general-action@v0.5.1
    with:
      token: ${{ secrets.GITHUB_TOKEN }}
      username-token: ${{ github.actor }}
```
