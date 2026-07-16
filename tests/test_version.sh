#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-version.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-version.*)
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

git_quiet init --bare "$remote_repo" || fail "无法创建版本测试裸仓库"
git_quiet init "$source_repo" || fail "无法创建版本测试源仓库"
git -C "$source_repo" config user.name "STermux Test"
git -C "$source_repo" config user.email "stermux-test@example.invalid"
git_quiet -C "$source_repo" checkout -b release || fail "无法创建 release 分支"
printf '%s\n' '{"name":"sillytavern","version":"1.15.2"}' > "$source_repo/package.json"
printf '%s\n' 'initial' > "$source_repo/content.txt"
git_quiet -C "$source_repo" add package.json content.txt || fail "无法暂存初始版本"
git_quiet -C "$source_repo" commit -m "version 1.15.2" || fail "无法提交初始版本"
git_quiet -C "$source_repo" remote add origin "$remote_repo" || fail "无法添加远程仓库"
git_quiet -C "$source_repo" push -u origin release || fail "无法推送初始版本"
git_quiet clone -b release "$remote_repo" "$local_repo" || fail "无法克隆版本测试仓库"

STERMUX_ROOT="$TEST_TMP_ROOT/stermux"
ST_PATH="$local_repo"
GIT_NETWORK_TIMEOUT_SECONDS=10
source "$PROJECT_ROOT/core/git.sh"
source "$PROJECT_ROOT/core/ui.sh"
source "$PROJECT_ROOT/modules/sillytavern/update.sh"
ui_initialize

[[ "$(sillytavern_read_local_version)" == "1.15.2" ]] || fail "本地版本读取失败"
sillytavern_update_refresh || fail "初始远程版本读取失败：$ST_UPDATE_ERROR"
[[ "$ST_UPDATE_LOCAL_VERSION" == "1.15.2" ]] || fail "状态中的本地版本错误"
[[ "$ST_UPDATE_REMOTE_VERSION" == "1.15.2" ]] || fail "状态中的远程版本错误"
[[ "$ST_UPDATE_STATUS" == "latest" ]] || fail "初始 Git 状态应为 latest"

printf '%s\n' '{"name":"sillytavern","version":"1.18.0"}' > "$source_repo/package.json"
git_quiet -C "$source_repo" add package.json || fail "无法暂存远程版本变化"
git_quiet -C "$source_repo" commit -m "version 1.18.0" || fail "无法提交远程版本变化"
git_quiet -C "$source_repo" push || fail "无法推送远程版本变化"

worktree_before="$(git -C "$local_repo" status --porcelain)"
sillytavern_update_refresh || fail "不同版本检查失败：$ST_UPDATE_ERROR"
worktree_after="$(git -C "$local_repo" status --porcelain)"
[[ "$ST_UPDATE_LOCAL_VERSION" == "1.15.2" ]] || fail "更新前本地版本被错误改变"
[[ "$ST_UPDATE_REMOTE_VERSION" == "1.18.0" ]] || fail "未读取 upstream package.json 版本"
[[ "$ST_UPDATE_STATUS" == "update_available" ]] || fail "版本不同时未检测到 Git 更新"
[[ "$worktree_before" == "$worktree_after" ]] || fail "读取远程版本改变了工作区"
status_output="$(sillytavern_update_show_status)"
[[ "$status_output" == *"当前版本：1.15.2"* ]] || fail "状态界面缺少当前版本"
[[ "$status_output" == *"最新版本：1.18.0"* ]] || fail "状态界面缺少最新版本"
[[ "$status_output" == *"更新状态：可更新"* ]] || fail "状态界面缺少简化更新状态"
[[ "$status_output" != *"当前分支"* ]] || fail "默认状态界面不应显示当前分支"
[[ "$status_output" != *"Commit"* ]] || fail "默认状态界面不应显示 Commit"
[[ "$status_output" != *"Upstream"* ]] || fail "默认状态界面不应显示 Upstream"
[[ "$status_output" != *"领先"* && "$status_output" != *"落后"* ]] || fail "默认状态界面不应显示 ahead/behind 数量"
technical_output="$(sillytavern_update_show_technical_details)"
[[ "$technical_output" == *"当前分支：release"* ]] || fail "技术详情缺少当前分支"
[[ "$technical_output" == *"当前 Commit："* ]] || fail "技术详情缺少当前 Commit"
[[ "$technical_output" == *"Upstream：origin/release"* ]] || fail "技术详情缺少 Upstream"
[[ "$technical_output" == *"ahead / behind：领先 0 个 Commit，落后 1 个 Commit"* ]] || fail "技术详情缺少 ahead/behind 状态"

history_file="$(sillytavern_update_history_file)"
mkdir -p -- "$(dirname -- "$history_file")"
printf '%s\n' \
    $'time\tbefore\tafter\tbranch\tresult\terror' \
    $'2026-01-01 00:00:00 +0000\taaaaaaaaaaaa\tbbbbbbbbbbbb\trelease\tsuccess\t' \
    > "$history_file"

sillytavern_update_execute || fail "版本更新执行失败：$ST_UPDATE_ERROR"
[[ "$ST_UPDATE_LAST_BEFORE_VERSION" == "1.15.2" ]] || fail "未保存更新前版本"
[[ "$ST_UPDATE_LAST_AFTER_VERSION" == "1.18.0" ]] || fail "未保存更新后版本"
[[ "$ST_UPDATE_LOCAL_VERSION" == "1.18.0" ]] || fail "更新后当前版本错误"
transition_output="$(sillytavern_update_show_transition)"
[[ "$transition_output" == *"版本：1.15.2 → 1.18.0"* ]] || fail "更新结果缺少版本变化"
[[ "$transition_output" != *"Commit"* ]] || fail "普通更新结果不应显示 Commit"
head -n 1 "$history_file" | grep -Fq $'format\ttime\tbefore_version' || fail "旧历史表头未迁移"
grep -Fq $'2026-01-01 00:00:00 +0000\taaaaaaaaaaaa' "$history_file" || fail "旧历史记录未保留"
grep -Fq $'v2\t' "$history_file" || fail "未写入 v2 更新历史"
grep -Fq $'\t1.15.2\t1.18.0\t' "$history_file" || fail "更新历史缺少版本变化"
history_output="$(sillytavern_update_show_history)"
[[ "$history_output" == *"1.15.2 → 1.18.0"* ]] || fail "历史界面未优先显示版本变化"
[[ "$history_output" != *"Commit"* ]] || fail "默认历史界面不应显示 Commit"
[[ "$history_output" != *"release"* ]] || fail "默认历史界面不应显示分支"

printf '%s\n' 'new commit, same version' > "$source_repo/same-version.txt"
git_quiet -C "$source_repo" add same-version.txt || fail "无法暂存同版本新 Commit"
git_quiet -C "$source_repo" commit -m "same version new commit" || fail "无法提交同版本新 Commit"
git_quiet -C "$source_repo" push || fail "无法推送同版本新 Commit"

sillytavern_update_refresh || fail "同版本新 Commit 检查失败：$ST_UPDATE_ERROR"
[[ "$ST_UPDATE_LOCAL_VERSION" == "1.18.0" ]] || fail "同版本场景本地版本错误"
[[ "$ST_UPDATE_REMOTE_VERSION" == "1.18.0" ]] || fail "同版本场景远程版本错误"
[[ "$ST_UPDATE_STATUS" == "update_available" ]] || fail "版本相同但有新 Commit 时未提示更新"
(( ST_UPDATE_BEHIND > 0 )) || fail "版本相同时未保留 behind Commit 判断"

rm -f -- "$local_repo/package.json"
sillytavern_update_refresh || fail "本地 package.json 缺失阻止了 Git 检查"
[[ "$ST_UPDATE_LOCAL_VERSION" == "unknown" ]] || fail "本地 package.json 缺失时未显示 unknown"
[[ "$ST_UPDATE_STATUS" == "update_available" ]] || fail "本地版本未知改变了 Git 更新判断"
git_quiet -C "$local_repo" restore package.json || fail "无法恢复本地 package.json"

printf '%s\n' '{"name":"sillytavern","version":42}' > "$local_repo/package.json"
[[ "$(sillytavern_read_local_version)" == "unknown" ]] || fail "异常本地 version 字段未返回 unknown"
git_quiet -C "$local_repo" restore package.json || fail "无法再次恢复本地 package.json"

git_quiet -C "$source_repo" rm package.json || fail "无法删除远程 package.json"
git_quiet -C "$source_repo" commit -m "remove package json" || fail "无法提交远程 package.json 缺失场景"
git_quiet -C "$source_repo" push || fail "无法推送远程 package.json 缺失场景"
sillytavern_update_refresh || fail "远程 package.json 缺失阻止了 Git 检查"
[[ "$ST_UPDATE_REMOTE_VERSION" == "unknown" ]] || fail "远程 package.json 缺失时未显示 unknown"
[[ "$ST_UPDATE_STATUS" == "update_available" ]] || fail "远程版本未知改变了 Git 更新判断"

printf '%s\n' '{"name":"sillytavern","version":"not-semver"}' > "$source_repo/package.json"
git_quiet -C "$source_repo" add package.json || fail "无法暂存异常远程 version"
git_quiet -C "$source_repo" commit -m "invalid package version" || fail "无法提交异常远程 version"
git_quiet -C "$source_repo" push || fail "无法推送异常远程 version"
sillytavern_update_refresh || fail "异常远程 version 阻止了 Git 检查"
[[ "$ST_UPDATE_REMOTE_VERSION" == "unknown" ]] || fail "异常远程 version 未返回 unknown"
[[ "$ST_UPDATE_STATUS" == "update_available" ]] || fail "异常远程 version 改变了 Git 更新判断"

printf '%s\n' 'PASS: 本地/远程版本、同版本 Commit、异常降级和历史版本测试通过'
