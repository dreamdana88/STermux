#!/usr/bin/env bash

set -u
set -o pipefail

STERMUX_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || {
    printf '无法确定 STermux 项目目录。\n' >&2
    exit 1
}
readonly STERMUX_ROOT

load_core_file() {
    local file="$1"

    if [[ ! -r "$file" ]]; then
        printf '无法读取核心文件：%s\n' "$file" >&2
        exit 1
    fi

    # shellcheck source=/dev/null
    if ! source "$file"; then
        printf '核心文件加载失败：%s\n' "$file" >&2
        exit 1
    fi
}

load_core_file "$STERMUX_ROOT/core/utils.sh"
load_core_file "$STERMUX_ROOT/core/config.sh"
load_core_file "$STERMUX_ROOT/core/ui.sh"

set_sillytavern_path() {
    local candidate="$1"
    local canonical_path

    canonical_path="$(path_canonicalize_directory "$candidate")" || return 1
    ST_PATH="$canonical_path"

    if ! config_set_value "ST_PATH" "$ST_PATH"; then
        ui_error "SillyTavern 路径有效，但无法保存到 config/user.conf。"
        return 1
    fi

    return 0
}

prompt_for_sillytavern_path() {
    local input
    local candidate

    while true; do
        printf '\n请输入 SillyTavern 安装目录（直接回车取消）：\n> '
        if ! IFS= read -r input; then
            ui_warning "输入已结束，取消设置路径。"
            return 1
        fi

        if [[ -z "$input" ]]; then
            ui_info "已取消设置路径。"
            return 1
        fi

        candidate="$(path_normalize_input "$input")"
        if ! sillytavern_path_is_valid "$candidate"; then
            ui_error "该目录不是可识别的 SillyTavern 安装：$candidate"
            ui_info "目录中需要包含 start.sh、server.js，以及名称为 sillytavern 的 package.json。"
            continue
        fi

        if set_sillytavern_path "$candidate"; then
            ui_success "已保存 SillyTavern 路径：$ST_PATH"
            return 0
        fi

        return 1
    done
}

detect_sillytavern_path() {
    local configured_path
    local common_path

    configured_path="$(path_normalize_input "${ST_PATH:-}")"
    if sillytavern_path_is_valid "$configured_path"; then
        ST_PATH="$(path_canonicalize_directory "$configured_path")" || return 1
        return 0
    fi

    common_path="$(sillytavern_find_common_path)" || common_path=""
    if [[ -n "$common_path" ]]; then
        if set_sillytavern_path "$common_path"; then
            ui_success "已在常见目录找到 SillyTavern：$ST_PATH"
            return 0
        fi
        return 1
    fi

    ui_warning "未找到有效的 SillyTavern 安装。"
    prompt_for_sillytavern_path
}

launch_sillytavern() {
    local launch_status

    if ! sillytavern_path_is_valid "${ST_PATH:-}"; then
        ui_warning "当前 SillyTavern 路径无效，需要重新设置。"
        if ! detect_sillytavern_path; then
            return 1
        fi
    fi

    ui_info "正在从以下目录启动 SillyTavern："
    printf '%s\n\n' "$ST_PATH"

    (
        cd -- "$ST_PATH" || exit 1
        bash ./start.sh
    )
    launch_status=$?

    case "$launch_status" in
        0)
            ui_success "SillyTavern 已停止。"
            ;;
        130)
            ui_info "SillyTavern 已由用户停止。"
            ;;
        *)
            ui_error "SillyTavern 启动或运行失败（退出码：$launch_status）。"
            ui_info "请检查上方 SillyTavern 输出以及当前安装目录。"
            return "$launch_status"
            ;;
    esac

    return 0
}

show_main_menu() {
    local installation_status

    if sillytavern_path_is_valid "${ST_PATH:-}"; then
        installation_status="已安装：$ST_PATH"
    else
        installation_status="未找到有效安装"
    fi

    ui_main_menu "$installation_status"
}

main_loop() {
    local choice

    while true; do
        show_main_menu
        printf '请选择操作：'

        if ! IFS= read -r choice; then
            printf '\n'
            ui_info "输入已结束，退出 STermux。"
            return 0
        fi

        case "$choice" in
            1)
                launch_sillytavern || true
                ui_pause
                ;;
            2)
                prompt_for_sillytavern_path || true
                ui_pause
                ;;
            0)
                ui_info "已退出 STermux。"
                return 0
                ;;
            *)
                ui_warning "无效选项，请输入 0、1 或 2。"
                ui_pause
                ;;
        esac
    done
}

main() {
    ui_initialize

    if ! config_load; then
        ui_error "配置加载失败，STermux 无法继续启动。"
        return 1
    fi

    detect_sillytavern_path || true
    main_loop
}

main "$@"
