#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-manager.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-manager.*)
            rm -rf -- "$TEST_TMP_ROOT"
            ;;
        *)
            printf '拒绝清理非测试目录：%s\n' "$TEST_TMP_ROOT" >&2
            ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

isolated_project="$TEST_TMP_ROOT/project"
test_home="$TEST_TMP_ROOT/home"
fake_install="$test_home/SillyTavern"

mkdir -p -- "$isolated_project/core" "$isolated_project/config" "$isolated_project/modules/sillytavern" "$fake_install" || exit 1
cp -- "$PROJECT_ROOT/manager.sh" "$isolated_project/manager.sh" || exit 1
cp -- "$PROJECT_ROOT/core/config.sh" "$PROJECT_ROOT/core/git.sh" "$PROJECT_ROOT/core/ui.sh" "$PROJECT_ROOT/core/utils.sh" "$isolated_project/core/" || exit 1
cp -- "$PROJECT_ROOT/modules/sillytavern/update.sh" "$isolated_project/modules/sillytavern/update.sh" || exit 1
cp -- "$PROJECT_ROOT/config/default.conf" "$PROJECT_ROOT/config/user.conf" "$isolated_project/config/" || exit 1
printf '%s\n' 'ST_PATH="$HOME/ConfiguredMissing"' > "$isolated_project/config/default.conf"

printf '%s\n' '#!/usr/bin/env bash' 'printf "TEST_MANAGER_LAUNCH_OK:%s\n" "$PWD"' > "$fake_install/start.sh"
printf '%s\n' '// test fixture' > "$fake_install/server.js"
printf '%s\n' '{"name":"sillytavern"}' > "$fake_install/package.json"

output="$(printf '1\n\n0\n' | HOME="$test_home" bash "$isolated_project/manager.sh" 2>&1)"
status=$?
(( status == 0 )) || fail "manager.sh 返回退出码 $status"
[[ "$output" == *"TEST_MANAGER_LAUNCH_OK"* ]] || fail "未调用 SillyTavern start.sh"

unset ST_PATH
source "$isolated_project/config/user.conf"
[[ -d "$ST_PATH" ]] || fail "自动发现的路径未正确保存"
[[ "$ST_PATH" == */home/SillyTavern ]] || fail "保存了意外的安装路径"

update_menu_output="$(printf '2\n0\n0\n' | HOME="$test_home" bash "$isolated_project/manager.sh" 2>&1)"
update_menu_status=$?
(( update_menu_status == 0 )) || fail "更新中心菜单返回退出码 $update_menu_status"
[[ "$update_menu_output" == *"Upstream"* ]] || fail "主菜单未进入更新中心"

empty_project="$TEST_TMP_ROOT/empty-project"
mkdir -p -- "$empty_project/core" "$empty_project/config" "$empty_project/modules/sillytavern" || exit 1
cp -- "$PROJECT_ROOT/manager.sh" "$empty_project/manager.sh" || exit 1
cp -- "$PROJECT_ROOT/core/config.sh" "$PROJECT_ROOT/core/git.sh" "$PROJECT_ROOT/core/ui.sh" "$PROJECT_ROOT/core/utils.sh" "$empty_project/core/" || exit 1
cp -- "$PROJECT_ROOT/modules/sillytavern/update.sh" "$empty_project/modules/sillytavern/update.sh" || exit 1
cp -- "$PROJECT_ROOT/config/default.conf" "$PROJECT_ROOT/config/user.conf" "$empty_project/config/" || exit 1

empty_output="$(printf '\n0\n' | HOME="$TEST_TMP_ROOT/no-install-home" bash "$empty_project/manager.sh" 2>&1)"
empty_status=$?
(( empty_status == 0 )) || fail "无安装流程返回退出码 $empty_status"
if grep -Eq '^ST_PATH=' "$empty_project/config/user.conf"; then
    fail "取消路径设置后仍写入了 ST_PATH"
fi

printf '%s\n' 'PASS: 菜单、常见路径保存、启动及取消流程测试通过'
