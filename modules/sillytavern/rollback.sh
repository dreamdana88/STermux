#!/usr/bin/env bash

ST_ROLLBACK_ERROR=""
ST_ROLLBACK_FETCH_STATUS="not_attempted"
ST_ROLLBACK_FETCH_ERROR=""
ST_ROLLBACK_BRANCH="unknown"
ST_ROLLBACK_UPSTREAM="unknown"
ST_ROLLBACK_REMOTE="unknown"
ST_ROLLBACK_REMOTE_URL="unknown"
ST_ROLLBACK_CURRENT_VERSION="unknown"
ST_ROLLBACK_CURRENT_COMMIT="unknown"
ST_ROLLBACK_LIST_SOURCE_COMMIT="unknown"
ST_ROLLBACK_LAST_BEFORE_VERSION="unknown"
ST_ROLLBACK_LAST_AFTER_VERSION="unknown"
ST_ROLLBACK_LAST_TARGET_VERSION="unknown"
ST_ROLLBACK_LAST_BACKUP_RESULT="not_run"
ST_ROLLBACK_LAST_GIT_RESULT="not_run"
ST_ROLLBACK_LAST_DEPENDENCY_RESULT="not_run"

declare -a ST_ROLLBACK_VERSIONS=()
declare -a ST_ROLLBACK_TAGS=()
declare -a ST_ROLLBACK_COMMITS=()

sillytavern_rollback_log_file() {
    printf '%s\n' "$STERMUX_ROOT/data/state/rollback-history.log"
}

sillytavern_rollback_log_append() {
    local before_version="$1" before_commit="$2" target_version="$3" target_commit="$4"
    local branch="$5" backup_result="$6" git_result="$7" dependency_result="$8"
    local result="$9" error_summary="${10:-}" log_file

    log_file="$(sillytavern_rollback_log_file)"
    mkdir -p -- "$(dirname -- "$log_file")" 2>/dev/null || return 1
    if [[ ! -f "$log_file" ]]; then
        printf 'format\ttime\tbefore_version\tbefore_commit\ttarget_version\ttarget_commit\tbranch\tbackup\tgit\tdependencies\tresult\terror\n' \
            > "$log_file" || return 1
    fi
    error_summary="$(git_message_one_line "$error_summary")"
    [[ -n "$error_summary" ]] || error_summary="-"
    printf 'v1\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S %z')" "$before_version" "$before_commit" \
        "$target_version" "$target_commit" "$branch" "$backup_result" "$git_result" \
        "$dependency_result" "$result" "$error_summary" >> "$log_file"
}

sillytavern_release_version_is_valid() {
    local version="$1"

    [[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

sillytavern_version_is_older() {
    local candidate="$1" current="$2"
    local candidate_major candidate_minor candidate_patch
    local current_major current_minor current_patch

    sillytavern_release_version_is_valid "$candidate" || return 1
    sillytavern_release_version_is_valid "$current" || return 1
    IFS=. read -r candidate_major candidate_minor candidate_patch <<< "$candidate"
    IFS=. read -r current_major current_minor current_patch <<< "$current"
    (( candidate_major < current_major )) && return 0
    (( candidate_major > current_major )) && return 1
    (( candidate_minor < current_minor )) && return 0
    (( candidate_minor > current_minor )) && return 1
    (( candidate_patch < current_patch ))
}

sillytavern_rollback_remote_is_official() {
    local url="${1:-}" normalized

    normalized="${url%/}"
    normalized="${normalized%.git}"
    normalized="${normalized,,}"
    case "$normalized" in
        https://github.com/sillytavern/sillytavern|git@github.com:sillytavern/sillytavern|ssh://git@github.com/sillytavern/sillytavern)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

sillytavern_rollback_repository_state() {
    ST_ROLLBACK_ERROR=""
    if ! sillytavern_path_is_valid "${ST_PATH:-}"; then
        ST_ROLLBACK_ERROR="当前 SillyTavern 路径无效"
        return 1
    fi
    if ! git_command_is_available; then
        ST_ROLLBACK_ERROR="Git 命令不可用"
        return 1
    fi
    if ! git_repository_is_valid "$ST_PATH"; then
        ST_ROLLBACK_ERROR="当前 SillyTavern 不是有效的 Git 仓库"
        return 1
    fi
    ST_ROLLBACK_BRANCH="$(git_current_branch "$ST_PATH")" || {
        ST_ROLLBACK_ERROR="当前处于 detached HEAD，无法安全回退"
        return 1
    }
    ST_ROLLBACK_CURRENT_COMMIT="$(git_current_commit "$ST_PATH")" || {
        ST_ROLLBACK_ERROR="无法确定当前 SillyTavern Commit"
        return 1
    }
    ST_ROLLBACK_UPSTREAM="$(git_current_upstream "$ST_PATH")" || {
        ST_ROLLBACK_ERROR="当前分支没有 upstream，无法保证回退后可重新升级"
        return 1
    }
    ST_ROLLBACK_REMOTE="$(git_current_remote "$ST_PATH")" || {
        ST_ROLLBACK_ERROR="无法确定当前 SillyTavern 远程仓库"
        return 1
    }
    ST_ROLLBACK_REMOTE_URL="$(git_remote_url "$ST_PATH" "$ST_ROLLBACK_REMOTE")" \
        || ST_ROLLBACK_REMOTE_URL="unknown"
    if ! git_compare_upstream "$ST_PATH"; then
        ST_ROLLBACK_ERROR="无法比较当前分支与 upstream：$GIT_LAST_ERROR"
        return 1
    fi
    if (( GIT_AHEAD_COUNT > 0 )); then
        ST_ROLLBACK_ERROR="当前分支包含本地 Commit 或已与远程分叉，不能自动回退"
        return 1
    fi
    return 0
}

sillytavern_rollback_versions_reset() {
    ST_ROLLBACK_VERSIONS=()
    ST_ROLLBACK_TAGS=()
    ST_ROLLBACK_COMMITS=()
}

sillytavern_rollback_collect_versions() {
    local tag commit json version
    local -a tags=()

    sillytavern_rollback_versions_reset
    mapfile -t tags < <(git -C "$ST_PATH" tag --list 2>/dev/null | sort -V -r)
    for tag in "${tags[@]}"; do
        sillytavern_release_version_is_valid "$tag" || continue
        sillytavern_version_is_older "$tag" "$ST_ROLLBACK_CURRENT_VERSION" || continue
        commit="$(git_ref_commit "$ST_PATH" "$tag")" || continue
        git_commit_is_ancestor "$ST_PATH" "$commit" "$ST_ROLLBACK_CURRENT_COMMIT" || continue
        json="$(git_show_file_at_ref "$ST_PATH" "$tag" package.json)" || continue
        version="$(sillytavern_version_from_json "$json")" || continue
        [[ "$version" == "$tag" ]] || continue
        ST_ROLLBACK_VERSIONS+=("$version")
        ST_ROLLBACK_TAGS+=("$tag")
        ST_ROLLBACK_COMMITS+=("$commit")
    done
    (( ${#ST_ROLLBACK_VERSIONS[@]} > 0 ))
}

sillytavern_rollback_refresh_versions() {
    ST_ROLLBACK_FETCH_STATUS="not_attempted"
    ST_ROLLBACK_FETCH_ERROR=""
    sillytavern_rollback_versions_reset
    sillytavern_rollback_repository_state || return 1
    ST_ROLLBACK_CURRENT_VERSION="$(sillytavern_read_local_version)"
    sillytavern_release_version_is_valid "$ST_ROLLBACK_CURRENT_VERSION" || {
        ST_ROLLBACK_ERROR="当前 SillyTavern 版本未知，无法确认安全回退范围"
        return 1
    }

    if sillytavern_rollback_remote_is_official "$ST_ROLLBACK_REMOTE_URL"; then
        if git_fetch_tags "$ST_PATH"; then
            ST_ROLLBACK_FETCH_STATUS="success"
            sillytavern_rollback_repository_state || return 1
        else
            ST_ROLLBACK_FETCH_STATUS="failed"
            ST_ROLLBACK_FETCH_ERROR="$GIT_LAST_ERROR"
        fi
    else
        ST_ROLLBACK_FETCH_STATUS="skipped_non_official"
        ST_ROLLBACK_FETCH_ERROR="当前 upstream 不是可确认的 SillyTavern 官方 GitHub 仓库，已跳过联网刷新"
    fi

    ST_ROLLBACK_LIST_SOURCE_COMMIT="$ST_ROLLBACK_CURRENT_COMMIT"
    if ! sillytavern_rollback_collect_versions; then
        ST_ROLLBACK_ERROR="没有找到当前版本之前、且可验证的正式版本 tag"
        return 1
    fi
    return 0
}

sillytavern_rollback_target_is_valid() {
    local target_version="$1" target_tag="$2" target_commit="$3"
    local index actual_commit json actual_version

    for ((index = 0; index < ${#ST_ROLLBACK_VERSIONS[@]}; index++)); do
        [[ "${ST_ROLLBACK_VERSIONS[index]}" == "$target_version" \
            && "${ST_ROLLBACK_TAGS[index]}" == "$target_tag" \
            && "${ST_ROLLBACK_COMMITS[index]}" == "$target_commit" ]] || continue
        actual_commit="$(git_ref_commit "$ST_PATH" "$target_tag")" || return 1
        [[ "$actual_commit" == "$target_commit" ]] || return 1
        git_commit_is_ancestor "$ST_PATH" "$target_commit" "$ST_ROLLBACK_CURRENT_COMMIT" || return 1
        json="$(git_show_file_at_ref "$ST_PATH" "$target_tag" package.json)" || return 1
        actual_version="$(sillytavern_version_from_json "$json")" || return 1
        [[ "$actual_version" == "$target_version" ]] || return 1
        return 0
    done
    return 1
}

sillytavern_rollback_dependencies_are_ready() {
    local command_name output

    for command_name in node npm; do
        command -v "$command_name" >/dev/null 2>&1 || {
            ST_ROLLBACK_ERROR="$command_name 未安装，无法完成回退后的依赖同步"
            return 1
        }
        output="$("$command_name" --version 2>&1)" || {
            ST_ROLLBACK_ERROR="$command_name 已存在但无法运行：$(git_message_one_line "$output")"
            return 1
        }
    done
    return 0
}

sillytavern_rollback_npm_install() {
    (
        cd -- "$ST_PATH" || exit 1
        npm install --no-save --no-audit --no-fund --omit=dev --ignore-scripts
    )
}

sillytavern_rollback_sync_dependencies() {
    ui_info "目标版本的 Node Modules 需要同步，此过程可能需要几分钟。"
    backup_run_with_progress '依赖' '同步 SillyTavern Node Modules' \
        sillytavern_rollback_npm_install
}

sillytavern_rollback_verify_target() {
    local target_version="$1" target_commit="$2" branch="$3" upstream="$4"

    [[ "$(git_current_commit "$ST_PATH" 2>/dev/null)" == "$target_commit" ]] || return 1
    [[ "$(git_current_branch "$ST_PATH" 2>/dev/null)" == "$branch" ]] || return 1
    [[ "$(git_current_upstream "$ST_PATH" 2>/dev/null)" == "$upstream" ]] || return 1
    [[ "$(sillytavern_read_local_version)" == "$target_version" ]] || return 1
    sillytavern_path_is_valid "$ST_PATH" || return 1
    git_compare_upstream "$ST_PATH" || return 1
    (( GIT_AHEAD_COUNT == 0 ))
}

sillytavern_rollback_restore_original() {
    local original_commit="$1" branch="$2" upstream="$3"

    git_reset_hard_to_commit "$ST_PATH" "$original_commit" || return 1
    [[ "$(git_current_commit "$ST_PATH" 2>/dev/null)" == "$original_commit" ]] || return 1
    [[ "$(git_current_branch "$ST_PATH" 2>/dev/null)" == "$branch" ]] || return 1
    [[ "$(git_current_upstream "$ST_PATH" 2>/dev/null)" == "$upstream" ]]
}

sillytavern_rollback_execute() {
    local target_version="$1" target_tag="$2" target_commit="$3"
    local before_version before_commit branch upstream backup_id="unknown"

    ST_ROLLBACK_ERROR=""
    ST_ROLLBACK_LAST_BACKUP_RESULT="not_run"
    ST_ROLLBACK_LAST_GIT_RESULT="not_run"
    ST_ROLLBACK_LAST_DEPENDENCY_RESULT="not_run"
    sillytavern_rollback_repository_state || return 1
    before_version="$(sillytavern_read_local_version)"
    before_commit="$ST_ROLLBACK_CURRENT_COMMIT"
    branch="$ST_ROLLBACK_BRANCH"
    upstream="$ST_ROLLBACK_UPSTREAM"
    ST_ROLLBACK_LAST_BEFORE_VERSION="$before_version"
    ST_ROLLBACK_LAST_AFTER_VERSION="$before_version"
    ST_ROLLBACK_LAST_TARGET_VERSION="$target_version"

    if [[ "$before_commit" != "$ST_ROLLBACK_LIST_SOURCE_COMMIT" ]]; then
        ST_ROLLBACK_ERROR="版本列表生成后 HEAD 已发生变化，请重新打开版本回退页面"
    elif ! sillytavern_rollback_target_is_valid "$target_version" "$target_tag" "$target_commit"; then
        ST_ROLLBACK_ERROR="目标版本不在当前已验证的安全回退列表中"
    elif git_has_unmerged_files "$ST_PATH"; then
        ST_ROLLBACK_ERROR="工作区存在未解决的合并冲突"
    elif git_tracked_worktree_has_changes "$ST_PATH"; then
        ST_ROLLBACK_ERROR="检测到 tracked 程序文件存在本地修改，请先自行提交、暂存或还原"
    elif ! sillytavern_rollback_dependencies_are_ready; then
        :
    fi
    if [[ -n "$ST_ROLLBACK_ERROR" ]]; then
        sillytavern_rollback_log_append "$before_version" "$before_commit" "$target_version" \
            "$target_commit" "$branch" "not_run" "not_run" "not_run" "failed" \
            "$ST_ROLLBACK_ERROR" || true
        return 1
    fi

    ui_info "正在创建回退前保护备份..."
    if ! backup_create protective "before-sillytavern-rollback:$target_version"; then
        ST_ROLLBACK_LAST_BACKUP_RESULT="failed"
        ST_ROLLBACK_ERROR="保护备份失败，已取消版本回退：$BACKUP_LAST_ERROR"
        sillytavern_rollback_log_append "$before_version" "$before_commit" "$target_version" \
            "$target_commit" "$branch" "failed" "not_run" "not_run" "failed" \
            "$ST_ROLLBACK_ERROR" || true
        return 1
    fi
    backup_id="$(basename -- "$BACKUP_LAST_PATH" 2>/dev/null || printf unknown)"
    ST_ROLLBACK_LAST_BACKUP_RESULT="success:$backup_id"

    ui_info "保护备份已完成，正在安全切换 SillyTavern 程序版本..."
    if ! git_reset_hard_to_commit "$ST_PATH" "$target_commit"; then
        ST_ROLLBACK_LAST_GIT_RESULT="failed"
        ST_ROLLBACK_ERROR="Git 版本切换失败：$GIT_LAST_ERROR"
        sillytavern_rollback_log_append "$before_version" "$before_commit" "$target_version" \
            "$target_commit" "$branch" "$ST_ROLLBACK_LAST_BACKUP_RESULT" "failed" \
            "not_run" "failed" "$ST_ROLLBACK_ERROR" || true
        return 1
    fi
    ST_ROLLBACK_LAST_GIT_RESULT="success"

    if ! sillytavern_rollback_verify_target "$target_version" "$target_commit" "$branch" "$upstream"; then
        if sillytavern_rollback_restore_original "$before_commit" "$branch" "$upstream"; then
            ST_ROLLBACK_LAST_GIT_RESULT="restored"
            ST_ROLLBACK_ERROR="目标版本验证失败，程序代码已恢复到回退前 Commit"
        else
            ST_ROLLBACK_LAST_GIT_RESULT="restore_failed"
            ST_ROLLBACK_ERROR="目标版本验证失败，且无法恢复回退前 Commit；请停止启动 SillyTavern 并查看日志"
        fi
        sillytavern_rollback_log_append "$before_version" "$before_commit" "$target_version" \
            "$target_commit" "$branch" "$ST_ROLLBACK_LAST_BACKUP_RESULT" \
            "$ST_ROLLBACK_LAST_GIT_RESULT" "not_run" "failed" "$ST_ROLLBACK_ERROR" || true
        return 1
    fi

    if ! sillytavern_rollback_sync_dependencies; then
        ST_ROLLBACK_LAST_DEPENDENCY_RESULT="failed"
        if sillytavern_rollback_restore_original "$before_commit" "$branch" "$upstream"; then
            ST_ROLLBACK_LAST_GIT_RESULT="restored"
            ST_ROLLBACK_ERROR="依赖同步失败，程序代码已恢复到回退前版本；用户数据未自动恢复"
        else
            ST_ROLLBACK_LAST_GIT_RESULT="restore_failed"
            ST_ROLLBACK_ERROR="依赖同步失败，且无法恢复回退前 Commit；请停止启动 SillyTavern 并查看日志"
        fi
        sillytavern_rollback_log_append "$before_version" "$before_commit" "$target_version" \
            "$target_commit" "$branch" "$ST_ROLLBACK_LAST_BACKUP_RESULT" \
            "$ST_ROLLBACK_LAST_GIT_RESULT" "failed" "failed" "$ST_ROLLBACK_ERROR" || true
        return 1
    fi
    ST_ROLLBACK_LAST_DEPENDENCY_RESULT="success"

    if git_tracked_worktree_has_changes "$ST_PATH" \
        || ! sillytavern_rollback_verify_target "$target_version" "$target_commit" "$branch" "$upstream"; then
        if sillytavern_rollback_restore_original "$before_commit" "$branch" "$upstream"; then
            ST_ROLLBACK_LAST_GIT_RESULT="restored"
            ST_ROLLBACK_ERROR="依赖同步后的最终验证失败，程序代码已恢复到回退前版本"
        else
            ST_ROLLBACK_LAST_GIT_RESULT="restore_failed"
            ST_ROLLBACK_ERROR="最终验证失败，且无法恢复回退前 Commit；请停止启动 SillyTavern 并查看日志"
        fi
        sillytavern_rollback_log_append "$before_version" "$before_commit" "$target_version" \
            "$target_commit" "$branch" "$ST_ROLLBACK_LAST_BACKUP_RESULT" \
            "$ST_ROLLBACK_LAST_GIT_RESULT" "$ST_ROLLBACK_LAST_DEPENDENCY_RESULT" \
            "failed" "$ST_ROLLBACK_ERROR" || true
        return 1
    fi

    ST_ROLLBACK_LAST_AFTER_VERSION="$(sillytavern_read_local_version)"
    if ! sillytavern_rollback_log_append "$before_version" "$before_commit" "$target_version" \
        "$target_commit" "$branch" "$ST_ROLLBACK_LAST_BACKUP_RESULT" "success" "success" \
        "success" ""; then
        ST_ROLLBACK_ERROR="版本回退成功，但写入回退日志失败"
        return 2
    fi
    return 0
}

sillytavern_rollback_show_versions() {
    local index

    ui_page_header 'SillyTavern 版本回退'
    printf '\n当前版本：%s\n\n' "$ST_ROLLBACK_CURRENT_VERSION"
    printf '可回退版本：\n\n'
    for ((index = 0; index < ${#ST_ROLLBACK_VERSIONS[@]}; index++)); do
        printf '%d. %s\n' "$((index + 1))" "${ST_ROLLBACK_VERSIONS[index]}"
    done
    printf '\n0. 返回\n\n'
    if [[ "$ST_ROLLBACK_FETCH_STATUS" == failed ]]; then
        ui_warning "官方 tag 刷新失败，当前列表来自本地已有 tag：$ST_ROLLBACK_FETCH_ERROR"
    elif [[ "$ST_ROLLBACK_FETCH_STATUS" == skipped_non_official ]]; then
        ui_warning "$ST_ROLLBACK_FETCH_ERROR"
    fi
}

sillytavern_rollback_interactive() {
    local input index confirm target_version target_tag target_commit status

    ui_info "正在刷新并验证 SillyTavern 正式版本 tag..."
    if ! sillytavern_rollback_refresh_versions; then
        ui_error "无法生成安全回退列表：$ST_ROLLBACK_ERROR"
        return 1
    fi
    sillytavern_rollback_show_versions
    printf '请选择目标版本 [0-%s]：' "${#ST_ROLLBACK_VERSIONS[@]}"
    IFS= read -r input || return 1
    [[ "$input" == 0 ]] && return 0
    if [[ ! "$input" =~ ^(0|[1-9][0-9]*)$ ]] \
        || (( input < 1 || input > ${#ST_ROLLBACK_VERSIONS[@]} )); then
        ui_warning "无效版本编号。只能从上方已验证列表中选择。"
        return 1
    fi
    index=$((input - 1))
    target_version="${ST_ROLLBACK_VERSIONS[index]}"
    target_tag="${ST_ROLLBACK_TAGS[index]}"
    target_commit="${ST_ROLLBACK_COMMITS[index]}"

    printf '\n当前版本：%s\n' "$ST_ROLLBACK_CURRENT_VERSION"
    printf '目标版本：%s\n\n' "$target_version"
    printf '即将创建回退前保护备份。\n'
    printf '版本回退可能存在新版数据与旧版程序不兼容的风险。\n\n'
    printf '确认回退？[y/N] '
    IFS= read -r confirm || return 1
    if [[ "$confirm" != y && "$confirm" != Y ]]; then
        ui_info "已取消版本回退。"
        return 0
    fi

    sillytavern_rollback_execute "$target_version" "$target_tag" "$target_commit"
    status=$?
    case "$status" in
        0)
            ui_success "版本回退完成"
            printf '\n原版本：%s\n' "$ST_ROLLBACK_LAST_BEFORE_VERSION"
            printf '当前版本：%s\n\n' "$ST_ROLLBACK_LAST_AFTER_VERSION"
            ui_success "回退前保护备份已创建。"
            ui_info "建议重新启动 SillyTavern。"
            ;;
        2)
            ui_warning "$ST_ROLLBACK_ERROR"
            ;;
        *)
            ui_error "版本回退失败：$ST_ROLLBACK_ERROR"
            return 1
            ;;
    esac
}
