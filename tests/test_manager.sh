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
        "$PROJECT_ROOT/core/autostart.sh" \
        "$PROJECT_ROOT/core/backup.sh" \
        "$PROJECT_ROOT/core/git.sh" \
        "$PROJECT_ROOT/core/ui.sh" \
        "$PROJECT_ROOT/core/utils.sh" \
        "$PROJECT_ROOT/core/version.sh" \
        "$target/core/" || return 1
    cp -- \
        "$PROJECT_ROOT/modules/sillytavern/install.sh" \
        "$PROJECT_ROOT/modules/sillytavern/backup-rules.sh" \
        "$PROJECT_ROOT/modules/sillytavern/update.sh" \
        "$PROJECT_ROOT/modules/sillytavern/extensions.sh" \
        "$target/modules/sillytavern/" || return 1
    cp -- "$PROJECT_ROOT/modules/stermux/update.sh" "$target/modules/stermux/update.sh" || return 1
    cp -- "$PROJECT_ROOT/config/default.conf" "$target/config/default.conf" || return 1
    cp -- "$PROJECT_ROOT/VERSION" "$target/VERSION" || return 1

    # 测试用户配置必须由测试自身创建，严禁复制项目真实 config/user.conf。
    printf '%s\n' '# Isolated test user configuration. Do not copy production user.conf.' \
        > "$target/config/user.conf" || return 1
    printf '%s\n' '# Isolated extension policy. Do not copy production policy.' \
        > "$target/config/extension-policy.conf" || return 1
}

create_fake_sillytavern() {
    local target="$1"
    local launch_line="$2"

    mkdir -p -- "$target/data/default-user/chats" || return 1
    printf '%s\n' '#!/usr/bin/env bash' "$launch_line" > "$target/start.sh" || return 1
    printf '%s\n' '// test fixture' > "$target/server.js" || return 1
    printf '%s\n' '{"name":"sillytavern","version":"1.15.0"}' > "$target/package.json" || return 1
    printf '%s\n' 'dataRoot: ./data' > "$target/config.yaml" || return 1
    printf '%s\n' 'isolated chat fixture' > "$target/data/default-user/chats/chat.txt" || return 1
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
        "$PROJECT_ROOT/core/autostart.sh" \
        "$PROJECT_ROOT/core/backup.sh" \
        "$PROJECT_ROOT/core/git.sh" \
        "$PROJECT_ROOT/core/ui.sh" \
        "$PROJECT_ROOT/core/utils.sh" \
        "$PROJECT_ROOT/core/version.sh" \
        "$poison_source/core/" || return 1
    cp -- \
        "$PROJECT_ROOT/modules/sillytavern/install.sh" \
        "$PROJECT_ROOT/modules/sillytavern/backup-rules.sh" \
        "$PROJECT_ROOT/modules/sillytavern/update.sh" \
        "$PROJECT_ROOT/modules/sillytavern/extensions.sh" \
        "$poison_source/modules/sillytavern/" || return 1
    cp -- "$PROJECT_ROOT/modules/stermux/update.sh" "$poison_source/modules/stermux/update.sh" || return 1
    cp -- "$PROJECT_ROOT/config/default.conf" "$poison_source/config/default.conf" || return 1
    cp -- "$PROJECT_ROOT/VERSION" "$poison_source/VERSION" || return 1

    printf -v quoted_forbidden_path '%q' "$forbidden_install"
    printf 'ST_PATH=%s\n' "$quoted_forbidden_path" > "$poison_source/config/user.conf" || return 1
    printf '%s\n' '# Poison isolation policy fixture.' \
        > "$poison_source/config/extension-policy.conf" || return 1

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
[[ "$output" == *"SillyTavern : 1.15.0"* ]] || fail "主菜单未显示本地 SillyTavern 版本"
[[ "$output" == *"STermux     : v0.0.1"* ]] || fail "主菜单未显示 STermux VERSION"
[[ "$output" == *"自动备份    : 已关闭"* ]] || fail "Phase 5 未实现时自动备份状态不正确"
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

self_update_output="$(printf '5\n3\n\n0\n0\n' | HOME="$test_home" bash "$isolated_project/manager.sh" 2>&1)"
self_update_status=$?
(( self_update_status == 0 )) || fail "STermux 更新菜单返回退出码 $self_update_status"
[[ "$self_update_output" == *"STermux 更新"* ]] || fail "主菜单未进入 STermux 更新页面"
[[ "$self_update_output" == *"当前版本 : v0.0.1"* ]] || fail "STermux 更新页面未使用统一 VERSION"
[[ "$self_update_output" == *"STermux 更新技术详情"* ]] || fail "STermux 更新页面缺少技术详情"

extension_menu_output="$(printf '3\n7\n\n0\n0\n' | HOME="$test_home" bash "$isolated_project/manager.sh" 2>&1)"
extension_menu_status=$?
(( extension_menu_status == 0 )) || fail "第三方扩展菜单返回退出码 $extension_menu_status"
[[ "$extension_menu_output" == *"第三方扩展"* ]] || fail "主菜单未进入第三方扩展管理"
[[ "$extension_menu_output" == *"4. 更新全部允许自动更新的扩展"* ]] || fail "扩展菜单缺少批量更新入口"
[[ "$extension_menu_output" == *"第三方扩展更新策略"* ]] || fail "扩展菜单缺少策略查看入口"

backup_menu_output="$(printf '4\n1\n\n2\n\n0\n0\n' | HOME="$test_home" bash "$isolated_project/manager.sh" 2>&1)"
backup_menu_status=$?
(( backup_menu_status == 0 )) || fail "备份菜单返回退出码 $backup_menu_status"
[[ "$backup_menu_output" == *"备份与恢复"* ]] || fail "主菜单未进入备份与恢复页面"
[[ "$backup_menu_output" == *"手动备份创建成功"* ]] || fail "管理器未能创建隔离 manual 备份"
[[ "$backup_menu_output" == *"手动备份"* ]] || fail "备份列表未使用中文手动备份类型"
find "$isolated_project/backups/sillytavern" -mindepth 1 -maxdepth 1 -type d | grep -q . \
    || fail "隔离管理器没有生成备份目录"

settings_output="$(printf '6\n4\n\n5\n\n0\n0\n' | HOME="$test_home" SHELL=/bin/bash bash "$isolated_project/manager.sh" 2>&1)"
settings_status=$?
(( settings_status == 0 )) || fail "设置菜单返回退出码 $settings_status"
[[ "$settings_output" == *"2. 脚本自启：已关闭（Bash）"* ]] || fail "设置菜单未显示脚本自启状态"
[[ "$settings_output" == *"3. 颜色显示：已开启"* ]] || fail "设置菜单未显示颜色状态"
[[ "$settings_output" == *"4. 查看当前 SillyTavern 路径"* ]] || fail "设置菜单缺少路径信息入口"
[[ "$settings_output" == *"5. 查看 STermux 版本信息"* ]] || fail "设置菜单缺少版本信息入口"
[[ "$settings_output" == *"当前 SillyTavern 路径："* ]] || fail "设置页面无法查看当前路径"
[[ "$settings_output" == *"STermux 版本：v0.0.1"* ]] || fail "设置页面无法查看 STermux 版本"
[[ "$settings_output" != *"[路径]"* && "$settings_output" != *"[启动]"* ]] \
    || fail "设置页不应为单个功能增加分组标题"

settings_enable_output="$(printf '6\n2\ny\n\n0\n0\n' | HOME="$test_home" SHELL=/bin/bash bash "$isolated_project/manager.sh" 2>&1)"
settings_enable_status=$?
(( settings_enable_status == 0 )) || fail "设置菜单开启自动进入失败"
[[ "$settings_enable_output" == *"已开启自动进入 STermux"* ]] || fail "设置菜单缺少开启成功提示"
grep -Fq '# >>> STermux autostart >>>' "$test_home/.bashrc" || fail "设置菜单未写入自动进入托管区域"

settings_disable_output="$(printf '6\n2\ny\n\n0\n0\n' | HOME="$test_home" SHELL=/bin/bash bash "$isolated_project/manager.sh" 2>&1)"
settings_disable_status=$?
(( settings_disable_status == 0 )) || fail "设置菜单关闭自动进入失败"
[[ "$settings_disable_output" == *"已关闭自动进入 STermux"* ]] || fail "设置菜单缺少关闭成功提示"
if grep -Fq '# >>> STermux autostart >>>' "$test_home/.bashrc"; then
    fail "设置菜单关闭后仍保留自动进入托管区域"
fi

settings_color_output="$(printf '6\n3\ny\n\n0\n0\n' | HOME="$test_home" SHELL=/bin/bash bash "$isolated_project/manager.sh" 2>&1)"
settings_color_status=$?
(( settings_color_status == 0 )) || fail "设置菜单关闭颜色失败"
[[ "$settings_color_output" == *"已关闭终端颜色显示"* ]] || fail "设置菜单缺少关闭颜色成功提示"
grep -Fxq 'COLOR_ENABLED=false' "$isolated_project/config/user.conf" \
    || fail "颜色设置未保存到隔离 user.conf"

empty_project="$TEST_TMP_ROOT/empty-project"
create_isolated_project "$empty_project" || fail "无法创建空安装隔离项目"

empty_output="$(printf '0\n' | HOME="$TEST_TMP_ROOT/no-install-home" bash "$empty_project/manager.sh" 2>&1)"
empty_status=$?
(( empty_status == 0 )) || fail "无安装流程返回退出码 $empty_status"
[[ "$empty_output" == *"SillyTavern : 未安装"* ]] || fail "无安装环境未显示新版未安装摘要"
[[ "$empty_output" == *"自动备份    : 未开启"* ]] || fail "无安装环境自动备份状态错误"
[[ "$empty_output" == *"1. 安装 SillyTavern"* ]] || fail "无安装环境未显示安装入口"
[[ "$empty_output" == *"2. 设置已有 SillyTavern 路径"* ]] || fail "无安装环境未显示已有路径入口"
[[ "$empty_output" != *"SillyTavern 更新中心"* ]] || fail "无安装环境不应显示更新中心"
[[ "$empty_output" != *"第三方扩展管理"* ]] || fail "无安装环境不应显示扩展管理"
[[ "$empty_output" != *"备份与恢复"* ]] || fail "无安装环境不应显示备份入口"
if grep -Eq '^ST_PATH=' "$empty_project/config/user.conf"; then
    fail "取消路径设置后仍写入了 ST_PATH"
fi

printf '%s\n' 'PASS: 菜单、配置隔离、Fixture 启动及取消流程测试通过'
