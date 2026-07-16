#!/usr/bin/env bash

GIT_NETWORK_TIMEOUT_SECONDS="${GIT_NETWORK_TIMEOUT_SECONDS:-60}"
GIT_LAST_OUTPUT=""
GIT_LAST_ERROR=""
GIT_AHEAD_COUNT=0
GIT_BEHIND_COUNT=0
GIT_UPSTREAM=""

git_message_one_line() {
    local message="${1:-}"

    message="${message//$'\r'/ }"
    message="${message//$'\n'/ }"
    message="${message//$'\t'/ }"
    message="${message//|//}"
    printf '%s\n' "$message"
}

git_command_is_available() {
    command -v git >/dev/null 2>&1
}

git_repository_is_valid() {
    local repository="$1"

    [[ -d "$repository" ]] || return 1
    [[ "$(git -C "$repository" rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]]
}

git_current_branch() {
    local repository="$1"

    git -C "$repository" symbolic-ref --quiet --short HEAD 2>/dev/null
}

git_current_commit() {
    local repository="$1"

    git -C "$repository" rev-parse HEAD 2>/dev/null
}

git_short_commit() {
    local repository="$1"

    git -C "$repository" rev-parse --short=12 HEAD 2>/dev/null
}

git_current_upstream() {
    local repository="$1"

    git -C "$repository" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null
}

git_current_remote() {
    local repository="$1"
    local branch

    branch="$(git_current_branch "$repository")" || return 1
    git -C "$repository" config --get "branch.$branch.remote" 2>/dev/null
}

git_worktree_has_changes() {
    local repository="$1"

    [[ -n "$(git -C "$repository" status --porcelain --untracked-files=normal 2>/dev/null)" ]]
}

git_has_unmerged_files() {
    local repository="$1"

    [[ -n "$(git -C "$repository" diff --name-only --diff-filter=U 2>/dev/null)" ]]
}

git_run_network_command() {
    local repository="$1"
    shift
    local output
    local status
    local timeout_seconds="${GIT_NETWORK_TIMEOUT_SECONDS:-60}"
    local -a command=(
        git
        -C "$repository"
        -c http.lowSpeedLimit=1000
        -c http.lowSpeedTime=30
        "$@"
    )

    GIT_LAST_OUTPUT=""
    GIT_LAST_ERROR=""

    if [[ ! "$timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
        timeout_seconds=60
    fi

    if command -v timeout >/dev/null 2>&1; then
        output="$(GIT_TERMINAL_PROMPT=0 timeout "$timeout_seconds" "${command[@]}" 2>&1)"
        status=$?
    else
        output="$(GIT_TERMINAL_PROMPT=0 "${command[@]}" 2>&1)"
        status=$?
    fi

    GIT_LAST_OUTPUT="$output"
    if (( status != 0 )); then
        if (( status == 124 )); then
            GIT_LAST_ERROR="网络操作超过 ${timeout_seconds} 秒，已停止等待"
        elif [[ -n "$output" ]]; then
            GIT_LAST_ERROR="$(git_message_one_line "$output")"
        else
            GIT_LAST_ERROR="Git 网络操作失败，退出码：$status"
        fi
        return "$status"
    fi

    return 0
}

git_fetch_upstream() {
    local repository="$1"
    local remote

    GIT_UPSTREAM="$(git_current_upstream "$repository")" || {
        GIT_LAST_ERROR="当前分支没有 upstream"
        return 1
    }

    remote="$(git_current_remote "$repository")" || {
        GIT_LAST_ERROR="无法确定当前分支的远程仓库"
        return 1
    }

    if [[ "$remote" == "." ]]; then
        return 0
    fi

    git_run_network_command "$repository" fetch --prune "$remote"
}

git_compare_upstream() {
    local repository="$1"
    local counts

    GIT_UPSTREAM="$(git_current_upstream "$repository")" || {
        GIT_LAST_ERROR="当前分支没有 upstream"
        return 1
    }

    counts="$(git -C "$repository" rev-list --left-right --count 'HEAD...@{upstream}' 2>&1)" || {
        GIT_LAST_ERROR="$(git_message_one_line "$counts")"
        return 1
    }

    read -r GIT_AHEAD_COUNT GIT_BEHIND_COUNT <<< "$counts"
    [[ "$GIT_AHEAD_COUNT" =~ ^[0-9]+$ && "$GIT_BEHIND_COUNT" =~ ^[0-9]+$ ]] || {
        GIT_LAST_ERROR="无法解析本地与远程 Commit 差异：$counts"
        return 1
    }

    return 0
}

git_pull_rebase_autostash() {
    local repository="$1"

    git_run_network_command "$repository" pull --rebase --autostash
}
