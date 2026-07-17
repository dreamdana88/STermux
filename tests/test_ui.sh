#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-ui.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-ui.*) rm -rf -- "$TEST_TMP_ROOT" ;;
        *) printf '拒绝清理非测试目录：%s\n' "$TEST_TMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

STERMUX_ROOT="$PROJECT_ROOT"
source "$PROJECT_ROOT/core/ui.sh"
source "$PROJECT_ROOT/core/version.sh"

COLUMNS=44
COLOR_ENABLED=false
unset NO_COLOR || true
ui_initialize

menu_output="$(ui_main_menu "1.15.0" "v0.0.1" "已开启")"
[[ "$menu_output" == *"SillyTavern : 1.15.0"* ]] || fail "首页缺少 SillyTavern 版本"
[[ "$menu_output" == *"STermux     : v0.0.1"* ]] || fail "首页缺少 STermux 版本"
[[ "$menu_output" == *"自动备份    : 已开启"* ]] || fail "首页缺少自动备份已开启状态"
[[ "$menu_output" == *"[SillyTavern 管理]"* ]] || fail "已安装菜单缺少 SillyTavern 管理分组"
[[ "$menu_output" == *"[系统]"* ]] || fail "已安装菜单缺少系统分组"
[[ "$menu_output" == *"1. 启动 SillyTavern"* ]] || fail "已安装菜单缺少启动入口"
[[ "$menu_output" == *"2. SillyTavern 更新中心"* ]] || fail "已安装菜单缺少更新入口"
[[ "$menu_output" == *"3. 第三方扩展管理"* ]] || fail "已安装菜单缺少扩展入口"
[[ "$menu_output" == *"4. 备份与恢复"* ]] || fail "已安装菜单缺少备份入口"
[[ "$menu_output" == *"5. STermux 更新"* ]] || fail "已安装菜单缺少 STermux 更新入口"
[[ "$menu_output" != *"/SillyTavern"* ]] || fail "首页不应显示 SillyTavern 路径"
[[ "$menu_output" != *"Commit"* && "$menu_output" != *"Upstream"* ]] \
    || fail "首页不应显示 Git 技术信息"

closed_output="$(ui_main_menu "版本未知" "v0.0.1" "已关闭")"
[[ "$closed_output" == *"SillyTavern : 版本未知"* ]] || fail "版本读取失败未降级"
[[ "$closed_output" == *"自动备份    : 已关闭"* ]] || fail "首页缺少自动备份已关闭状态"

uninstalled_output="$(ui_uninstalled_menu "v0.0.1")"
[[ "$uninstalled_output" == *"SillyTavern : 未安装"* ]] || fail "未安装状态缺失"
[[ "$uninstalled_output" == *"自动备份    : 未开启"* ]] || fail "未安装时自动备份状态错误"
[[ "$uninstalled_output" == *"1. 安装 SillyTavern"* ]] || fail "未安装菜单缺少安装入口"
[[ "$uninstalled_output" == *"2. 设置已有 SillyTavern 路径"* ]] || fail "未安装菜单缺少路径入口"
[[ "$uninstalled_output" == *"3. STermux 更新"* ]] || fail "未安装菜单缺少自更新入口"
[[ "$uninstalled_output" == *"4. 设置"* ]] || fail "未安装菜单缺少设置入口"
[[ "$uninstalled_output" != *"SillyTavern 更新中心"* ]] || fail "未安装菜单不应显示更新中心"
[[ "$uninstalled_output" != *"第三方扩展管理"* ]] || fail "未安装菜单不应显示扩展管理"
[[ "$uninstalled_output" != *"备份与恢复"* ]] || fail "未安装菜单不应显示备份入口"

while IFS= read -r line; do
    case "$line" in
        =*|-*)
            [[ "$(ui_display_width "$line")" == 44 ]] \
                || fail "分隔线宽度异常：$line"
            ;;
    esac
done <<< "$menu_output"

[[ "$(stermux_version_read)" == "v0.0.1" ]] || fail "无法读取项目 VERSION"
[[ "$(stermux_version_display)" == "v0.0.1" ]] || fail "VERSION 展示错误"
mkdir -p -- "$TEST_TMP_ROOT/missing" "$TEST_TMP_ROOT/invalid"
STERMUX_ROOT="$TEST_TMP_ROOT/missing"
[[ "$(stermux_version_display)" == "版本未知" ]] || fail "VERSION 缺失未降级"
printf '%s\n' 'release-one' > "$TEST_TMP_ROOT/invalid/VERSION"
STERMUX_ROOT="$TEST_TMP_ROOT/invalid"
[[ "$(stermux_version_display)" == "版本未知" ]] || fail "VERSION 异常未降级"
STERMUX_ROOT="$PROJECT_ROOT"

COLOR_ENABLED=true
unset NO_COLOR || true
ui_terminal_supports_color() { return 1; }
ui_initialize
[[ -z "$UI_COLOR_GREEN" ]] || fail "不支持颜色的终端没有降级为纯文本"

ui_terminal_supports_color() { return 0; }
ui_initialize
[[ -n "$UI_COLOR_GREEN" ]] || fail "颜色开启时没有初始化颜色"
colored_text="$(ui_colorize success '中文AB')"
[[ "$colored_text" == *$'\033[32m'* ]] || fail "成功状态没有绿色"
[[ "$(ui_display_width "$colored_text")" == 6 ]] || fail "ANSI 颜色影响显示宽度"

COLOR_ENABLED=false
ui_initialize
[[ -z "$UI_COLOR_GREEN" ]] || fail "颜色配置关闭后仍有 ANSI 颜色"
[[ "$(ui_colorize success '成功')" == "成功" ]] || fail "颜色关闭未降级为纯文本"

COLOR_ENABLED=true
NO_COLOR=''
ui_initialize
[[ -z "$UI_COLOR_CYAN" ]] || fail "NO_COLOR 为空值时没有关闭颜色"
NO_COLOR=1
ui_initialize
[[ -z "$UI_COLOR_CYAN" ]] || fail "NO_COLOR 没有关闭颜色"
unset NO_COLOR

ui_terminal_supports_color() { [[ "${TERM:-}" != dumb ]]; }
TERM=dumb
ui_initialize
[[ -z "$UI_COLOR_CYAN" ]] || fail "TERM=dumb 没有降级为纯文本"

printf '%s\n' 'PASS: 动态菜单、版本、状态、颜色与中英文宽度测试通过'
