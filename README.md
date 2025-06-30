# MCVS-general-action

Create a `.github/workflows/general.yml` file with the following content:

```yml
---
name: General
"on": push
permissions:
  contents: read
  packages: read
jobs:
  MCVS-general-action:
    strategy:
      matrix:
        args:
          - testing-type: "lint-git"
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4.1.1
      - uses: schubergphilis/mcvs-general-action@v0.1.0
        with:
          testing-type: ${{ matrix.args.testing-type }}
```
