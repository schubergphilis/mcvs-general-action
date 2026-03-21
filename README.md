# MCVS-general-action

[![GitHub release](https://img.shields.io/github/v/release/schubergphilis/mcvs-general-action)](https://github.com/schubergphilis/mcvs-general-action/releases)
[![License](https://img.shields.io/github/license/schubergphilis/mcvs-general-action)](LICENSE)

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
    runs-on: ubuntu-slim
    steps:
      - uses: actions/checkout@some-hash # v4.2.2
      - uses: schubergphilis/mcvs-general-action@some-hash # v0.5.1
        with:
          testing-type: ${{ matrix.args.testing-type }}
```

| Option                  | Default | Required |
| :---------------------- | :------ | -------- |
| testing-type            |         |          |
| yamllint-version        | x       |          |
| yamllint-sha256-version | x       |          |

## License

See [LICENSE](LICENSE) file for details.
