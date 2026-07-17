#!/usr/bin/env bash

STERMUX_UPDATE_STATUS="not_checked"
STERMUX_UPDATE_BRANCH="unknown"
STERMUX_UPDATE_COMMIT="unknown"
STERMUX_UPDATE_UPSTREAM="unknown"
STERMUX_UPDATE_AHEAD=0
STERMUX_UPDATE_BEHIND=0
STERMUX_UPDATE_ERROR=""
STERMUX_UPDATE_BEFORE_COMMIT="unknown"
STERMUX_UPDATE_AFTER_COMMIT="unknown"

stermux_update_log_file() {
    printf '%s\n' "$STERMUX_ROOT/data/logs/stermux-update.log"
}

stermux_update_log() {
    local result="$1"
    local detail="${2:-}"
    local log_file

    log_file="$(stermux_update_log_file)"
    mkdir -p -- "$(dirname -- "$log_file")" 2>/dev/null || return 1
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S %z')" \
        "$result" "$STERMUX_UPDATE_BRANCH" \
        "$STERMUX_UPDATE_BEFORE_COMMIT" "$STERMUX_UPDATE_AFTER_COMMIT" \
        "$(git_message_one_line "$detail")" \
        >> "$log_file"
}

stermux_git_is_usable() {
    local output

    if ! command -v git >/dev/null 2>&1; then
        STERMUX_UPDATE_ERROR="未找到 git 命令"
        return 1
    fi
    output="$(git --version 2>&1)" || {
        STERMUX_UPDATE_ERROR="git 命令存在但无法运行：$(git_message_one_line "$output")"
        return 1
    }
    return 0
}

stermux_update_reset_status() {
    STERMUX_UPDATE_STATUS="not_checked"
    STERMUX_UPDATE_BRANCH="unknown"
    STERMUX_UPDATE_COMMIT="unknown"
    STERMUX_UPDATE_UPSTREAM="unknown"
    STERMUX_UPDATE_AHEAD=0
    STERMUX_UPDATE_BEHIND=0
    STERMUX_UPDATE_ERROR=""
}

stermux_update_load_local_status() {
    stermux_update_reset_status

    if ! stermux_git_is_usable; then
        STERMUX_UPDATE_STATUS="git_unusable"
        return 1
    fi
    if ! git_repository_is_valid "$STERMUX_ROOT"; then
        STERMUX_UPDATE_STATUS="not_git"
        STERMUX_UPDATE_ERROR="当前 STermux 目录不是有效 Git 仓库"
        return 1
    fi

    STERMUX_UPDATE_COMMIT="$(git_current_commit "$STERMUX_ROOT")" || STERMUX_UPDATE_COMMIT="unknown"
    STERMUX_UPDATE_BRANCH="$(git_current_branch "$STERMUX_ROOT")" || {
        STERMUX_UPDATE_STATUS="detached"
        STERMUX_UPDATE_ERROR="当前 STermux 仓库处于 detached HEAD"
        return 1
    }
    STERMUX_UPDATE_UPSTREAM="$(git_current_upstream "$STERMUX_ROOT")" || {
        STERMUX_UPDATE_STATUS="no_upstream"
        STERMUX_UPDATE_ERROR="当前 STermux 分支没有 upstream"
        return 1
    }
    return 0
}

stermux_update_refresh() {
    stermux_update_load_local_status || return 1

    if ! git_fetch_upstream "$STERMUX_ROOT"; then
        STERMUX_UPDATE_STATUS="fetch_failed"
        STERMUX_UPDATE_ERROR="$GIT_LAST_ERROR"
        return 1
    fi
    if ! git_compare_upstream "$STERMUX_ROOT"; then
        STERMUX_UPDATE_STATUS="compare_failed"
        STERMUX_UPDATE_ERROR="$GIT_LAST_ERROR"
        return 1
    fi

    STERMUX_UPDATE_UPSTREAM="$GIT_UPSTREAM"
    STERMUX_UPDATE_AHEAD="$GIT_AHEAD_COUNT"
    STERMUX_UPDATE_BEHIND="$GIT_BEHIND_COUNT"
    if (( STERMUX_UPDATE_AHEAD == 0 && STERMUX_UPDATE_BEHIND == 0 )); then
        STERMUX_UPDATE_STATUS="latest"
    elif (( STERMUX_UPDATE_AHEAD == 0 && STERMUX_UPDATE_BEHIND > 0 )); then
        STERMUX_UPDATE_STATUS="update_available"
    elif (( STERMUX_UPDATE_AHEAD > 0 && STERMUX_UPDATE_BEHIND == 0 )); then
        STERMUX_UPDATE_STATUS="local_ahead"
    else
        STERMUX_UPDATE_STATUS="diverged"
    fi
    return 0
}

stermux_update_user_status_text() {
    case "$STERMUX_UPDATE_STATUS" in
        not_checked) printf '%s\n' "尚未检查" ;;
        latest) printf '%s\n' "已是最新" ;;
        update_available) printf '%s\n' "发现新版本" ;;
        local_ahead|diverged) printf '%s\n' "本地状态特殊，无法自动更新" ;;
        fetch_failed|compare_failed) printf '%s\n' "检查失败" ;;
        no_upstream|detached|not_git|git_unusable) printf '%s\n' "当前安装无法自动更新" ;;
        local_changes) printf '%s\n' "检测到本地程序修改" ;;
        pull_failed) printf '%s\n' "更新失败" ;;
        restart_failed) printf '%s\n' "更新成功，重新启动失败" ;;
        *) printf '%s\n' "未知状态" ;;
    esac
}

stermux_update_status_role() {
    case "$STERMUX_UPDATE_STATUS" in
        latest) printf '%s\n' "success" ;;
        update_available) printf '%s\n' "warning" ;;
        fetch_failed|compare_failed|git_unusable|not_git|pull_failed|restart_failed) printf '%s\n' "error" ;;
        local_changes|local_ahead|diverged|no_upstream|detached) printf '%s\n' "warning" ;;
        *) printf '%s\n' "default" ;;
    esac
}

stermux_update_show_status() {
    ui_page_header 'STermux 更新'
    printf '\n'
    printf '当前版本 : %s\n' "$(stermux_version_display)"
    printf '更新状态 : '
    ui_colorize "$(stermux_update_status_role)" "$(stermux_update_user_status_text)"
    printf '\n'
}

stermux_update_show_technical_details() {
    printf '\n'
    ui_page_header 'STermux 更新技术详情'
    printf '\n'
    printf '当前分支：%s\n' "$STERMUX_UPDATE_BRANCH"
    printf '当前 Commit：%s\n' "$STERMUX_UPDATE_COMMIT"
    printf 'Upstream：%s\n' "$STERMUX_UPDATE_UPSTREAM"
    printf 'ahead / behind：领先 %s 个 Commit，落后 %s 个 Commit\n' \
        "$STERMUX_UPDATE_AHEAD" "$STERMUX_UPDATE_BEHIND"
    if [[ -n "$STERMUX_UPDATE_ERROR" ]]; then
        printf '错误摘要：%s\n' "$STERMUX_UPDATE_ERROR"
    fi
}

stermux_update_program_files_have_changes() {
    local changes

    changes="$(git -C "$STERMUX_ROOT" status --porcelain --untracked-files=no -- \
        . \
        ':(exclude)config/user.conf' \
        ':(exclude)config/extension-policy.conf' \
        ':(exclude)data/**' \
        ':(exclude)logs/**' \
        2>/dev/null)" || return 2
    [[ -n "$changes" ]]
}

stermux_update_execute() {
    local change_status

    if [[ "$STERMUX_UPDATE_STATUS" != "update_available" ]]; then
        STERMUX_UPDATE_ERROR="当前状态不允许自动更新：$STERMUX_UPDATE_STATUS"
        return 1
    fi

    stermux_update_program_files_have_changes
    change_status=$?
    if (( change_status == 0 )); then
        STERMUX_UPDATE_STATUS="local_changes"
        STERMUX_UPDATE_ERROR="检测到 tracked 程序文件存在本地修改，已拒绝自动更新"
        stermux_update_log "blocked" "$STERMUX_UPDATE_ERROR" || true
        return 1
    elif (( change_status == 2 )); then
        STERMUX_UPDATE_ERROR="无法检查 STermux 本地程序文件状态"
        return 1
    fi

    STERMUX_UPDATE_BEFORE_COMMIT="$(git_current_commit "$STERMUX_ROOT")" \
        || STERMUX_UPDATE_BEFORE_COMMIT="unknown"
    STERMUX_UPDATE_AFTER_COMMIT="$STERMUX_UPDATE_BEFORE_COMMIT"
    if ! git_pull_ff_only "$STERMUX_ROOT"; then
        STERMUX_UPDATE_STATUS="pull_failed"
        STERMUX_UPDATE_ERROR="$GIT_LAST_ERROR"
        STERMUX_UPDATE_AFTER_COMMIT="$(git_current_commit "$STERMUX_ROOT")" \
            || STERMUX_UPDATE_AFTER_COMMIT="$STERMUX_UPDATE_BEFORE_COMMIT"
        stermux_update_log "failed" "$STERMUX_UPDATE_ERROR" || true
        return 1
    fi

    STERMUX_UPDATE_AFTER_COMMIT="$(git_current_commit "$STERMUX_ROOT")" \
        || STERMUX_UPDATE_AFTER_COMMIT="unknown"
    STERMUX_UPDATE_COMMIT="$STERMUX_UPDATE_AFTER_COMMIT"
    STERMUX_UPDATE_AHEAD=0
    STERMUX_UPDATE_BEHIND=0
    STERMUX_UPDATE_STATUS="latest"
    STERMUX_UPDATE_ERROR=""
    stermux_update_log "success" "fast-forward update" || true
    return 0
}

stermux_update_restart_program() {
    [[ -r "$STERMUX_ROOT/manager.sh" ]] || return 1
    exec bash "$STERMUX_ROOT/manager.sh"
}

stermux_update_apply_and_restart() {
    if ! stermux_update_execute; then
        return 1
    fi

    ui_success "STermux 更新成功，正在重新启动..."
    if ! stermux_update_restart_program; then
        STERMUX_UPDATE_STATUS="restart_failed"
        STERMUX_UPDATE_ERROR="更新已经成功，但无法重新启动 manager.sh；请手动重新运行 STermux"
        stermux_update_log "restart_failed" "$STERMUX_UPDATE_ERROR" || true
        ui_error "$STERMUX_UPDATE_ERROR"
        return 2
    fi
    return 0
}

stermux_update_confirm_and_execute() {
    local confirm
    local change_status

    ui_info "正在重新检查 STermux 更新..."
    if ! stermux_update_refresh; then
        ui_error "无法检查 STermux 更新：$STERMUX_UPDATE_ERROR"
        return 1
    fi
    case "$STERMUX_UPDATE_STATUS" in
        latest)
            ui_success "STermux 已是最新。"
            return 0
            ;;
        update_available)
            ;;
        *)
            ui_error "当前状态不允许自动更新：$(stermux_update_user_status_text)"
            return 1
            ;;
    esac

    stermux_update_program_files_have_changes
    change_status=$?
    case "$change_status" in
        0)
            STERMUX_UPDATE_STATUS="local_changes"
            STERMUX_UPDATE_ERROR="检测到 tracked 程序文件存在本地修改，已拒绝自动更新"
            ui_error "$STERMUX_UPDATE_ERROR"
            return 1
            ;;
        1)
            ;;
        *)
            STERMUX_UPDATE_ERROR="无法检查 STermux 本地程序文件状态"
            ui_error "$STERMUX_UPDATE_ERROR"
            return 1
            ;;
    esac

    printf '确认使用 git pull --ff-only 更新 STermux？[y/N] '
    IFS= read -r confirm || return 1
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        ui_info "已取消 STermux 更新。"
        return 0
    fi
    stermux_update_apply_and_restart
}

stermux_update_menu() {
    local choice

    stermux_update_load_local_status || true
    while true; do
        ui_clear
        stermux_update_show_status
        printf '\n1. 检查更新\n'
        printf '2. 更新 STermux\n'
        printf '3. 查看技术详情\n'
        printf '0. 返回主菜单\n\n'
        ui_menu_prompt '0-3'
        IFS= read -r choice || return 0

        case "$choice" in
            1)
                ui_info "正在检查 STermux 更新..."
                if stermux_update_refresh; then
                    stermux_update_show_status
                else
                    ui_error "检查失败：$STERMUX_UPDATE_ERROR"
                fi
                ui_pause
                ;;
            2)
                stermux_update_confirm_and_execute || true
                ui_pause
                ;;
            3)
                stermux_update_show_technical_details
                ui_pause
                ;;
            0)
                return 0
                ;;
            *)
                ui_warning "无效选项，请输入 0、1、2 或 3。"
                ui_pause
                ;;
        esac
    done
}
