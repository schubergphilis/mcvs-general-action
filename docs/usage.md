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
      - uses: schubergphilis/mcvs-general-action@b6632aeb1211ae627878eda34660ddb8accbbcfb # v0.8.0
        with:
          testing-type: lint-commit
```

## Releasing on merge to main

To tag and release on every merge to `main`, opt in with
`auto-release: "true"` in the workflow from
[Auto-release](auto-release.md#releasing-on-merge-to-main).
