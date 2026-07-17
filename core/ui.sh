#!/usr/bin/env bash

UI_COLOR_RESET=''
UI_COLOR_CYAN=''
UI_COLOR_BLUE=''
UI_COLOR_GREEN=''
UI_COLOR_YELLOW=''
UI_COLOR_RED=''
UI_COLOR_GRAY=''
UI_COLOR_WHITE=''
UI_LAYOUT_WIDTH=44

ui_terminal_supports_color() {
    [[ -t 1 && -n "${TERM:-}" && "${TERM:-}" != "dumb" ]]
}

ui_initialize() {
    UI_COLOR_RESET=''
    UI_COLOR_CYAN=''
    UI_COLOR_BLUE=''
    UI_COLOR_GREEN=''
    UI_COLOR_YELLOW=''
    UI_COLOR_RED=''
    UI_COLOR_GRAY=''
    UI_COLOR_WHITE=''

    if [[ "${COLOR_ENABLED:-true}" == true \
        && -z "${NO_COLOR+x}" ]] \
        && ui_terminal_supports_color; then
        UI_COLOR_RESET=$'\033[0m'
        UI_COLOR_CYAN=$'\033[36m'
        UI_COLOR_BLUE="$UI_COLOR_CYAN"
        UI_COLOR_GREEN=$'\033[32m'
        UI_COLOR_YELLOW=$'\033[33m'
        UI_COLOR_RED=$'\033[31m'
        UI_COLOR_GRAY=$'\033[90m'
        UI_COLOR_WHITE=$'\033[37m'
    fi

    UI_LAYOUT_WIDTH="$(ui_terminal_width)"
}

ui_terminal_width() {
    local columns="${COLUMNS:-44}"

    [[ "$columns" =~ ^[1-9][0-9]*$ ]] || columns=44
    if (( columns > 52 )); then
        columns=52
    fi
    printf '%s\n' "$columns"
}

ui_strip_ansi() {
    local text="$1"
    local ansi_pattern=$'\033''\[[0-9;]*m'

    while [[ "$text" =~ $ansi_pattern ]]; do
        text="${text/"${BASH_REMATCH[0]}"/}"
    done
    printf '%s' "$text"
}

ui_display_width() {
    local text
    local character
    local width=0
    local index
    local character_value
    local byte_length=1

    text="$(ui_strip_ansi "$1")"
    for ((index = 0; index < ${#text}; index++)); do
        character="${text:index:1}"
        printf -v character_value '%d' "'$character"
        (( character_value >= 0 )) || character_value=$((character_value + 256))
        if (( character_value >= 32 && character_value <= 126 )); then
            width=$((width + 1))
        elif (( character_value > 255 )); then
            # UTF-8 locale 下 Bash 已按完整字符切片，不能再按字节数跳过后续字符。
            width=$((width + 2))
        else
            # C locale 下 Bash 按 UTF-8 字节切片，只在此分支跳过当前字符的续字节。
            width=$((width + 2))
            if (( character_value >= 240 )); then
                byte_length=4
            elif (( character_value >= 224 )); then
                byte_length=3
            elif (( character_value >= 192 )); then
                byte_length=2
            else
                byte_length=1
            fi
            index=$((index + byte_length - 1))
        fi
    done
    printf '%s\n' "$width"
}

ui_repeat_char() {
    local character="$1"
    local count="${2:-$UI_LAYOUT_WIDTH}"
    local output=""

    while (( count > 0 )); do
        output+="$character"
        count=$((count - 1))
    done
    printf '%s' "$output"
}

ui_color_code() {
    case "$1" in
        title|info) printf '%s' "$UI_COLOR_CYAN" ;;
        success) printf '%s' "$UI_COLOR_GREEN" ;;
        warning) printf '%s' "$UI_COLOR_YELLOW" ;;
        error) printf '%s' "$UI_COLOR_RED" ;;
        secondary) printf '%s' "$UI_COLOR_GRAY" ;;
        primary) printf '%s' "$UI_COLOR_WHITE" ;;
        *) printf '%s' '' ;;
    esac
}

ui_colorize() {
    local role="$1"
    local text="$2"
    local color

    color="$(ui_color_code "$role")"
    if [[ -n "$color" ]]; then
        printf '%s%s%s' "$color" "$text" "$UI_COLOR_RESET"
    else
        printf '%s' "$text"
    fi
}

ui_print_centered() {
    local text="$1"
    local role="${2:-default}"
    local width
    local padding

    width="$(ui_display_width "$text")"
    padding=$(( (UI_LAYOUT_WIDTH - width + 1) / 2 ))
    (( padding > 0 )) || padding=0
    printf '%*s' "$padding" ''
    ui_colorize "$role" "$text"
    printf '\n'
}

ui_primary_line() {
    ui_colorize primary "$1"
    printf '\n'
}

ui_secondary_line() {
    ui_colorize secondary "$1"
    printf '\n'
}

ui_separator() {
    local character="${1:--}"
    local role="${2:-title}"

    ui_colorize "$role" "$(ui_repeat_char "$character")"
    printf '\n'
}

ui_brand_header() {
    ui_separator '=' title
    ui_print_centered 'STermux' title
    ui_print_centered '仅发布在外神们茶话会社区'
    ui_separator '=' title
}

ui_page_header() {
    local title="$1"

    ui_separator '=' title
    ui_print_centered "$title" title
    ui_separator '=' title
}

ui_group_title() {
    printf '['
    ui_colorize title "$1"
    printf ']\n'
}

ui_status_line() {
    local label="$1"
    local value="$2"
    local role="${3:-default}"
    local label_width
    local padding

    label_width="$(ui_display_width "$label")"
    padding=$((12 - label_width))
    (( padding > 0 )) || padding=0
    printf '%s%*s: ' "$label" "$padding" ''
    ui_colorize "$role" "$value"
    printf '\n'
}

ui_menu_prompt() {
    printf '请选择 [%s]: ' "$1"
}

ui_clear() {
    if [[ -t 1 && -n "${TERM:-}" ]] && command -v clear >/dev/null 2>&1; then
        clear
    fi
}

ui_info() {
    printf '%s[信息]%s %s\n' "$UI_COLOR_CYAN" "$UI_COLOR_RESET" "$1"
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

    printf '\n按回车键继续...'
    IFS= read -r unused || true
}

ui_main_menu() {
    local sillytavern_version="$1"
    local stermux_version="$2"
    local automatic_backup_status="$3"
    local sillytavern_role=success
    local stermux_role=success
    local backup_role=warning

    [[ "$sillytavern_version" != "版本未知" ]] || sillytavern_role=warning
    [[ "$stermux_version" != "版本未知" ]] || stermux_role=warning
    [[ "$automatic_backup_status" != "已开启" ]] || backup_role=success

    ui_clear
    ui_brand_header
    printf '\n'
    ui_status_line 'SillyTavern' "$sillytavern_version" "$sillytavern_role"
    ui_status_line 'STermux' "$stermux_version" "$stermux_role"
    ui_status_line '自动备份' "$automatic_backup_status" "$backup_role"
    printf '\n'
    ui_separator
    ui_group_title 'SillyTavern 管理'
    printf '\n'
    ui_primary_line '1. 启动 SillyTavern'
    ui_primary_line '2. SillyTavern 更新中心'
    ui_primary_line '3. 第三方扩展管理'
    ui_primary_line '4. 备份与恢复'
    printf '\n'
    ui_group_title '系统'
    printf '\n'
    ui_primary_line '5. STermux 更新'
    ui_primary_line '6. 设置'
    printf '\n'
    ui_primary_line '0. 退出'
    printf '\n'
    ui_separator
}

ui_uninstalled_menu() {
    local stermux_version="$1"
    local stermux_role=success

    [[ "$stermux_version" != "版本未知" ]] || stermux_role=warning

    ui_clear
    ui_brand_header
    printf '\n'
    ui_status_line 'SillyTavern' '未安装' error
    ui_status_line 'STermux' "$stermux_version" "$stermux_role"
    ui_status_line '自动备份' '未开启' warning
    printf '\n'
    ui_separator
    ui_group_title 'SillyTavern'
    printf '\n'
    ui_primary_line '1. 安装 SillyTavern'
    ui_primary_line '2. 设置已有 SillyTavern 路径'
    printf '\n'
    ui_group_title '系统'
    printf '\n'
    ui_primary_line '3. STermux 更新'
    ui_primary_line '4. 设置'
    printf '\n'
    ui_primary_line '0. 退出'
    printf '\n'
    ui_separator
}
