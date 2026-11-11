#!/usr/bin/env bats
# Tests for scripts/yamllint.sh. Needs yamllint and pyyaml on the PATH, as
# installed from configs/requirements.txt. Run: bats tests/

setup() {
  # shellcheck source=scripts/yamllint.sh
  source "${BATS_TEST_DIRNAME}/../scripts/yamllint.sh"
  COMPANY_CONFIG="${BATS_TEST_DIRNAME}/../configs/yamllint.yaml"
  REPO=$(mktemp -d)
  WORK=$(mktemp -d)
  cd "$REPO"
  # A file every rule set accepts, and one that breaks document-start.
  printf -- '---\nkey: value\n' >good.yaml
  mkdir -p generated
  printf 'key: value\n' >generated/lock.yaml
}

teardown() {
  rm -rf "$REPO" "$WORK"
}

@test "ignore_patterns skips blank lines and comments and trims spaces" {
  YAMLLINT_IGNORE=$'\n  generated/\n# a comment\n\tvendor/*.yaml  \n'
  run ignore_patterns
  [ "$status" -eq 0 ]
  [ "$output" = $'generated/\nvendor/*.yaml' ]
}

@test "ignore_patterns prints nothing when the input is empty" {
  YAMLLINT_IGNORE=""
  run ignore_patterns
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "write_config keeps the company ignore list and appends the patterns" {
  write_config "$COMPANY_CONFIG" "$WORK/merged.yaml" <<<"generated/"
  run python3 -I -c '
import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["ignore"])' "$WORK/merged.yaml"
  [ "$status" -eq 0 ]
  [ "$output" = "['openspec', 'generated/']" ]
}

@test "write_config keeps the company rules" {
  write_config "$COMPANY_CONFIG" "$WORK/merged.yaml" <<<"generated/"
  run python3 -I -c '
import sys, yaml
config = yaml.safe_load(open(sys.argv[1]))
print(config["extends"], config["rules"]["document-start"])' "$WORK/merged.yaml"
  [ "$status" -eq 0 ]
  [ "$output" = "default {'level': 'error'}" ]
}

@test "main fails on a file the company rules reject" {
  YAMLLINT_IGNORE=""
  run main "$COMPANY_CONFIG" "$WORK"
  [ "$status" -ne 0 ]
  [[ "$output" == *generated/lock.yaml* ]]
}

@test "main passes when that file is ignored" {
  YAMLLINT_IGNORE="generated/"
  run main "$COMPANY_CONFIG" "$WORK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"  generated/"* ]]
}

@test "main lists every extra pattern it ignores" {
  YAMLLINT_IGNORE=$'generated/\nvendor/'
  run main "$COMPANY_CONFIG" "$WORK"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'  generated/\n  vendor/'* ]]
}

@test "main still applies the company ignore list with extra patterns" {
  mkdir -p openspec
  printf 'key: value\n' >openspec/spec.yaml
  YAMLLINT_IGNORE="generated/"
  run main "$COMPANY_CONFIG" "$WORK"
  [ "$status" -eq 0 ]
}

@test "main refuses a wrong number of arguments" {
  run main
  [ "$status" -eq 2 ]
}
