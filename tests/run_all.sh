#!/usr/bin/env bash

set -u
set -o pipefail

TEST_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
PROJECT_ROOT="$(CDPATH= cd -- "$TEST_ROOT/.." && pwd -P)" || exit 1

syntax_files=(
    "$PROJECT_ROOT/manager.sh"
    "$PROJECT_ROOT/core/config.sh"
    "$PROJECT_ROOT/core/autostart.sh"
    "$PROJECT_ROOT/core/backup.sh"
    "$PROJECT_ROOT/core/uninstall.sh"
    "$PROJECT_ROOT/core/git.sh"
    "$PROJECT_ROOT/core/ui.sh"
    "$PROJECT_ROOT/core/utils.sh"
    "$PROJECT_ROOT/core/version.sh"
    "$PROJECT_ROOT/modules/sillytavern/update.sh"
    "$PROJECT_ROOT/modules/sillytavern/backup-rules.sh"
    "$PROJECT_ROOT/modules/sillytavern/install.sh"
    "$PROJECT_ROOT/modules/sillytavern/extensions.sh"
    "$PROJECT_ROOT/modules/stermux/update.sh"
    "$PROJECT_ROOT/config/default.conf"
    "$TEST_ROOT/run_all.sh"
    "$TEST_ROOT/test_config.sh"
    "$TEST_ROOT/test_autostart.sh"
    "$TEST_ROOT/test_backup.sh"
    "$TEST_ROOT/test_uninstall.sh"
    "$TEST_ROOT/test_git.sh"
    "$TEST_ROOT/test_install.sh"
    "$TEST_ROOT/test_self_update.sh"
    "$TEST_ROOT/test_extensions.sh"
    "$TEST_ROOT/test_manager.sh"
    "$TEST_ROOT/test_paths.sh"
    "$TEST_ROOT/test_ui.sh"
    "$TEST_ROOT/test_version.sh"
)

printf '%s\n' '== Bash 语法检查 =='
# 真实 config/user.conf 可能包含用户设备的绝对路径，自动测试禁止读取它。
if ! bash -n "${syntax_files[@]}"; then
    printf '%s\n' '语法检查失败。' >&2
    exit 1
fi
printf '%s\n\n' '语法检查通过。'

test_files=(
    "$TEST_ROOT/test_config.sh"
    "$TEST_ROOT/test_autostart.sh"
    "$TEST_ROOT/test_backup.sh"
    "$TEST_ROOT/test_uninstall.sh"
    "$TEST_ROOT/test_paths.sh"
    "$TEST_ROOT/test_ui.sh"
    "$TEST_ROOT/test_git.sh"
    "$TEST_ROOT/test_install.sh"
    "$TEST_ROOT/test_self_update.sh"
    "$TEST_ROOT/test_extensions.sh"
    "$TEST_ROOT/test_version.sh"
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
