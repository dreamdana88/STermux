#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1

if locale -a 2>/dev/null | grep -Eqi '^C\.utf-?8$'; then
    LC_ALL="$(locale -a 2>/dev/null | grep -Ei '^C\.utf-?8$' | head -n 1)"
    export LC_ALL
fi

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

display_width() {
    local text="$1"
    local character
    local width=0
    local index

    for ((index = 0; index < ${#text}; index++)); do
        character="${text:index:1}"
        if [[ "$character" == [\ -~] ]]; then
            width=$((width + 1))
        else
            width=$((width + 2))
        fi
    done

    printf '%d\n' "$width"
}

source "$PROJECT_ROOT/core/ui.sh"
ui_initialize
menu_output="$(ui_main_menu "测试状态")"

box_line_count=0
while IFS= read -r line; do
    [[ "$line" == ║*║ ]] || continue
    content="${line#║}"
    content="${content%║}"
    width="$(display_width "$content")"
    [[ "$width" == 34 ]] || fail "菜单行显示宽度为 $width，预期为 34：$line"
    box_line_count=$((box_line_count + 1))
done <<< "$menu_output"

[[ "$box_line_count" == 6 ]] || fail "菜单内容行数量异常：$box_line_count"
[[ "$menu_output" == *'║     仅发布在外神们茶话会社区     ║'* ]] || fail "社区标题未使用修正后的居中间距"

printf '%s\n' 'PASS: 中英文混排菜单边框宽度测试通过'
