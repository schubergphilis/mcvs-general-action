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
      - uses: schubergphilis/mcvs-general-action@v0.4.0
        with:
          testing-type: ${{ matrix.args.testing-type }}
```

| Option               | Default | Required |
| :------------------- | :------ | -------- |
| testing-type         |         |          |
| token                | x       |          |
| trivy-action-db      | x       |          |
| trivy-action-java-db | x       |          |
| yamllint-version     | x       |          |
