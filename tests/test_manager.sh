#!/usr/bin/env bash

set -u
set -o pipefail

DISCOVERED_PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
PROJECT_ROOT="${STERMUX_TEST_PROJECT_ROOT:-$DISCOVERED_PROJECT_ROOT}"
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

create_isolated_project() {
    local target="$1"

    mkdir -p -- "$target/core" "$target/config" "$target/modules/sillytavern" "$target/modules/stermux" || return 1
    cp -- "$PROJECT_ROOT/manager.sh" "$target/manager.sh" || return 1
    cp -- \
        "$PROJECT_ROOT/core/config.sh" \
        "$PROJECT_ROOT/core/git.sh" \
        "$PROJECT_ROOT/core/ui.sh" \
        "$PROJECT_ROOT/core/utils.sh" \
        "$target/core/" || return 1
    cp -- \
        "$PROJECT_ROOT/modules/sillytavern/install.sh" \
        "$PROJECT_ROOT/modules/sillytavern/update.sh" \
        "$target/modules/sillytavern/" || return 1
    cp -- "$PROJECT_ROOT/modules/stermux/update.sh" "$target/modules/stermux/update.sh" || return 1
    cp -- "$PROJECT_ROOT/config/default.conf" "$target/config/default.conf" || return 1

    # 测试用户配置必须由测试自身创建，严禁复制项目真实 config/user.conf。
    printf '%s\n' '# Isolated test user configuration. Do not copy production user.conf.' \
        > "$target/config/user.conf" || return 1
}

create_fake_sillytavern() {
    local target="$1"
    local launch_line="$2"

    mkdir -p -- "$target" || return 1
    printf '%s\n' '#!/usr/bin/env bash' "$launch_line" > "$target/start.sh" || return 1
    printf '%s\n' '// test fixture' > "$target/server.js" || return 1
    printf '%s\n' '{"name":"sillytavern"}' > "$target/package.json" || return 1
}

run_user_config_isolation_regression() {
    local poison_source="$TEST_TMP_ROOT/poison-source"
    local forbidden_install="$TEST_TMP_ROOT/forbidden-real-sillytavern"
    local forbidden_marker="$TEST_TMP_ROOT/forbidden-start-was-called"
    local nested_output
    local nested_status
    local quoted_forbidden_path
    local quoted_marker_path

    [[ "${STERMUX_TEST_ISOLATION_GUARD:-0}" == "1" ]] && return 0

    mkdir -p -- "$poison_source/core" "$poison_source/config" \
        "$poison_source/modules/sillytavern" "$poison_source/modules/stermux" || return 1
    cp -- "$PROJECT_ROOT/manager.sh" "$poison_source/manager.sh" || return 1
    cp -- \
        "$PROJECT_ROOT/core/config.sh" \
        "$PROJECT_ROOT/core/git.sh" \
        "$PROJECT_ROOT/core/ui.sh" \
        "$PROJECT_ROOT/core/utils.sh" \
        "$poison_source/core/" || return 1
    cp -- \
        "$PROJECT_ROOT/modules/sillytavern/install.sh" \
        "$PROJECT_ROOT/modules/sillytavern/update.sh" \
        "$poison_source/modules/sillytavern/" || return 1
    cp -- "$PROJECT_ROOT/modules/stermux/update.sh" "$poison_source/modules/stermux/update.sh" || return 1
    cp -- "$PROJECT_ROOT/config/default.conf" "$poison_source/config/default.conf" || return 1

    printf -v quoted_forbidden_path '%q' "$forbidden_install"
    printf 'ST_PATH=%s\n' "$quoted_forbidden_path" > "$poison_source/config/user.conf" || return 1

    printf -v quoted_marker_path '%q' "$forbidden_marker"
    create_fake_sillytavern "$forbidden_install" \
        "printf 'FORBIDDEN_REAL_START_CALLED\\n' > $quoted_marker_path; exit 99" || return 1

    nested_output="$(
        STERMUX_TEST_PROJECT_ROOT="$poison_source" \
        STERMUX_TEST_ISOLATION_GUARD=1 \
        bash "${BASH_SOURCE[0]}" 2>&1
    )"
    nested_status=$?

    if [[ -e "$forbidden_marker" ]]; then
        fail "隔离回归失败：测试启动了来源项目 user.conf 指向的 SillyTavern"
    fi
    if (( nested_status != 0 )); then
        printf '%s\n' "$nested_output" >&2
        fail "带有效绝对 ST_PATH 的来源 user.conf 导致隔离测试失败"
    fi

    return 0
}

# 必须先验证来源 user.conf 隔离，再运行任何包含菜单选项 1 的测试。
run_user_config_isolation_regression || fail "用户配置隔离回归测试失败"

isolated_project="$TEST_TMP_ROOT/project"
test_home="$TEST_TMP_ROOT/home"
fake_install="$test_home/SillyTavern"

create_isolated_project "$isolated_project" || fail "无法创建隔离项目"
printf '%s\n' 'ST_PATH="$HOME/ConfiguredMissing"' > "$isolated_project/config/default.conf"
create_fake_sillytavern "$fake_install" 'printf "TEST_MANAGER_LAUNCH_OK:%s\n" "$PWD"' \
    || fail "无法创建 SillyTavern Fixture"

output="$(printf '1\n\n0\n' | HOME="$test_home" bash "$isolated_project/manager.sh" 2>&1)"
status=$?
(( status == 0 )) || fail "manager.sh 返回退出码 $status"
[[ "$output" == *"TEST_MANAGER_LAUNCH_OK"* ]] || fail "未调用 SillyTavern Fixture start.sh"
[[ "$output" != *"1. 安装 SillyTavern"* ]] || fail "已有 SillyTavern 时仍显示安装入口"
[[ "$output" == *"SillyTavern 首次启动需要安装 Node Modules"* ]] || fail "首次启动缺少 Node Modules 耗时提示"
[[ "$output" == *"此过程可能需要几分钟"* ]] || fail "首次启动缺少耐心等待提示"

unset ST_PATH
source "$isolated_project/config/user.conf"
[[ -d "$ST_PATH" ]] || fail "自动发现的路径未正确保存"
[[ "$ST_PATH" == */home/SillyTavern ]] || fail "保存了意外的安装路径"

update_menu_output="$(printf '2\n4\n\n0\n0\n' | HOME="$test_home" bash "$isolated_project/manager.sh" 2>&1)"
update_menu_status=$?
(( update_menu_status == 0 )) || fail "更新中心菜单返回退出码 $update_menu_status"
[[ "$update_menu_output" == *"更新状态"* ]] || fail "主菜单未进入更新中心"
[[ "$update_menu_output" == *"4. 查看技术详情"* ]] || fail "更新中心缺少技术详情入口"
[[ "$update_menu_output" == *"Upstream"* ]] || fail "技术详情未显示 Upstream"

self_update_output="$(printf '3\n3\n\n0\n0\n' | HOME="$test_home" bash "$isolated_project/manager.sh" 2>&1)"
self_update_status=$?
(( self_update_status == 0 )) || fail "STermux 更新菜单返回退出码 $self_update_status"
[[ "$self_update_output" == *"STermux 更新"* ]] || fail "主菜单未进入 STermux 更新页面"
[[ "$self_update_output" == *"当前版本：开发版"* ]] || fail "STermux 更新页面缺少开发版显示"
[[ "$self_update_output" == *"STermux 更新技术详情"* ]] || fail "STermux 更新页面缺少技术详情"

empty_project="$TEST_TMP_ROOT/empty-project"
create_isolated_project "$empty_project" || fail "无法创建空安装隔离项目"

empty_output="$(printf '0\n' | HOME="$TEST_TMP_ROOT/no-install-home" bash "$empty_project/manager.sh" 2>&1)"
empty_status=$?
(( empty_status == 0 )) || fail "无安装流程返回退出码 $empty_status"
[[ "$empty_output" == *"SillyTavern：未安装"* ]] || fail "无安装环境未显示未安装状态"
[[ "$empty_output" == *"1. 安装 SillyTavern"* ]] || fail "无安装环境未显示安装入口"
[[ "$empty_output" == *"2. 设置已有 SillyTavern 路径"* ]] || fail "无安装环境未显示已有路径入口"
if grep -Eq '^ST_PATH=' "$empty_project/config/user.conf"; then
    fail "取消路径设置后仍写入了 ST_PATH"
fi

printf '%s\n' 'PASS: 菜单、配置隔离、Fixture 启动及取消流程测试通过'
