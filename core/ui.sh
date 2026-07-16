#!/usr/bin/env bash

ui_initialize() {
    UI_COLOR_RESET=''
    UI_COLOR_BLUE=''
    UI_COLOR_GREEN=''
    UI_COLOR_YELLOW=''
    UI_COLOR_RED=''

    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
        UI_COLOR_RESET=$'\033[0m'
        UI_COLOR_BLUE=$'\033[36m'
        UI_COLOR_GREEN=$'\033[32m'
        UI_COLOR_YELLOW=$'\033[33m'
        UI_COLOR_RED=$'\033[31m'
    fi
}

ui_clear() {
    if [[ -t 1 && -n "${TERM:-}" ]] && command -v clear >/dev/null 2>&1; then
        clear
    fi
}

ui_info() {
    printf '%s[信息]%s %s\n' "$UI_COLOR_BLUE" "$UI_COLOR_RESET" "$1"
}

ui_success() {
    printf '%s[成功]%s %s\n' "$UI_COLOR_GREEN" "$UI_COLOR_RESET" "$1"
}

ui_warning() {
    printf '%s[警告]%s %s\n' "$UI_COLOR_YELLOW" "$UI_COLOR_RESET" "$1"
}

ui_error() {
    printf '%s[错误]%s %s\n' "$UI_COLOR_RED" "$UI_COLOR_RESET" "$1" >&2
}

ui_pause() {
    local unused

    printf '\n按回车键返回主菜单...'
    IFS= read -r unused || true
}

ui_main_menu() {
    local installation_status="$1"

    ui_clear
    printf '%s\n' '╔══════════════════════════════════╗'
    printf '%s\n' '║              STermux             ║'
    printf '%s\n' '║     仅发布在外神们茶话会社区     ║'
    printf '%s\n' '╠══════════════════════════════════╣'
    printf '%s\n' '║ 1. 启动 SillyTavern              ║'
    printf '%s\n' '║ 2. 更新中心                      ║'
    printf '%s\n' '║ 6. 设置 SillyTavern 路径         ║'
    printf '%s\n' '║ 0. 退出                          ║'
    printf '%s\n' '╚══════════════════════════════════╝'
    printf '\nSillyTavern：%s\n\n' "$installation_status"
}

ui_uninstalled_menu() {
    ui_clear
    printf '%s\n' '╔══════════════════════════════════╗'
    printf '%s\n' '║              STermux             ║'
    printf '%s\n' '║     仅发布在外神们茶话会社区     ║'
    printf '%s\n' '╠══════════════════════════════════╣'
    printf '%s\n' '║ 1. 安装 SillyTavern              ║'
    printf '%s\n' '║ 2. 设置已有 SillyTavern 路径     ║'
    printf '%s\n' '║ 0. 退出                          ║'
    printf '%s\n' '╚══════════════════════════════════╝'
    printf '\nSillyTavern：未安装\n\n'
}
