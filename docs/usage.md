# Usage

The [Quickstart](../README.md#quickstart) runs every testing type in a
matrix.

## Running individual tests

You can run a single test type instead of using a matrix:

```yml
jobs:
  commit-lint:
    runs-on: ubuntu-slim
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - uses: schubergphilis/mcvs-general-action@9705f65655a1848a02c368b91d14185b065ebdb5 # v0.7.3
        with:
          testing-type: lint-commit
```
