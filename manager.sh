#!/usr/bin/env bash

set -u
set -o pipefail

STERMUX_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || {
    printf '无法确定 STermux 项目目录。\n' >&2
    exit 1
}
readonly STERMUX_ROOT

load_script_file() {
    local file="$1"

    if [[ ! -r "$file" ]]; then
        printf '无法读取脚本文件：%s\n' "$file" >&2
        exit 1
    fi

    # shellcheck source=/dev/null
    if ! source "$file"; then
        printf '脚本文件加载失败：%s\n' "$file" >&2
        exit 1
    fi
}

load_script_file "$STERMUX_ROOT/core/utils.sh"
load_script_file "$STERMUX_ROOT/core/config.sh"
load_script_file "$STERMUX_ROOT/core/ui.sh"
load_script_file "$STERMUX_ROOT/core/version.sh"
load_script_file "$STERMUX_ROOT/core/autostart.sh"
load_script_file "$STERMUX_ROOT/core/git.sh"
load_script_file "$STERMUX_ROOT/core/backup.sh"
load_script_file "$STERMUX_ROOT/core/uninstall.sh"
load_script_file "$STERMUX_ROOT/modules/stermux/update.sh"
load_script_file "$STERMUX_ROOT/modules/sillytavern/install.sh"
load_script_file "$STERMUX_ROOT/modules/sillytavern/backup-rules.sh"
load_script_file "$STERMUX_ROOT/modules/sillytavern/update.sh"
load_script_file "$STERMUX_ROOT/modules/sillytavern/extensions.sh"

SILLYTAVERN_IS_INSTALLED=false

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

    return 1
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

    if [[ ! -d "$ST_PATH/node_modules" ]]; then
        ui_info "SillyTavern 首次启动需要安装 Node Modules。"
        ui_info "此过程可能需要几分钟，请耐心等待，不要退出 Termux。"
        printf '\n'
    fi

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

open_sillytavern_update_center() {
    if ! sillytavern_path_is_valid "${ST_PATH:-}"; then
        ui_warning "当前 SillyTavern 路径无效，需要重新设置。"
        if ! detect_sillytavern_path; then
            return 1
        fi
    fi

    sillytavern_update_menu
}

open_stermux_update_center() {
    stermux_update_menu
}

open_sillytavern_extensions() {
    if ! sillytavern_path_is_valid "${ST_PATH:-}"; then
        ui_warning "当前 SillyTavern 路径无效，需要重新设置。"
        if ! detect_sillytavern_path; then
            return 1
        fi
    fi

    sillytavern_extensions_menu
}

open_backup_center() {
    if ! sillytavern_path_is_valid "${ST_PATH:-}"; then
        ui_warning "当前 SillyTavern 路径无效，需要重新设置。"
        if ! detect_sillytavern_path; then
            return 1
        fi
    fi

    backup_menu
}

settings_confirm_autostart_change() {
    local action="$1"
    local confirm

    printf '确认%s打开 Termux 时自动进入 STermux？[y/N] ' "$action"
    IFS= read -r confirm || return 1
    [[ "$confirm" == y || "$confirm" == Y ]]
}

settings_toggle_autostart() {
    local action

    AUTOSTART_LAST_BACKUP=""
    autostart_status >/dev/null 2>&1 || true
    case "$AUTOSTART_STATUS" in
        enabled)
            action="关闭"
            if settings_confirm_autostart_change "$action"; then
                if autostart_disable; then
                    ui_success "已关闭自动进入 STermux。"
                else
                    ui_error "$AUTOSTART_LAST_ERROR"
                    return 1
                fi
            else
                ui_info "已取消关闭。"
            fi
            ;;
        disabled)
            action="开启"
            if settings_confirm_autostart_change "$action"; then
                if autostart_enable; then
                    ui_success "已开启自动进入 STermux。"
                else
                    ui_error "$AUTOSTART_LAST_ERROR"
                    return 1
                fi
            else
                ui_info "已取消开启。"
            fi
            ;;
        *)
            ui_error "无法切换脚本自启：${AUTOSTART_LAST_ERROR:-当前配置状态异常}"
            return 1
            ;;
    esac

    if [[ -n "$AUTOSTART_LAST_BACKUP" ]]; then
        ui_info "原 Shell 配置已备份：$AUTOSTART_LAST_BACKUP"
    fi
}

settings_color_status_text() {
    if [[ "${COLOR_ENABLED:-true}" != true ]]; then
        printf '%s\n' "已关闭"
    elif [[ -n "${NO_COLOR+x}" ]]; then
        printf '%s\n' "已关闭（NO_COLOR）"
    else
        printf '%s\n' "已开启"
    fi
}

settings_toggle_color() {
    local target
    local action
    local confirm

    if [[ "${COLOR_ENABLED:-true}" == true ]]; then
        target=false
        action="关闭"
    else
        target=true
        action="开启"
    fi

    printf '确认%s终端颜色显示？[y/N] ' "$action"
    IFS= read -r confirm || return 1
    if [[ "$confirm" != y && "$confirm" != Y ]]; then
        ui_info "已取消${action}。"
        return 0
    fi
    if ! config_set_value "COLOR_ENABLED" "$target"; then
        ui_error "无法保存颜色显示设置。"
        return 1
    fi
    COLOR_ENABLED="$target"
    ui_initialize
    ui_success "已${action}终端颜色显示。"
}

settings_show_sillytavern_path() {
    if sillytavern_path_is_valid "${ST_PATH:-}"; then
        printf '\n当前 SillyTavern 路径：\n%s\n' "$ST_PATH"
    elif [[ -n "${ST_PATH:-}" ]]; then
        printf '\n当前保存的 SillyTavern 路径无效：\n%s\n' "$ST_PATH"
    else
        ui_info "尚未设置 SillyTavern 路径。"
    fi
}

settings_show_version() {
    printf '\nSTermux 版本：%s\n' "$(stermux_version_display)"
}

settings_menu() {
    local choice

    while true; do
        ui_clear
        ui_page_header 'STermux 设置'
        printf '\n'
        printf '1. 设置 SillyTavern 路径\n'
        printf '2. 脚本自启：%s\n' "$(autostart_status_text)"
        printf '3. 颜色显示：%s\n' "$(settings_color_status_text)"
        printf '\n4. 查看当前 SillyTavern 路径\n'
        printf '5. 查看 STermux 版本信息\n'
        printf '\n6. 卸载管理\n'
        printf '\n0. 返回主菜单\n\n'
        ui_menu_prompt '0-6'
        IFS= read -r choice || return 0
        case "$choice" in
            1)
                prompt_for_sillytavern_path || true
                ui_pause
                ;;
            2)
                settings_toggle_autostart || true
                ui_pause
                ;;
            3)
                settings_toggle_color || true
                ui_pause
                ;;
            4)
                settings_show_sillytavern_path
                ui_pause
                ;;
            5)
                settings_show_version
                ui_pause
                ;;
            6)
                uninstall_manager_menu || true
                ui_pause
                ;;
            0)
                return 0
                ;;
            *)
                ui_warning "无效选项，请输入 0 到 6。"
                ui_pause
                ;;
        esac
    done
}

show_main_menu() {
    local sillytavern_version
    local stermux_version

    stermux_version="$(stermux_version_display)"

    if sillytavern_path_is_valid "${ST_PATH:-}"; then
        SILLYTAVERN_IS_INSTALLED=true
        sillytavern_version="$(sillytavern_read_local_version)"
        if [[ "$sillytavern_version" == "unknown" || -z "$sillytavern_version" ]]; then
            sillytavern_version="版本未知"
        fi
        # Phase 5 计划备份尚未实现，不能将 protective 备份误显示为自动备份已开启。
        ui_main_menu "$sillytavern_version" "$stermux_version" "已关闭"
    else
        SILLYTAVERN_IS_INSTALLED=false
        ui_uninstalled_menu "$stermux_version"
    fi
}

main_loop() {
    local choice

    while true; do
        show_main_menu
        if [[ "$SILLYTAVERN_IS_INSTALLED" == true ]]; then
            ui_menu_prompt '0-6'
        else
            ui_menu_prompt '0-4'
        fi

        if ! IFS= read -r choice; then
            printf '\n'
            ui_info "输入已结束，退出 STermux。"
            return 0
        fi

        if [[ "$SILLYTAVERN_IS_INSTALLED" == true ]]; then
            case "$choice" in
                1)
                    launch_sillytavern || true
                    ui_pause
                    ;;
                2)
                    open_sillytavern_update_center || true
                    ;;
                3)
                    open_sillytavern_extensions || true
                    ;;
                4)
                    open_backup_center || true
                    ;;
                5)
                    open_stermux_update_center || true
                    ;;
                6)
                    settings_menu
                    ;;
                0)
                    ui_info "已退出 STermux。"
                    return 0
                    ;;
                *)
                    ui_warning "无效选项，请输入 0、1、2、3、4、5 或 6。"
                    ui_pause
                    ;;
            esac
        else
            case "$choice" in
                1)
                    if ! sillytavern_install_interactive; then
                        ui_pause
                    fi
                    ;;
                2)
                    prompt_for_sillytavern_path || true
                    ui_pause
                    ;;
                3)
                    open_stermux_update_center || true
                    ;;
                4)
                    settings_menu
                    ;;
                0)
                    ui_info "已退出 STermux。"
                    return 0
                    ;;
                *)
                    ui_warning "无效选项，请输入 0、1、2、3 或 4。"
                    ui_pause
                    ;;
            esac
        fi
    done
}

main() {
    ui_initialize

    if ! config_load; then
        ui_error "配置加载失败，STermux 无法继续启动。"
        return 1
    fi
    ui_initialize

    detect_sillytavern_path || true
    main_loop
}

main "$@"
