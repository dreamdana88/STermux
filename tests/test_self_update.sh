#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-self-update.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-self-update.*)
            rm -rf -- "$TEST_TMP_ROOT"
            ;;
        *)
            printf '拒绝清理非测试目录：%s\n' "$TEST_TMP_ROOT" >&2
            ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

git_quiet() {
    git "$@" >/dev/null 2>&1
}

create_repository_set() {
    local name="$1"

    REMOTE_REPO="$TEST_TMP_ROOT/$name-remote.git"
    SOURCE_REPO="$TEST_TMP_ROOT/$name-source"
    LOCAL_REPO="$TEST_TMP_ROOT/$name-local"

    git_quiet init --bare "$REMOTE_REPO" || return 1
    git_quiet init "$SOURCE_REPO" || return 1
    git -C "$SOURCE_REPO" config user.name "STermux Test"
    git -C "$SOURCE_REPO" config user.email "stermux-test@example.invalid"
    git_quiet -C "$SOURCE_REPO" checkout -b release || return 1
    mkdir -p -- "$SOURCE_REPO/core" "$SOURCE_REPO/config"
    printf '%s\n' '#!/usr/bin/env bash' 'printf "manager-v1\n"' > "$SOURCE_REPO/manager.sh"
    printf '%s\n' 'program-v1' > "$SOURCE_REPO/core/program.txt"
    printf '%s\n' '# runtime config' > "$SOURCE_REPO/config/user.conf"
    printf '%s\n' '# extension policy' > "$SOURCE_REPO/config/extension-policy.conf"
    git_quiet -C "$SOURCE_REPO" add manager.sh core/program.txt \
        config/user.conf config/extension-policy.conf || return 1
    git_quiet -C "$SOURCE_REPO" commit -m "initial" || return 1
    git_quiet -C "$SOURCE_REPO" remote add origin "$REMOTE_REPO" || return 1
    git_quiet -C "$SOURCE_REPO" push -u origin release || return 1
    git_quiet clone -b release "$REMOTE_REPO" "$LOCAL_REPO" || return 1
    git -C "$LOCAL_REPO" config user.name "STermux Test"
    git -C "$LOCAL_REPO" config user.email "stermux-test@example.invalid"
}

push_remote_program_change() {
    local value="$1"

    printf '%s\n' "$value" > "$SOURCE_REPO/core/program.txt"
    git_quiet -C "$SOURCE_REPO" add core/program.txt || return 1
    git_quiet -C "$SOURCE_REPO" commit -m "$value" || return 1
    git_quiet -C "$SOURCE_REPO" push || return 1
}

GIT_NETWORK_TIMEOUT_SECONDS=10
STERMUX_ROOT="$TEST_TMP_ROOT/not-set"
source "$PROJECT_ROOT/core/git.sh"
source "$PROJECT_ROOT/core/ui.sh"
source "$PROJECT_ROOT/modules/stermux/update.sh"
ui_initialize

create_repository_set "main" || fail "无法创建主自更新测试仓库"
STERMUX_ROOT="$LOCAL_REPO"
silly_config_value='ST_PATH="$HOME/SillyTavern"'
extension_policy_value='ManualExtension=manual'

stermux_update_refresh || fail "最新状态检查失败：$STERMUX_UPDATE_ERROR"
[[ "$STERMUX_UPDATE_STATUS" == "latest" ]] || fail "初始状态不是 latest"
status_output="$(stermux_update_show_status)"
[[ "$status_output" == *"当前版本：开发版"* ]] || fail "普通状态缺少开发版显示"
[[ "$status_output" == *"当前状态：已是最新"* ]] || fail "普通状态缺少最新提示"
[[ "$status_output" != *"Commit"* && "$status_output" != *"Upstream"* ]] \
    || fail "普通状态泄露 Git 技术信息"
technical_output="$(stermux_update_show_technical_details)"
[[ "$technical_output" == *"当前 Commit："* && "$technical_output" == *"Upstream：origin/release"* ]] \
    || fail "技术详情缺少 Git 信息"

push_remote_program_change "program-v2" || fail "无法创建远程更新"
stermux_update_refresh || fail "远程更新检查失败：$STERMUX_UPDATE_ERROR"
[[ "$STERMUX_UPDATE_STATUS" == "update_available" ]] || fail "未检测到远程更新"
before_commit="$(git_current_commit "$LOCAL_REPO")"
printf '%s\n' "$silly_config_value" > "$LOCAL_REPO/config/user.conf"
printf '%s\n' "$extension_policy_value" > "$LOCAL_REPO/config/extension-policy.conf"
if stermux_update_program_files_have_changes; then
    fail "运行时配置被误判为程序文件修改"
fi
stermux_update_execute || fail "ff-only 自更新失败：$STERMUX_UPDATE_ERROR"
after_commit="$(git_current_commit "$LOCAL_REPO")"
[[ "$before_commit" != "$after_commit" ]] || fail "自更新成功后 Commit 未变化"
[[ "$(< "$LOCAL_REPO/core/program.txt")" == "program-v2" ]] || fail "自更新未获取远程程序文件"
[[ "$(< "$LOCAL_REPO/config/user.conf")" == "$silly_config_value" ]] || fail "自更新覆盖了运行时配置"
[[ "$(< "$LOCAL_REPO/config/extension-policy.conf")" == "$extension_policy_value" ]] \
    || fail "自更新覆盖了扩展更新策略"
grep -Fq $'success\trelease' "$(stermux_update_log_file)" || fail "自更新成功未写日志"

push_remote_program_change "program-v3" || fail "无法创建本地修改拒绝场景"
stermux_update_refresh || fail "本地修改场景检查失败"
printf '%s\n' 'local tracked modification' > "$LOCAL_REPO/manager.sh"
blocked_commit="$(git_current_commit "$LOCAL_REPO")"
if stermux_update_execute; then
    fail "tracked 程序文件修改时仍执行了更新"
fi
[[ "$STERMUX_UPDATE_STATUS" == "local_changes" ]] || fail "本地修改状态错误"
[[ "$(git_current_commit "$LOCAL_REPO")" == "$blocked_commit" ]] || fail "拒绝更新时 Commit 被改变"
git_quiet -C "$LOCAL_REPO" restore manager.sh || fail "无法恢复本地修改 Fixture"

create_repository_set "diverged" || fail "无法创建分叉测试仓库"
STERMUX_ROOT="$LOCAL_REPO"
printf '%s\n' 'local commit' > "$LOCAL_REPO/local.txt"
git_quiet -C "$LOCAL_REPO" add local.txt
git_quiet -C "$LOCAL_REPO" commit -m "local commit" || fail "无法创建本地 Commit"
push_remote_program_change "remote-diverged" || fail "无法创建远程分叉 Commit"
stermux_update_refresh || fail "分叉状态检查失败"
[[ "$STERMUX_UPDATE_STATUS" == "diverged" ]] || fail "分叉状态识别错误"
if stermux_update_execute; then
    fail "分叉状态下意外执行自动更新"
fi

create_repository_set "local-ahead" || fail "无法创建本地领先测试仓库"
STERMUX_ROOT="$LOCAL_REPO"
printf '%s\n' 'local ahead commit' > "$LOCAL_REPO/local-ahead.txt"
git_quiet -C "$LOCAL_REPO" add local-ahead.txt
git_quiet -C "$LOCAL_REPO" commit -m "local ahead" || fail "无法创建本地领先 Commit"
stermux_update_refresh || fail "本地领先状态检查失败"
[[ "$STERMUX_UPDATE_STATUS" == "local_ahead" ]] || fail "本地领先状态识别错误"
if stermux_update_execute; then
    fail "本地领先状态下意外执行自动更新"
fi

create_repository_set "no-upstream" || fail "无法创建无 upstream 仓库"
STERMUX_ROOT="$LOCAL_REPO"
git_quiet -C "$LOCAL_REPO" branch --unset-upstream || fail "无法移除 upstream"
if stermux_update_load_local_status; then
    fail "无 upstream 状态意外成功"
fi
[[ "$STERMUX_UPDATE_STATUS" == "no_upstream" ]] || fail "无 upstream 状态错误"

create_repository_set "detached" || fail "无法创建 detached 仓库"
STERMUX_ROOT="$LOCAL_REPO"
git_quiet -C "$LOCAL_REPO" checkout --detach || fail "无法进入 detached HEAD"
if stermux_update_load_local_status; then
    fail "detached HEAD 状态意外成功"
fi
[[ "$STERMUX_UPDATE_STATUS" == "detached" ]] || fail "detached HEAD 状态错误"

create_repository_set "fetch-failure" || fail "无法创建 fetch 失败仓库"
STERMUX_ROOT="$LOCAL_REPO"
git_quiet -C "$LOCAL_REPO" remote set-url origin "$TEST_TMP_ROOT/missing-fetch-remote.git"
if stermux_update_refresh; then
    fail "失效远程 fetch 意外成功"
fi
[[ "$STERMUX_UPDATE_STATUS" == "fetch_failed" ]] || fail "fetch 失败状态错误"

create_repository_set "pull-failure" || fail "无法创建 pull 失败仓库"
STERMUX_ROOT="$LOCAL_REPO"
push_remote_program_change "pull-failure-update" || fail "无法创建 pull 失败远程更新"
stermux_update_refresh || fail "pull 失败前检查失败"
git_quiet -C "$LOCAL_REPO" remote set-url origin "$TEST_TMP_ROOT/missing-pull-remote.git"
if stermux_update_execute; then
    fail "失效远程 pull 意外成功"
fi
[[ "$STERMUX_UPDATE_STATUS" == "pull_failed" ]] || fail "pull 失败状态错误"

STERMUX_ROOT="$TEST_TMP_ROOT/not-a-repository"
mkdir -p -- "$STERMUX_ROOT"
if stermux_update_load_local_status; then
    fail "非 Git 目录意外通过自更新检查"
fi
[[ "$STERMUX_UPDATE_STATUS" == "not_git" ]] || fail "非 Git 目录状态错误"

git() {
    printf '%s\n' 'CANNOT LINK EXECUTABLE: libcrypto.so missing' >&2
    return 127
}
if stermux_update_load_local_status; then
    fail "损坏 git 命令意外通过检查"
fi
[[ "$STERMUX_UPDATE_STATUS" == "git_unusable" ]] || fail "损坏 git 状态错误"
[[ "$STERMUX_UPDATE_ERROR" == *"CANNOT LINK EXECUTABLE"* ]] || fail "损坏 git 诊断丢失"
unset -f git

create_repository_set "restart" || fail "无法创建重启测试仓库"
STERMUX_ROOT="$LOCAL_REPO"
push_remote_program_change "restart-update" || fail "无法创建重启远程更新"
stermux_update_refresh || fail "重启场景检查失败"
restart_marker="$TEST_TMP_ROOT/restart-called"
stermux_update_restart_program() {
    printf '%s\n' 'RESTARTED' > "$restart_marker"
    return 0
}
stermux_update_apply_and_restart >/dev/null 2>&1 || fail "更新后重启流程失败"
[[ -f "$restart_marker" ]] || fail "更新成功后未触发重启逻辑"

create_repository_set "restart-failure" || fail "无法创建重启失败仓库"
STERMUX_ROOT="$LOCAL_REPO"
push_remote_program_change "restart-failure-update" || fail "无法创建重启失败远程更新"
stermux_update_refresh || fail "重启失败场景检查失败"
stermux_update_restart_program() { return 1; }
restart_status=0
stermux_update_apply_and_restart >/dev/null 2>&1 || restart_status=$?
[[ "$restart_status" == 2 ]] || fail "重启失败未返回独立状态"
[[ "$STERMUX_UPDATE_STATUS" == "restart_failed" ]] || fail "重启失败状态错误"

printf '%s\n' 'PASS: STermux 自更新状态、ff-only、安全拒绝、失败隔离及重启测试通过'
