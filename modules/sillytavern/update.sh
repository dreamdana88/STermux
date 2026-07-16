#!/usr/bin/env bash

ST_UPDATE_STATUS="not_checked"
ST_UPDATE_BRANCH="unknown"
ST_UPDATE_COMMIT="unknown"
ST_UPDATE_UPSTREAM="unknown"
ST_UPDATE_AHEAD=0
ST_UPDATE_BEHIND=0
ST_UPDATE_ERROR=""
ST_UPDATE_LOCAL_VERSION="unknown"
ST_UPDATE_REMOTE_VERSION="unknown"
ST_UPDATE_LAST_BEFORE_VERSION="unknown"
ST_UPDATE_LAST_AFTER_VERSION="unknown"
ST_UPDATE_LAST_BEFORE_COMMIT="unknown"
ST_UPDATE_LAST_AFTER_COMMIT="unknown"

sillytavern_update_history_file() {
    printf '%s\n' "$STERMUX_ROOT/data/state/update-history.log"
}

sillytavern_version_is_valid() {
    local version="$1"

    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]
}

sillytavern_version_from_json() {
    local json="$1"
    local version=""
    local compact_json

    if command -v node >/dev/null 2>&1; then
        version="$(node -e '
            const fs = require("fs");
            try {
                const value = JSON.parse(fs.readFileSync(0, "utf8")).version;
                if (typeof value !== "string") process.exit(1);
                process.stdout.write(value);
            } catch {
                process.exit(1);
            }
        ' <<< "$json" 2>/dev/null)" || return 1
    else
        compact_json="${json//$'\r'/}"
        compact_json="${compact_json//$'\n'/}"
        if [[ "$compact_json" =~ \"version\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
            version="${BASH_REMATCH[1]}"
        else
            return 1
        fi
    fi

    sillytavern_version_is_valid "$version" || return 1
    printf '%s\n' "$version"
}

sillytavern_read_local_version() {
    local package_file="$ST_PATH/package.json"
    local json
    local version

    if [[ ! -r "$package_file" ]]; then
        printf '%s\n' "unknown"
        return 0
    fi

    json="$(< "$package_file")" || {
        printf '%s\n' "unknown"
        return 0
    }
    version="$(sillytavern_version_from_json "$json")" || version="unknown"
    printf '%s\n' "$version"
}

sillytavern_read_remote_version() {
    local upstream="$1"
    local json
    local version

    if [[ -z "$upstream" || "$upstream" == "unknown" ]]; then
        printf '%s\n' "unknown"
        return 0
    fi

    json="$(git_show_file_at_ref "$ST_PATH" "$upstream" "package.json")" || {
        printf '%s\n' "unknown"
        return 0
    }
    version="$(sillytavern_version_from_json "$json")" || version="unknown"
    printf '%s\n' "$version"
}

sillytavern_version_display() {
    local version="$1"

    if [[ "$version" == "unknown" || -z "$version" ]]; then
        printf '%s\n' "未知"
    else
        printf '%s\n' "$version"
    fi
}

sillytavern_update_reset_status() {
    ST_UPDATE_STATUS="not_checked"
    ST_UPDATE_BRANCH="unknown"
    ST_UPDATE_COMMIT="unknown"
    ST_UPDATE_UPSTREAM="unknown"
    ST_UPDATE_AHEAD=0
    ST_UPDATE_BEHIND=0
    ST_UPDATE_ERROR=""
    ST_UPDATE_LOCAL_VERSION="unknown"
    ST_UPDATE_REMOTE_VERSION="unknown"
}

sillytavern_update_load_local_status() {
    sillytavern_update_reset_status
    ST_UPDATE_LOCAL_VERSION="$(sillytavern_read_local_version)"

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

    ST_UPDATE_UPSTREAM="$GIT_UPSTREAM"
    ST_UPDATE_REMOTE_VERSION="$(sillytavern_read_remote_version "$ST_UPDATE_UPSTREAM")"

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

sillytavern_update_user_status_text() {
    case "$ST_UPDATE_STATUS" in
        not_checked) printf '%s\n' "尚未检查" ;;
        latest) printf '%s\n' "已是最新" ;;
        update_available) printf '%s\n' "可更新" ;;
        local_ahead|diverged) printf '%s\n' "本地状态特殊，无法自动更新" ;;
        fetch_failed|compare_failed) printf '%s\n' "检查失败" ;;
        no_upstream|detached|not_git|git_missing) printf '%s\n' "当前安装无法自动检查" ;;
        *) printf '%s\n' "未知状态" ;;
    esac
}

sillytavern_update_history_ensure_schema() {
    local history_file
    local history_dir
    local temporary_file
    local first_line
    local new_header=$'format\ttime\tbefore_version\tafter_version\tbefore_commit\tafter_commit\tbranch\tresult\terror'
    local old_header=$'time\tbefore\tafter\tbranch\tresult\terror'

    history_file="$(sillytavern_update_history_file)"
    history_dir="$(dirname -- "$history_file")"
    mkdir -p -- "$history_dir" || return 1

    if [[ ! -f "$history_file" ]]; then
        printf '%s\n' "$new_header" > "$history_file"
        return $?
    fi

    IFS= read -r first_line < "$history_file" || first_line=""
    if [[ "$first_line" == "$new_header" ]]; then
        return 0
    fi
    if [[ "$first_line" != "$old_header" ]]; then
        return 1
    fi

    temporary_file="$history_file.schema-v2.$$"
    {
        printf '%s\n' "$new_header"
        tail -n +2 "$history_file"
    } > "$temporary_file" || return 1
    mv -- "$temporary_file" "$history_file"
}

sillytavern_update_history_append() {
    local before_version="$1"
    local after_version="$2"
    local before_commit="$3"
    local after_commit="$4"
    local branch="$5"
    local result="$6"
    local error_summary="${7:-}"
    local history_file
    local timestamp

    history_file="$(sillytavern_update_history_file)"
    timestamp="$(date '+%Y-%m-%d %H:%M:%S %z')"
    error_summary="$(git_message_one_line "$error_summary")"
    [[ -n "$error_summary" ]] || error_summary="-"

    sillytavern_update_history_ensure_schema || return 1

    printf 'v2\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$timestamp" "$before_version" "$after_version" "$before_commit" "$after_commit" \
        "$branch" "$result" "$error_summary" \
        >> "$history_file"
}

sillytavern_update_execute() {
    local before_commit
    local after_commit
    local before_version
    local after_version

    if [[ "$ST_UPDATE_STATUS" != "update_available" ]]; then
        ST_UPDATE_ERROR="当前状态不允许自动更新：$ST_UPDATE_STATUS"
        return 1
    fi

    before_commit="$(git_current_commit "$ST_PATH")" || before_commit="unknown"
    before_version="$(sillytavern_read_local_version)"
    ST_UPDATE_LAST_BEFORE_COMMIT="$before_commit"
    ST_UPDATE_LAST_AFTER_COMMIT="$before_commit"
    ST_UPDATE_LAST_BEFORE_VERSION="$before_version"
    ST_UPDATE_LAST_AFTER_VERSION="$before_version"

    if git_has_unmerged_files "$ST_PATH"; then
        ST_UPDATE_ERROR="工作区存在未解决的合并冲突"
        sillytavern_update_history_append \
            "$before_version" "$before_version" "$before_commit" "$before_commit" \
            "$ST_UPDATE_BRANCH" "failed" "$ST_UPDATE_ERROR" || true
        return 1
    fi

    if ! git_pull_rebase_autostash "$ST_PATH"; then
        ST_UPDATE_ERROR="$GIT_LAST_ERROR"
        after_commit="$(git_current_commit "$ST_PATH")" || after_commit="$before_commit"
        after_version="$(sillytavern_read_local_version)"
        ST_UPDATE_LAST_AFTER_COMMIT="$after_commit"
        ST_UPDATE_LAST_AFTER_VERSION="$after_version"
        sillytavern_update_history_append \
            "$before_version" "$after_version" "$before_commit" "$after_commit" \
            "$ST_UPDATE_BRANCH" "failed" "$ST_UPDATE_ERROR" || true
        return 1
    fi

    after_commit="$(git_current_commit "$ST_PATH")" || after_commit="unknown"
    after_version="$(sillytavern_read_local_version)"
    ST_UPDATE_LAST_AFTER_COMMIT="$after_commit"
    ST_UPDATE_LAST_AFTER_VERSION="$after_version"
    ST_UPDATE_COMMIT="$after_commit"
    ST_UPDATE_LOCAL_VERSION="$after_version"
    ST_UPDATE_REMOTE_VERSION="$after_version"
    ST_UPDATE_AHEAD=0
    ST_UPDATE_BEHIND=0
    ST_UPDATE_STATUS="latest"
    if ! sillytavern_update_history_append \
        "$before_version" "$after_version" "$before_commit" "$after_commit" \
        "$ST_UPDATE_BRANCH" "success" ""; then
        ST_UPDATE_ERROR="更新成功，但写入更新历史失败"
        return 2
    fi

    ST_UPDATE_ERROR=""
    return 0
}

sillytavern_update_show_status() {
    local status_text
    local local_version
    local remote_version

    status_text="$(sillytavern_update_user_status_text)"
    local_version="$(sillytavern_version_display "$ST_UPDATE_LOCAL_VERSION")"
    remote_version="$(sillytavern_version_display "$ST_UPDATE_REMOTE_VERSION")"

    printf '\nSillyTavern 更新状态\n\n'
    printf '当前版本：%s\n' "$local_version"
    printf '最新版本：%s\n' "$remote_version"
    printf '更新状态：%s\n' "$status_text"
}

sillytavern_update_show_technical_details() {
    local ahead_behind_text

    case "$ST_UPDATE_STATUS" in
        latest|update_available|local_ahead|diverged)
            ahead_behind_text="领先 ${ST_UPDATE_AHEAD} 个 Commit，落后 ${ST_UPDATE_BEHIND} 个 Commit"
            ;;
        *)
            ahead_behind_text="尚未获取"
            ;;
    esac

    printf '\nSillyTavern 更新技术详情\n\n'
    printf '当前分支：%s\n' "$ST_UPDATE_BRANCH"
    printf '当前 Commit：%s\n' "$ST_UPDATE_COMMIT"
    printf 'Upstream：%s\n' "$ST_UPDATE_UPSTREAM"
    printf 'ahead / behind：%s\n' "$ahead_behind_text"
    printf 'Git 状态：%s\n' "$(sillytavern_update_status_text)"
    if [[ -n "$ST_UPDATE_ERROR" ]]; then
        printf '错误摘要：%s\n' "$ST_UPDATE_ERROR"
    fi
}

sillytavern_update_show_history() {
    local history_file
    local line
    local format
    local time
    local before_version
    local after_version
    local before_commit
    local after_commit
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

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        [[ "$line" == format$'\t'* || "$line" == time$'\t'* ]] && continue

        if [[ "$line" == v2$'\t'* ]]; then
            IFS=$'\t' read -r format time before_version after_version before_commit after_commit branch result error <<< "$line"
        else
            format="v1"
            before_version="unknown"
            after_version="unknown"
            IFS=$'\t' read -r time before_commit after_commit branch result error <<< "$line"
        fi

        count=$((count + 1))
        printf '%d. %s → %s\n' "$count" \
            "$(sillytavern_version_display "$before_version")" \
            "$(sillytavern_version_display "$after_version")"
        printf '   时间：%s\n' "$time"
        if [[ "$result" == "success" ]]; then
            printf '   结果：成功\n'
        else
            printf '   结果：失败\n'
        fi
        if [[ -n "$error" && "$error" != "-" ]]; then
            printf '   错误：%s\n' "$error"
        fi
    done < <(tail -n 20 "$history_file")

    if (( count == 0 )); then
        ui_info "暂无更新历史。"
    fi
}

sillytavern_update_show_transition() {
    printf '版本：%s → %s\n' \
        "$(sillytavern_version_display "$ST_UPDATE_LAST_BEFORE_VERSION")" \
        "$(sillytavern_version_display "$ST_UPDATE_LAST_AFTER_VERSION")"
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
    printf '确认执行官方更新命令 git pull --rebase --autostash？[y/N] '
    IFS= read -r confirm || return 1
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        ui_info "已取消更新。"
        return 0
    fi

    if [[ "${AUTO_BACKUP_BEFORE_UPDATE:-false}" == true ]]; then
        ui_info "更新前正在创建 protective 数据备份..."
        if ! backup_create protective "before-sillytavern-update"; then
            ui_error "保护备份失败，已取消 SillyTavern 更新：$BACKUP_LAST_ERROR"
            return 1
        fi
        ui_success "更新前保护备份已完成。"
    fi

    ui_info "正在更新 SillyTavern..."
    sillytavern_update_execute
    update_status=$?
    case "$update_status" in
        0)
            ui_success "SillyTavern 更新成功。"
            sillytavern_update_show_transition
            ui_info "依赖将在下次启动时由 SillyTavern 官方 start.sh 同步。"
            ;;
        2)
            sillytavern_update_show_transition
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
        printf '4. 查看技术详情\n'
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
            4)
                sillytavern_update_show_technical_details
                ui_pause
                ;;
            0)
                return 0
                ;;
            *)
                ui_warning "无效选项，请输入 0、1、2、3 或 4。"
                ui_pause
                ;;
        esac
    done
}
