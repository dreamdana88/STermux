#!/usr/bin/env bash

ST_UPDATE_STATUS="not_checked"
ST_UPDATE_BRANCH="unknown"
ST_UPDATE_COMMIT="unknown"
ST_UPDATE_UPSTREAM="unknown"
ST_UPDATE_AHEAD=0
ST_UPDATE_BEHIND=0
ST_UPDATE_ERROR=""

sillytavern_update_history_file() {
    printf '%s\n' "$STERMUX_ROOT/data/state/update-history.log"
}

sillytavern_update_reset_status() {
    ST_UPDATE_STATUS="not_checked"
    ST_UPDATE_BRANCH="unknown"
    ST_UPDATE_COMMIT="unknown"
    ST_UPDATE_UPSTREAM="unknown"
    ST_UPDATE_AHEAD=0
    ST_UPDATE_BEHIND=0
    ST_UPDATE_ERROR=""
}

sillytavern_update_load_local_status() {
    sillytavern_update_reset_status

    if ! git_command_is_available; then
        ST_UPDATE_STATUS="git_missing"
        ST_UPDATE_ERROR="未找到 git 命令"
        return 1
    fi

    if ! git_repository_is_valid "$ST_PATH"; then
        ST_UPDATE_STATUS="not_git"
        ST_UPDATE_ERROR="当前 SillyTavern 安装不是有效的 Git 工作区"
        return 1
    fi

    ST_UPDATE_COMMIT="$(git_current_commit "$ST_PATH")" || ST_UPDATE_COMMIT="unknown"
    ST_UPDATE_BRANCH="$(git_current_branch "$ST_PATH")" || {
        ST_UPDATE_STATUS="detached"
        ST_UPDATE_ERROR="当前处于 detached HEAD，无法自动更新"
        return 1
    }

    ST_UPDATE_UPSTREAM="$(git_current_upstream "$ST_PATH")" || {
        ST_UPDATE_STATUS="no_upstream"
        ST_UPDATE_ERROR="当前分支没有 upstream"
        return 1
    }

    ST_UPDATE_STATUS="not_checked"
    return 0
}

sillytavern_update_refresh() {
    sillytavern_update_load_local_status || return 1

    if ! git_fetch_upstream "$ST_PATH"; then
        ST_UPDATE_STATUS="fetch_failed"
        ST_UPDATE_ERROR="$GIT_LAST_ERROR"
        return 1
    fi

    if ! git_compare_upstream "$ST_PATH"; then
        ST_UPDATE_STATUS="compare_failed"
        ST_UPDATE_ERROR="$GIT_LAST_ERROR"
        return 1
    fi

    ST_UPDATE_UPSTREAM="$GIT_UPSTREAM"
    ST_UPDATE_AHEAD="$GIT_AHEAD_COUNT"
    ST_UPDATE_BEHIND="$GIT_BEHIND_COUNT"

    if (( ST_UPDATE_AHEAD == 0 && ST_UPDATE_BEHIND == 0 )); then
        ST_UPDATE_STATUS="latest"
    elif (( ST_UPDATE_AHEAD == 0 && ST_UPDATE_BEHIND > 0 )); then
        ST_UPDATE_STATUS="update_available"
    elif (( ST_UPDATE_AHEAD > 0 && ST_UPDATE_BEHIND == 0 )); then
        ST_UPDATE_STATUS="local_ahead"
    else
        ST_UPDATE_STATUS="diverged"
    fi

    return 0
}

sillytavern_update_status_text() {
    case "$ST_UPDATE_STATUS" in
        not_checked) printf '%s\n' "尚未检查" ;;
        latest) printf '%s\n' "已是最新" ;;
        update_available) printf '可更新（落后 %s 个 Commit）\n' "$ST_UPDATE_BEHIND" ;;
        local_ahead) printf '本地领先 %s 个 Commit\n' "$ST_UPDATE_AHEAD" ;;
        diverged) printf '本地与远程已分叉（领先 %s，落后 %s）\n' "$ST_UPDATE_AHEAD" "$ST_UPDATE_BEHIND" ;;
        fetch_failed) printf '%s\n' "远程检查失败" ;;
        no_upstream) printf '%s\n' "没有 upstream" ;;
        detached) printf '%s\n' "detached HEAD" ;;
        not_git) printf '%s\n' "不是 Git 安装" ;;
        git_missing) printf '%s\n' "未安装 Git" ;;
        compare_failed) printf '%s\n' "版本比较失败" ;;
        *) printf '%s\n' "未知状态" ;;
    esac
}

sillytavern_update_history_append() {
    local before_commit="$1"
    local after_commit="$2"
    local branch="$3"
    local result="$4"
    local error_summary="${5:-}"
    local history_file
    local history_dir
    local timestamp

    history_file="$(sillytavern_update_history_file)"
    history_dir="$(dirname -- "$history_file")"
    timestamp="$(date '+%Y-%m-%d %H:%M:%S %z')"
    error_summary="$(git_message_one_line "$error_summary")"

    mkdir -p -- "$history_dir" || return 1
    if [[ ! -f "$history_file" ]]; then
        printf 'time\tbefore\tafter\tbranch\tresult\terror\n' > "$history_file" || return 1
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$timestamp" "$before_commit" "$after_commit" "$branch" "$result" "$error_summary" \
        >> "$history_file"
}

sillytavern_update_execute() {
    local before_commit
    local after_commit

    if [[ "$ST_UPDATE_STATUS" != "update_available" ]]; then
        ST_UPDATE_ERROR="当前状态不允许自动更新：$ST_UPDATE_STATUS"
        return 1
    fi

    before_commit="$(git_current_commit "$ST_PATH")" || before_commit="unknown"

    if git_has_unmerged_files "$ST_PATH"; then
        ST_UPDATE_ERROR="工作区存在未解决的合并冲突"
        sillytavern_update_history_append "$before_commit" "$before_commit" "$ST_UPDATE_BRANCH" "failed" "$ST_UPDATE_ERROR" || true
        return 1
    fi

    if ! git_pull_rebase_autostash "$ST_PATH"; then
        ST_UPDATE_ERROR="$GIT_LAST_ERROR"
        after_commit="$(git_current_commit "$ST_PATH")" || after_commit="$before_commit"
        sillytavern_update_history_append "$before_commit" "$after_commit" "$ST_UPDATE_BRANCH" "failed" "$ST_UPDATE_ERROR" || true
        return 1
    fi

    after_commit="$(git_current_commit "$ST_PATH")" || after_commit="unknown"
    ST_UPDATE_COMMIT="$after_commit"
    ST_UPDATE_AHEAD=0
    ST_UPDATE_BEHIND=0
    ST_UPDATE_STATUS="latest"
    if ! sillytavern_update_history_append "$before_commit" "$after_commit" "$ST_UPDATE_BRANCH" "success" ""; then
        ST_UPDATE_ERROR="更新成功，但写入更新历史失败"
        return 2
    fi

    ST_UPDATE_ERROR=""
    return 0
}

sillytavern_update_show_status() {
    local short_commit="$ST_UPDATE_COMMIT"
    local status_text

    if [[ "$short_commit" != "unknown" ]]; then
        short_commit="${short_commit:0:12}"
    fi
    status_text="$(sillytavern_update_status_text)"

    printf '\nSillyTavern 更新状态\n\n'
    printf '当前分支：%s\n' "$ST_UPDATE_BRANCH"
    printf '当前 Commit：%s\n' "$short_commit"
    printf 'Upstream：%s\n' "$ST_UPDATE_UPSTREAM"
    printf '远程状态：%s\n' "$status_text"
    if [[ -n "$ST_UPDATE_ERROR" ]]; then
        printf '错误摘要：%s\n' "$ST_UPDATE_ERROR"
    fi
}

sillytavern_update_show_history() {
    local history_file
    local time
    local before
    local after
    local branch
    local result
    local error
    local count=0

    history_file="$(sillytavern_update_history_file)"
    printf '\n最近更新历史\n\n'

    if [[ ! -s "$history_file" ]]; then
        ui_info "暂无更新历史。"
        return 0
    fi

    while IFS=$'\t' read -r time before after branch result error; do
        [[ "$time" == "time" ]] && continue
        count=$((count + 1))
        printf '%d. %s | %s | %s -> %s | %s\n' \
            "$count" "$time" "$branch" "${before:0:12}" "${after:0:12}" "$result"
        if [[ -n "$error" ]]; then
            printf '   错误：%s\n' "$error"
        fi
    done < <(tail -n 20 "$history_file")

    if (( count == 0 )); then
        ui_info "暂无更新历史。"
    fi
}

sillytavern_update_confirm_and_execute() {
    local confirm
    local update_status

    ui_info "正在重新检查 SillyTavern 更新..."
    sillytavern_update_refresh || {
        ui_error "无法检查更新：$ST_UPDATE_ERROR"
        return 1
    }

    case "$ST_UPDATE_STATUS" in
        latest)
            ui_success "SillyTavern 已是最新版本。"
            return 0
            ;;
        update_available)
            ;;
        local_ahead|diverged)
            ui_warning "当前分支包含本地 Commit，Phase 2 不会自动改写或合并这些提交。"
            return 1
            ;;
        *)
            ui_error "当前状态不允许更新：$(sillytavern_update_status_text)"
            return 1
            ;;
    esac

    sillytavern_update_show_status
    if git_worktree_has_changes "$ST_PATH"; then
        ui_warning "检测到未提交的本地文件变化；官方 --autostash 会尝试临时保存并恢复这些变化。"
    fi
    ui_warning "Phase 4 尚未实现，更新前不会自动创建 protective 数据备份。"
    printf '确认执行官方更新命令 git pull --rebase --autostash？[y/N] '
    IFS= read -r confirm || return 1
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        ui_info "已取消更新。"
        return 0
    fi

    ui_info "正在更新 SillyTavern..."
    sillytavern_update_execute
    update_status=$?
    case "$update_status" in
        0)
            ui_success "SillyTavern 更新成功，当前 Commit：${ST_UPDATE_COMMIT:0:12}"
            ui_info "依赖将在下次启动时由 SillyTavern 官方 start.sh 同步。"
            ;;
        2)
            ui_warning "$ST_UPDATE_ERROR"
            ;;
        *)
            ui_error "SillyTavern 更新失败：$ST_UPDATE_ERROR"
            return "$update_status"
            ;;
    esac
}

sillytavern_update_menu() {
    local choice

    sillytavern_update_load_local_status || true
    while true; do
        ui_clear
        sillytavern_update_show_status
        printf '\n1. 检查更新\n'
        printf '2. 执行更新\n'
        printf '3. 查看更新历史\n'
        printf '0. 返回主菜单\n\n'
        printf '请选择操作：'

        if ! IFS= read -r choice; then
            return 0
        fi

        case "$choice" in
            1)
                ui_info "正在检查远程更新..."
                if sillytavern_update_refresh; then
                    sillytavern_update_show_status
                else
                    ui_error "更新检查失败：$ST_UPDATE_ERROR"
                fi
                ui_pause
                ;;
            2)
                sillytavern_update_confirm_and_execute || true
                ui_pause
                ;;
            3)
                sillytavern_update_show_history
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
