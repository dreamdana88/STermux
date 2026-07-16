#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-git.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-git.*)
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

remote_repo="$TEST_TMP_ROOT/remote.git"
source_repo="$TEST_TMP_ROOT/source"
local_repo="$TEST_TMP_ROOT/local"
broken_repo="$TEST_TMP_ROOT/broken"

git_quiet init --bare "$remote_repo" || fail "无法创建裸仓库"
git_quiet init "$source_repo" || fail "无法创建源仓库"
git -C "$source_repo" config user.name "STermux Test"
git -C "$source_repo" config user.email "stermux-test@example.invalid"
git_quiet -C "$source_repo" checkout -b release || fail "无法创建 release 分支"
printf '%s\n' 'version=1' > "$source_repo/version.txt"
printf '%s\n' 'local=clean' > "$source_repo/local.txt"
git_quiet -C "$source_repo" add version.txt local.txt || fail "无法暂存初始文件"
git_quiet -C "$source_repo" commit -m "initial" || fail "无法创建初始 Commit"
git_quiet -C "$source_repo" remote add origin "$remote_repo" || fail "无法添加远程仓库"
git_quiet -C "$source_repo" push -u origin release || fail "无法推送初始 Commit"
git_quiet clone -b release "$remote_repo" "$local_repo" || fail "无法克隆测试仓库"

git -C "$local_repo" config user.name "STermux Test"
git -C "$local_repo" config user.email "stermux-test@example.invalid"

STERMUX_ROOT="$TEST_TMP_ROOT/stermux"
ST_PATH="$local_repo"
GIT_NETWORK_TIMEOUT_SECONDS=10
source "$PROJECT_ROOT/core/git.sh"
source "$PROJECT_ROOT/modules/sillytavern/update.sh"

sillytavern_update_refresh || fail "初始更新检查失败：$ST_UPDATE_ERROR"
[[ "$ST_UPDATE_STATUS" == "latest" ]] || fail "初始状态应为 latest，实际为 $ST_UPDATE_STATUS"

printf '%s\n' 'version=2' > "$source_repo/version.txt"
git_quiet -C "$source_repo" add version.txt || fail "无法暂存远程更新"
git_quiet -C "$source_repo" commit -m "remote update 1" || fail "无法创建远程更新"
git_quiet -C "$source_repo" push || fail "无法推送远程更新"

sillytavern_update_refresh || fail "远程更新检查失败：$ST_UPDATE_ERROR"
[[ "$ST_UPDATE_STATUS" == "update_available" ]] || fail "应检测到 update_available，实际为 $ST_UPDATE_STATUS"
[[ "$ST_UPDATE_BEHIND" == 1 ]] || fail "落后 Commit 数应为 1，实际为 $ST_UPDATE_BEHIND"

before_commit="$(git_current_commit "$local_repo")"
sillytavern_update_execute || fail "更新执行失败：$ST_UPDATE_ERROR"
after_commit="$(git_current_commit "$local_repo")"
[[ "$before_commit" != "$after_commit" ]] || fail "更新后 Commit 未变化"
[[ "$ST_UPDATE_STATUS" == "latest" ]] || fail "更新后状态不是 latest"
[[ "$(< "$local_repo/version.txt")" == "version=2" ]] || fail "远程内容未更新到本地"

history_file="$(sillytavern_update_history_file)"
[[ -s "$history_file" ]] || fail "未创建更新历史"
grep -Eq $'\tsuccess\t' "$history_file" || fail "更新历史未记录 success"
grep -Fq "$before_commit" "$history_file" || fail "更新历史缺少更新前 Commit"
grep -Fq "$after_commit" "$history_file" || fail "更新历史缺少更新后 Commit"

printf '%s\n' 'local=modified' > "$local_repo/local.txt"
printf '%s\n' 'version=3' > "$source_repo/version.txt"
git_quiet -C "$source_repo" add version.txt || fail "无法暂存第二次远程更新"
git_quiet -C "$source_repo" commit -m "remote update 2" || fail "无法创建第二次远程更新"
git_quiet -C "$source_repo" push || fail "无法推送第二次远程更新"

sillytavern_update_refresh || fail "带本地修改时检查失败：$ST_UPDATE_ERROR"
[[ "$ST_UPDATE_STATUS" == "update_available" ]] || fail "带本地修改时未检测到更新"
git_worktree_has_changes "$local_repo" || fail "未识别本地文件修改"
sillytavern_update_execute || fail "--autostash 更新失败：$ST_UPDATE_ERROR"
[[ "$(< "$local_repo/version.txt")" == "version=3" ]] || fail "第二次远程内容未更新"
[[ "$(< "$local_repo/local.txt")" == "local=modified" ]] || fail "--autostash 未恢复本地修改"

git_quiet -C "$local_repo" restore local.txt || fail "无法恢复测试文件"
printf '%s\n' 'local commit' > "$local_repo/local-only.txt"
git_quiet -C "$local_repo" add local-only.txt || fail "无法暂存本地 Commit"
git_quiet -C "$local_repo" commit -m "local-only commit" || fail "无法创建本地 Commit"
printf '%s\n' 'remote commit' > "$source_repo/remote-only.txt"
git_quiet -C "$source_repo" add remote-only.txt || fail "无法暂存远程分叉 Commit"
git_quiet -C "$source_repo" commit -m "remote-only commit" || fail "无法创建远程分叉 Commit"
git_quiet -C "$source_repo" push || fail "无法推送远程分叉 Commit"

sillytavern_update_refresh || fail "分叉状态检查失败：$ST_UPDATE_ERROR"
[[ "$ST_UPDATE_STATUS" == "diverged" ]] || fail "分叉状态错误：$ST_UPDATE_STATUS"
if sillytavern_update_execute; then
    fail "分叉状态下自动更新意外执行"
fi

git_quiet -C "$local_repo" branch --unset-upstream || fail "无法移除 upstream"
if sillytavern_update_load_local_status; then
    fail "没有 upstream 时状态检查意外成功"
fi
[[ "$ST_UPDATE_STATUS" == "no_upstream" ]] || fail "无 upstream 状态错误：$ST_UPDATE_STATUS"

git_quiet clone -b release "$remote_repo" "$broken_repo" || fail "无法创建网络失败测试仓库"
git_quiet -C "$broken_repo" remote set-url origin "$TEST_TMP_ROOT/missing-remote.git" || fail "无法设置失效远程"
ST_PATH="$broken_repo"
if sillytavern_update_refresh; then
    fail "失效远程的 fetch 意外成功"
fi
[[ "$ST_UPDATE_STATUS" == "fetch_failed" ]] || fail "fetch 失败状态错误：$ST_UPDATE_STATUS"
[[ -n "$ST_UPDATE_ERROR" ]] || fail "fetch 失败缺少错误摘要"

ST_PATH="$TEST_TMP_ROOT/not-a-repository"
mkdir -p -- "$ST_PATH"
if sillytavern_update_load_local_status; then
    fail "非 Git 目录状态检查意外成功"
fi
[[ "$ST_UPDATE_STATUS" == "not_git" ]] || fail "非 Git 状态错误：$ST_UPDATE_STATUS"

printf '%s\n' 'PASS: Git 状态、更新、autostash、历史及失败隔离测试通过'
