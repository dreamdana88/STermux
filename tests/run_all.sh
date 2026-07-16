#!/usr/bin/env bash

set -u
set -o pipefail

TEST_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
PROJECT_ROOT="$(CDPATH= cd -- "$TEST_ROOT/.." && pwd -P)" || exit 1

syntax_files=(
    "$PROJECT_ROOT/manager.sh"
    "$PROJECT_ROOT/core/config.sh"
    "$PROJECT_ROOT/core/ui.sh"
    "$PROJECT_ROOT/core/utils.sh"
    "$PROJECT_ROOT/config/default.conf"
    "$PROJECT_ROOT/config/user.conf"
    "$TEST_ROOT/run_all.sh"
    "$TEST_ROOT/test_config.sh"
    "$TEST_ROOT/test_manager.sh"
    "$TEST_ROOT/test_paths.sh"
)

printf '%s\n' '== Bash 语法检查 =='
if ! bash -n "${syntax_files[@]}"; then
    printf '%s\n' '语法检查失败。' >&2
    exit 1
fi
printf '%s\n\n' '语法检查通过。'

test_files=(
    "$TEST_ROOT/test_config.sh"
    "$TEST_ROOT/test_paths.sh"
    "$TEST_ROOT/test_manager.sh"
)

passed=0
failed=0

for test_file in "${test_files[@]}"; do
    printf '== %s ==\n' "$(basename -- "$test_file")"
    if bash "$test_file"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
    printf '\n'
done

printf '测试汇总：通过 %d，失败 %d\n' "$passed" "$failed"
(( failed == 0 ))
