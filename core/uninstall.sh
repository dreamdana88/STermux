#!/usr/bin/env bash

UNINSTALL_LAST_ERROR=""
UNINSTALL_BACKUP_COUNT=0
UNINSTALL_BACKUP_SIZE=0
UNINSTALL_RESULT_FAILED=0
UNINSTALL_AUTOSTART_RESULT="unknown"

declare -a UNINSTALL_SELECTED_ACTIONS=()
declare -a UNINSTALL_RESULT_LABELS=()
declare -a UNINSTALL_RESULT_STATES=()
declare -a UNINSTALL_RESULT_DETAILS=()

uninstall_one_line() {
    local value="${1:-}"
    value="${value//$'\r'/ }"
    value="${value//$'\n'/ }"
    value="${value//$'\t'/ }"
    printf '%s\n' "$value"
}

uninstall_log_file() {
    printf '%s\n' "$STERMUX_ROOT/data/logs/uninstall.log"
}

uninstall_log() {
    local action="$1" result="$2" detail="${3:-}" log_file

    log_file="$(uninstall_log_file)"
    mkdir -p -- "$(dirname -- "$log_file")" 2>/dev/null || return 1
    printf '%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" \
        "$(uninstall_one_line "$action")" "$(uninstall_one_line "$result")" \
        "$(uninstall_one_line "$detail")" >> "$log_file"
}

uninstall_canonical_if_directory() {
    local path="${1:-}"
    [[ -n "$path" && -d "$path" ]] || return 1
    path_canonicalize_directory "$path"
}

uninstall_path_is_forbidden() {
    local candidate="$1" comparison canonical

    [[ -n "$candidate" && "$candidate" != "/" ]] || return 0
    for comparison in "${HOME:-}" "${PREFIX:-}"; do
        [[ -n "$comparison" && -d "$comparison" ]] || continue
        canonical="$(uninstall_canonical_if_directory "$comparison")" || continue
        [[ "$candidate" != "$canonical" ]] || return 0
    done
    return 1
}

stermux_uninstall_root_is_valid() {
    local root="${1:-}" canonical expected st_canonical

    [[ -n "$root" && -d "$root" && ! -L "$root" ]] || {
        UNINSTALL_LAST_ERROR="STermux 根目录不存在、为空或为符号链接"
        return 1
    }
    canonical="$(uninstall_canonical_if_directory "$root")" || return 1
    expected="$(uninstall_canonical_if_directory "$STERMUX_ROOT")" || return 1
    [[ "$canonical" == "$expected" ]] || {
        UNINSTALL_LAST_ERROR="卸载目标不是当前 STermux 根目录"
        return 1
    }
    uninstall_path_is_forbidden "$canonical" && {
        UNINSTALL_LAST_ERROR="STermux 根目录指向 HOME、PREFIX 或根目录，已拒绝删除"
        return 1
    }
    [[ -f "$canonical/manager.sh" && -f "$canonical/core/ui.sh" \
        && -f "$canonical/VERSION" ]] || {
        UNINSTALL_LAST_ERROR="目标缺少 STermux 结构标记"
        return 1
    }
    if sillytavern_path_is_valid "${ST_PATH:-}"; then
        st_canonical="$(uninstall_canonical_if_directory "$ST_PATH")" || return 1
        if [[ "$st_canonical" == "$canonical" || "$st_canonical" == "$canonical/"* ]]; then
            UNINSTALL_LAST_ERROR="SillyTavern 位于 STermux 目录内，无法保证保留其数据"
            return 1
        fi
    fi
    return 0
}

sillytavern_uninstall_path_is_valid() {
    local target="${1:-}" canonical root_canonical comparison comparison_canonical

    [[ -n "$target" && -d "$target" && ! -L "$target" ]] || {
        UNINSTALL_LAST_ERROR="SillyTavern 路径不存在、为空或为符号链接"
        return 1
    }
    sillytavern_path_is_valid "$target" || {
        UNINSTALL_LAST_ERROR="目标不是有效的 SillyTavern 安装"
        return 1
    }
    canonical="$(uninstall_canonical_if_directory "$target")" || return 1
    uninstall_path_is_forbidden "$canonical" && {
        UNINSTALL_LAST_ERROR="SillyTavern 路径指向 HOME、PREFIX 或根目录，已拒绝删除"
        return 1
    }
    root_canonical="$(uninstall_canonical_if_directory "$STERMUX_ROOT")" || return 1
    [[ "$canonical" != "$root_canonical" && "$root_canonical" != "$canonical/"* ]] || {
        UNINSTALL_LAST_ERROR="SillyTavern 路径与 STermux 根目录冲突"
        return 1
    }
    for comparison in "${HOME:-}" "${PREFIX:-}"; do
        [[ -n "$comparison" && -d "$comparison" ]] || continue
        comparison_canonical="$(uninstall_canonical_if_directory "$comparison")" || continue
        [[ "$canonical" != "$comparison_canonical" ]] || {
            UNINSTALL_LAST_ERROR="SillyTavern 路径是受保护目录"
            return 1
        }
    done
    return 0
}

uninstall_remove_directory() {
    rm -rf -- "$1"
}

uninstall_sillytavern_execute() {
    local target canonical

    target="${ST_PATH:-}"
    sillytavern_uninstall_path_is_valid "$target" || return 1
    canonical="$(uninstall_canonical_if_directory "$target")" || return 1
    if ! uninstall_remove_directory "$canonical" || [[ -e "$canonical" ]]; then
        UNINSTALL_LAST_ERROR="SillyTavern 目录删除失败"
        uninstall_log sillytavern failed "$UNINSTALL_LAST_ERROR" || true
        return 1
    fi
    ST_PATH=""
    if ! config_remove_value ST_PATH; then
        UNINSTALL_LAST_ERROR="SillyTavern 已删除，但无法清除保存的 ST_PATH"
        uninstall_log sillytavern warning "$UNINSTALL_LAST_ERROR" || true
        return 1
    fi
    uninstall_log sillytavern success "$canonical" || true
    return 0
}

uninstall_backup_summary() {
    local index

    UNINSTALL_BACKUP_COUNT=0
    UNINSTALL_BACKUP_SIZE=0
    backup_inventory_scan || return 1
    UNINSTALL_BACKUP_COUNT="${#BACKUP_IDS[@]}"
    for ((index = 0; index < ${#BACKUP_SIZES[@]}; index++)); do
        [[ "${BACKUP_SIZES[index]}" =~ ^[0-9]+$ ]] || continue
        UNINSTALL_BACKUP_SIZE=$((UNINSTALL_BACKUP_SIZE + BACKUP_SIZES[index]))
    done
}

uninstall_delete_all_backups() {
    local index failed=0

    uninstall_backup_summary || return 1
    for ((index = 0; index < ${#BACKUP_PATHS[@]}; index++)); do
        if ! backup_delete_path "${BACKUP_PATHS[index]}" manual; then
            failed=$((failed + 1))
        fi
    done
    if (( failed > 0 )); then
        UNINSTALL_LAST_ERROR="有 $failed 个备份删除失败"
        uninstall_log backups failed "$UNINSTALL_LAST_ERROR" || true
        return 1
    fi
    uninstall_log backups success "count=$UNINSTALL_BACKUP_COUNT;size=$UNINSTALL_BACKUP_SIZE" || true
}

uninstall_autostart_execute() {
    UNINSTALL_AUTOSTART_RESULT="unknown"
    AUTOSTART_LAST_ERROR=""
    autostart_status >/dev/null 2>&1 || true
    if [[ "$AUTOSTART_STATUS" == disabled ]]; then
        UNINSTALL_AUTOSTART_RESULT="not_enabled"
        uninstall_log autostart skipped "not-enabled" || true
        return 0
    fi
    if ! autostart_disable; then
        UNINSTALL_LAST_ERROR="${AUTOSTART_LAST_ERROR:-自动进入配置删除失败}"
        uninstall_log autostart failed "$UNINSTALL_LAST_ERROR" || true
        return 1
    fi
    UNINSTALL_AUTOSTART_RESULT="removed"
    uninstall_log autostart success "managed-block-removed" || true
}

uninstall_parse_selection() {
    local input="$1" normalized token existing duplicate

    UNINSTALL_SELECTED_ACTIONS=()
    normalized="${input//,/ }"
    for token in $normalized; do
        [[ "$token" =~ ^[1-4]$ ]] || continue
        duplicate=false
        for existing in "${UNINSTALL_SELECTED_ACTIONS[@]}"; do
            [[ "$existing" == "$token" ]] && { duplicate=true; break; }
        done
        [[ "$duplicate" == true ]] || UNINSTALL_SELECTED_ACTIONS+=("$token")
    done
    (( ${#UNINSTALL_SELECTED_ACTIONS[@]} > 0 ))
}

uninstall_selection_has() {
    local wanted="$1" action
    for action in "${UNINSTALL_SELECTED_ACTIONS[@]}"; do
        [[ "$action" == "$wanted" ]] && return 0
    done
    return 1
}

uninstall_selection_add() {
    uninstall_selection_has "$1" || UNINSTALL_SELECTED_ACTIONS+=("$1")
}

uninstall_selection_remove() {
    local unwanted="$1" action
    local -a remaining=()
    for action in "${UNINSTALL_SELECTED_ACTIONS[@]}"; do
        [[ "$action" == "$unwanted" ]] || remaining+=("$action")
    done
    UNINSTALL_SELECTED_ACTIONS=("${remaining[@]}")
}

uninstall_result_add() {
    local label="$1" state="$2" detail="${3:-}"
    UNINSTALL_RESULT_LABELS+=("$label")
    UNINSTALL_RESULT_STATES+=("$state")
    UNINSTALL_RESULT_DETAILS+=("$detail")
    [[ "$state" != failed ]] || UNINSTALL_RESULT_FAILED=$((UNINSTALL_RESULT_FAILED + 1))
}

uninstall_results_show() {
    local index
    printf '\n卸载结果：\n\n'
    for ((index = 0; index < ${#UNINSTALL_RESULT_LABELS[@]}; index++)); do
        if [[ "${UNINSTALL_RESULT_STATES[index]}" == success ]]; then
            ui_success "${UNINSTALL_RESULT_LABELS[index]}${UNINSTALL_RESULT_DETAILS[index]:+：${UNINSTALL_RESULT_DETAILS[index]}}"
        else
            ui_error "${UNINSTALL_RESULT_LABELS[index]}：${UNINSTALL_RESULT_DETAILS[index]}"
        fi
    done
}

uninstall_temp_directory() {
    if [[ -n "${STERMUX_UNINSTALL_TMPDIR:-}" ]]; then
        printf '%s\n' "$STERMUX_UNINSTALL_TMPDIR"
    elif [[ -n "${PREFIX:-}" && -d "$PREFIX/tmp" ]]; then
        printf '%s\n' "$PREFIX/tmp"
    else
        printf '%s\n' "${TMPDIR:-/tmp}"
    fi
}

uninstall_self_script_create() {
    local temporary_directory temporary_script root_canonical temp_canonical

    UNINSTALL_LAST_ERROR=""
    stermux_uninstall_root_is_valid "$STERMUX_ROOT" || return 1
    temporary_directory="$(uninstall_temp_directory)"
    [[ -d "$temporary_directory" && ! -L "$temporary_directory" ]] || {
        UNINSTALL_LAST_ERROR="无法使用卸载临时目录：$temporary_directory"
        return 1
    }
    root_canonical="$(uninstall_canonical_if_directory "$STERMUX_ROOT")" || return 1
    temp_canonical="$(uninstall_canonical_if_directory "$temporary_directory")" || return 1
    [[ "$temp_canonical" != "$root_canonical" && "$temp_canonical" != "$root_canonical/"* ]] || {
        UNINSTALL_LAST_ERROR="卸载临时目录不能位于 STermux 项目内"
        return 1
    }
    temporary_script="$(mktemp "$temporary_directory/stermux-uninstall.XXXXXX.sh")" || {
        UNINSTALL_LAST_ERROR="无法创建临时卸载脚本"
        return 1
    }
    {
        printf '%s\n' '#!/usr/bin/env bash'
        printf '%s\n' 'set -u'
        printf '%s\n' 'target="${1:-}"; protected_home="${2:-}"; protected_prefix="${3:-}"; protected_st="${4:-}"; st_kept="${5:-true}"'
        printf '%s\n' 'script_path="${BASH_SOURCE[0]}"'
        printf '%s\n' 'cleanup() { rm -f -- "$script_path" 2>/dev/null || true; }'
        printf '%s\n' 'trap cleanup EXIT'
        printf '%s\n' 'canonical_dir() { [[ -d "$1" ]] && (CDPATH= cd -- "$1" 2>/dev/null && pwd -P); }'
        printf '%s\n' 'target_canonical="$(canonical_dir "$target")" || { printf "[错误] STermux 卸载目标无法解析。\\n" >&2; exit 1; }'
        printf '%s\n' 'for protected in / "$protected_home" "$protected_prefix" "$protected_st"; do'
        printf '%s\n' '  [[ -n "$protected" ]] || continue'
        printf '%s\n' '  if [[ -d "$protected" ]]; then protected="$(canonical_dir "$protected")" || exit 1; fi'
        printf '%s\n' '  [[ "$target_canonical" != "$protected" ]] || { printf "[错误] STermux 卸载目标是受保护目录。\\n" >&2; exit 1; }'
        printf '%s\n' 'done'
        printf '%s\n' '[[ ! -L "$target" && -f "$target_canonical/manager.sh" && -f "$target_canonical/core/ui.sh" && -f "$target_canonical/VERSION" ]] || { printf "[错误] STermux 结构验证失败。\\n" >&2; exit 1; }'
        printf '%s\n' 'cd -- "$(dirname -- "$script_path")" || exit 1'
        printf '%s\n' 'rm -rf -- "$target_canonical" || { printf "[错误] STermux 目录删除失败。\\n" >&2; exit 1; }'
        printf '%s\n' '[[ ! -e "$target_canonical" ]] || { printf "[错误] STermux 目录仍然存在。\\n" >&2; exit 1; }'
        printf '%s\n' 'printf "============================================\\n\\n"'
        printf '%s\n' 'if [[ "$st_kept" == true ]]; then printf "              STermux 已成功卸载\\n"; else printf "              卸载操作已完成\\n"; fi'
        printf '%s\n' 'printf "\\n        感谢您的使用，期待再次相见 👋\\n\\n============================================\\n\\n"'
        printf '%s\n' 'if [[ "$st_kept" == true ]]; then printf "SillyTavern 及其用户数据已保留。\\n"; fi'
        printf '%s\n' 'printf "Termux 公共依赖未被删除。\\n"'
    } > "$temporary_script" || {
        rm -f -- "$temporary_script" 2>/dev/null || true
        UNINSTALL_LAST_ERROR="无法写入临时卸载脚本"
        return 1
    }
    chmod 700 -- "$temporary_script" || {
        rm -f -- "$temporary_script" 2>/dev/null || true
        UNINSTALL_LAST_ERROR="无法设置临时卸载脚本权限"
        return 1
    }
    printf '%s\n' "$temporary_script"
}

uninstall_exec_handoff() {
    exec bash "$@"
}

uninstall_self_handoff() {
    local temporary_script st_kept=true protected_st=""

    sillytavern_path_is_valid "${ST_PATH:-}" && protected_st="$ST_PATH" || st_kept=false
    temporary_script="$(uninstall_self_script_create)" || return 1
    uninstall_log stermux handoff "$temporary_script" || true
    uninstall_exec_handoff "$temporary_script" "$STERMUX_ROOT" "${HOME:-}" \
        "${PREFIX:-}" "$protected_st" "$st_kept"
}

uninstall_show_menu() {
    ui_page_header '卸载管理'
    printf '\n'
    ui_warning '以下操作可能永久删除数据，请谨慎选择。'
    printf '\n1. 卸载 STermux\n'
    printf '   包含程序、配置、日志及所有备份\n\n'
    printf '2. 卸载 SillyTavern\n'
    printf '   删除当前酒馆及其中的用户数据\n\n'
    printf '3. 删除所有 SillyTavern 备份\n\n'
    printf '4. 删除自动进入配置\n\n'
    printf '0. 返回\n\n'
    ui_separator
    printf '请选择要执行的操作，可多选：'
}

uninstall_show_summary() {
    printf '\n即将执行：\n\n'
    if uninstall_selection_has 2; then
        printf '✓ 卸载 SillyTavern：%s\n' "${ST_PATH:-未设置}"
        printf '  将永久删除酒馆程序、聊天记录、角色卡、世界书、用户配置和第三方扩展。\n'
        printf '  STermux 备份将保留，除非同时删除备份或卸载 STermux。\n'
    fi
    if uninstall_selection_has 3; then
        if uninstall_selection_has 1; then
            printf '✓ 删除所有 SillyTavern 备份（包含在 STermux 卸载中）\n'
        else
            printf '✓ 删除所有 SillyTavern 备份：%s 份，共 %s\n' \
                "$UNINSTALL_BACKUP_COUNT" "$(backup_size_display "$UNINSTALL_BACKUP_SIZE")"
        fi
    fi
    uninstall_selection_has 4 && printf '✓ 删除 STermux 自动进入配置\n'
    if uninstall_selection_has 1; then
        printf '✓ 卸载 STermux：%s\n' "$STERMUX_ROOT"
        printf '  将删除程序、配置、日志、状态文件和项目目录内全部备份。\n'
        printf '  SillyTavern 与 Termux 公共依赖将保留，除非已单独选择卸载 SillyTavern。\n'
    fi
    printf '\n此操作将永久删除相关数据且无法恢复。\n'
}

uninstall_manager_menu() {
    local input confirm action

    ui_clear
    uninstall_show_menu
    IFS= read -r input || return 0
    [[ "$input" != 0 ]] || return 0
    uninstall_parse_selection "$input" || {
        ui_warning '没有有效的操作编号。'
        return 1
    }
    if uninstall_selection_has 1 && ! uninstall_selection_has 4; then
        printf '是否同时移除 STermux 自动进入配置？[Y/n] '
        IFS= read -r confirm || confirm=""
        [[ "$confirm" == n || "$confirm" == N ]] || uninstall_selection_add 4
    fi
    if uninstall_selection_has 3 && ! uninstall_selection_has 1; then
        uninstall_backup_summary || {
            ui_error "无法读取备份清单：$BACKUP_LAST_ERROR"
            return 1
        }
        if (( UNINSTALL_BACKUP_COUNT == 0 )); then
            ui_info '当前没有可删除的备份。'
            if (( ${#UNINSTALL_SELECTED_ACTIONS[@]} == 1 )); then
                return 0
            fi
            uninstall_selection_remove 3
        fi
    fi
    uninstall_show_summary
    printf '最终确认是否执行？[y/N] '
    IFS= read -r confirm || return 0
    if [[ "$confirm" != y && "$confirm" != Y ]]; then
        ui_info '已取消卸载操作。'
        return 0
    fi

    UNINSTALL_RESULT_LABELS=(); UNINSTALL_RESULT_STATES=(); UNINSTALL_RESULT_DETAILS=()
    UNINSTALL_RESULT_FAILED=0
    if uninstall_selection_has 4; then
        if uninstall_autostart_execute; then
            if [[ "$UNINSTALL_AUTOSTART_RESULT" == not_enabled ]]; then
                uninstall_result_add 'STermux 自动进入配置当前未启用' success
            else
                uninstall_result_add '自动进入配置已删除' success
            fi
        else
            uninstall_result_add '自动进入配置删除失败' failed "$UNINSTALL_LAST_ERROR"
        fi
    fi
    if uninstall_selection_has 2; then
        if uninstall_sillytavern_execute; then
            uninstall_result_add 'SillyTavern 已卸载' success
        else
            uninstall_result_add 'SillyTavern 卸载失败' failed "$UNINSTALL_LAST_ERROR"
        fi
    fi
    if uninstall_selection_has 3 && ! uninstall_selection_has 1; then
        if uninstall_delete_all_backups; then
            uninstall_result_add '所有有效 SillyTavern 备份已删除' success
        else
            uninstall_result_add '备份删除失败' failed "$UNINSTALL_LAST_ERROR"
        fi
    fi
    uninstall_results_show
    uninstall_log selection executed "actions=${UNINSTALL_SELECTED_ACTIONS[*]};failed=$UNINSTALL_RESULT_FAILED" || true

    if uninstall_selection_has 1; then
        if (( UNINSTALL_RESULT_FAILED > 0 )); then
            printf '\n前面的操作存在失败，是否仍然继续卸载 STermux？[y/N] '
            IFS= read -r confirm || return 1
            [[ "$confirm" == y || "$confirm" == Y ]] || {
                ui_info '已保留 STermux，便于继续处理失败项。'
                return 1
            }
        fi
        ui_info '正在交接给安全临时卸载脚本...'
        uninstall_self_handoff || {
            ui_error "无法启动 STermux 自删除：$UNINSTALL_LAST_ERROR"
            return 1
        }
    fi
    return 0
}
