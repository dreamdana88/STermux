#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-rollback.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-rollback.*) rm -rf -- "$TEST_TMP_ROOT" ;;
        *) printf '拒绝清理非测试目录：%s\n' "$TEST_TMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
git_quiet() { git "$@" >/dev/null 2>&1; }

remote_repo="$TEST_TMP_ROOT/remote.git"
source_repo="$TEST_TMP_ROOT/source"
local_repo="$TEST_TMP_ROOT/local"

git_quiet init --bare "$remote_repo" || fail "无法创建回退测试裸仓库"
git_quiet init "$source_repo" || fail "无法创建回退测试源仓库"
git -C "$source_repo" config user.name "STermux Test"
git -C "$source_repo" config user.email "stermux-test@example.invalid"
git_quiet -C "$source_repo" checkout -b release || fail "无法创建 release 分支"

printf '%s\n' '#!/usr/bin/env bash' > "$source_repo/start.sh"
printf '%s\n' '// server fixture' > "$source_repo/server.js"

commit_version() {
    local version="$1"
    printf '{"name":"sillytavern","version":"%s"}\n' "$version" > "$source_repo/package.json"
    printf 'program=%s\n' "$version" > "$source_repo/program.txt"
    git_quiet -C "$source_repo" add start.sh server.js package.json program.txt \
        || fail "无法暂存版本 $version"
    git_quiet -C "$source_repo" commit -m "version $version" || fail "无法提交版本 $version"
    git_quiet -C "$source_repo" tag "$version" || fail "无法创建 tag $version"
}

commit_version 1.15.0
commit_version 1.16.0
git_quiet -C "$source_repo" tag v1.16.0 || fail "无法创建无效 v 前缀 tag"
commit_version 1.17.0
git_quiet -C "$source_repo" tag 1.17.0-beta || fail "无法创建测试版 tag"
commit_version 1.18.0
git_quiet -C "$source_repo" tag 1.14.0 || fail "无法创建版本不匹配 tag"
git_quiet -C "$source_repo" tag invalid-tag || fail "无法创建无效 tag"
git_quiet -C "$source_repo" push -u "$remote_repo" release --tags || fail "无法推送版本 Fixture"
git_quiet clone -b release "$remote_repo" "$local_repo" || fail "无法克隆回退测试仓库"

mkdir -p -- "$local_repo/data/default-user/chats" \
    "$local_repo/public/scripts/extensions/third-party/TestExtension" || fail "无法创建用户数据 Fixture"
printf '%s\n' 'user chat must survive' > "$local_repo/data/default-user/chats/chat.txt"
printf '%s\n' 'dataRoot: ./data' > "$local_repo/config.yaml"
printf '%s\n' 'extension data must survive' \
    > "$local_repo/public/scripts/extensions/third-party/TestExtension/settings.json"

STERMUX_ROOT="$TEST_TMP_ROOT/stermux"
ST_PATH="$local_repo"
GIT_NETWORK_TIMEOUT_SECONDS=10
BACKUP_LAST_ERROR=""
BACKUP_LAST_PATH=""
BACKUP_CALLED=0
BACKUP_SHOULD_FAIL=false
SYNC_CALLED=0
SYNC_SHOULD_FAIL=false

source "$PROJECT_ROOT/core/utils.sh"
source "$PROJECT_ROOT/core/ui.sh"
source "$PROJECT_ROOT/core/git.sh"
source "$PROJECT_ROOT/modules/sillytavern/update.sh"
source "$PROJECT_ROOT/modules/sillytavern/rollback.sh"
ui_initialize

if ! sillytavern_rollback_remote_is_official 'https://github.com/SillyTavern/SillyTavern.git'; then
    fail "官方 HTTPS remote 未被识别"
fi
if sillytavern_rollback_remote_is_official 'https://example.invalid/github-proxy/SillyTavern'; then
    fail "第三方代理 URL 被错误识别为官方 remote"
fi
real_official_remote_definition="$(declare -f sillytavern_rollback_remote_is_official)"
sillytavern_rollback_remote_is_official() { return 0; }
sillytavern_rollback_dependencies_are_ready() { return 0; }
sillytavern_rollback_sync_dependencies() {
    SYNC_CALLED=$((SYNC_CALLED + 1))
    [[ "$SYNC_SHOULD_FAIL" != true ]]
}
backup_create() {
    local type="$1" reason="$2"
    BACKUP_CALLED=$((BACKUP_CALLED + 1))
    [[ "$type" == protective ]] || { BACKUP_LAST_ERROR="wrong backup type"; return 1; }
    [[ "$reason" == before-sillytavern-rollback:* ]] \
        || { BACKUP_LAST_ERROR="wrong backup reason"; return 1; }
    if [[ "$BACKUP_SHOULD_FAIL" == true ]]; then
        BACKUP_LAST_ERROR="mock protective backup failure"
        return 1
    fi
    BACKUP_LAST_PATH="$TEST_TMP_ROOT/backups/mock-protective"
    return 0
}

sillytavern_rollback_refresh_versions || fail "无法列出回退版本：$ST_ROLLBACK_ERROR"
[[ ${#ST_ROLLBACK_VERSIONS[@]} -eq 3 ]] || fail "有效回退版本数量错误"
[[ "${ST_ROLLBACK_VERSIONS[*]}" == "1.17.0 1.16.0 1.15.0" ]] \
    || fail "正式版本未按语义版本倒序显示：${ST_ROLLBACK_VERSIONS[*]}"
[[ " ${ST_ROLLBACK_VERSIONS[*]} " != *" 1.18.0 "* ]] || fail "当前版本出现在回退列表"
[[ " ${ST_ROLLBACK_TAGS[*]} " != *" v1.16.0 "* \
    && " ${ST_ROLLBACK_TAGS[*]} " != *" 1.17.0-beta "* \
    && " ${ST_ROLLBACK_TAGS[*]} " != *" 1.14.0 "* ]] || fail "无效或版本不匹配 tag 未过滤"

real_fetch_tags_definition="$(declare -f git_fetch_tags)"
git_fetch_tags() { GIT_LAST_ERROR="mock offline"; return 1; }
sillytavern_rollback_refresh_versions || fail "网络失败时没有回退到本地 tag"
[[ "$ST_ROLLBACK_FETCH_STATUS" == failed && ${#ST_ROLLBACK_VERSIONS[@]} -eq 3 ]] \
    || fail "网络失败本地 tag 降级状态错误"
eval "$real_fetch_tags_definition"

BACKUP_CALLED=0
cancel_output="$TEST_TMP_ROOT/cancel-output.txt"
sillytavern_rollback_interactive <<< $'1\n\n' > "$cancel_output" 2>&1 \
    || fail "用户取消回退不应报错"
grep -Fq '已取消版本回退' "$cancel_output" || fail "默认 N 未取消回退"
(( BACKUP_CALLED == 0 )) || fail "用户取消后仍创建了保护备份"
[[ "$(sillytavern_read_local_version)" == 1.18.0 ]] || fail "用户取消后版本发生变化"

if sillytavern_rollback_interactive <<< $'999\n' >/dev/null 2>&1; then
    fail "非法编号被接受"
fi
if sillytavern_rollback_interactive <<< $'08\n' >/dev/null 2>&1; then
    fail "带前导零的非法编号被接受"
fi
(( BACKUP_CALLED == 0 )) || fail "非法编号触发了保护备份"

sillytavern_rollback_refresh_versions || fail "目标验证前刷新失败"
if sillytavern_rollback_target_is_valid 1.17.0 1.17.0 deadbeef; then
    fail "伪造目标 Commit 通过验证"
fi

target_version="${ST_ROLLBACK_VERSIONS[0]}"
target_tag="${ST_ROLLBACK_TAGS[0]}"
target_commit="${ST_ROLLBACK_COMMITS[0]}"
printf '%s\n' '// local tracked edit' > "$local_repo/server.js"
if sillytavern_rollback_execute "$target_version" "$target_tag" "$target_commit"; then
    fail "tracked 文件修改时仍执行回退"
fi
[[ "$ST_ROLLBACK_ERROR" == *"tracked"* ]] || fail "tracked 修改拒绝原因不明确"
(( BACKUP_CALLED == 0 )) || fail "tracked 修改拒绝前错误创建保护备份"
git_quiet -C "$local_repo" restore server.js || fail "无法恢复 tracked Fixture"

git_quiet -C "$local_repo" checkout --detach || fail "无法创建 detached HEAD Fixture"
if sillytavern_rollback_refresh_versions; then fail "detached HEAD 仍生成回退列表"; fi
[[ "$ST_ROLLBACK_ERROR" == *"detached HEAD"* ]] || fail "detached HEAD 错误不明确"
git_quiet -C "$local_repo" checkout release || fail "无法恢复 release 分支"

git_quiet -C "$local_repo" branch --unset-upstream || fail "无法创建无 upstream Fixture"
if sillytavern_rollback_refresh_versions; then fail "无 upstream 时仍生成回退列表"; fi
[[ "$ST_ROLLBACK_ERROR" == *"没有 upstream"* ]] || fail "无 upstream 错误不明确"
git_quiet -C "$local_repo" branch --set-upstream-to=origin/release release \
    || fail "无法恢复 upstream"

printf '%s\n' 'local rollback divergence' > "$local_repo/local-divergence.txt"
git_quiet -C "$local_repo" add local-divergence.txt || fail "无法暂存本地分叉 Commit"
git_quiet -C "$local_repo" commit -m 'local rollback divergence' || fail "无法提交本地分叉 Commit"
printf '%s\n' 'remote rollback divergence' > "$source_repo/remote-divergence.txt"
git_quiet -C "$source_repo" add remote-divergence.txt || fail "无法暂存远程分叉 Commit"
git_quiet -C "$source_repo" commit -m 'remote rollback divergence' || fail "无法提交远程分叉 Commit"
git_quiet -C "$source_repo" push || fail "无法推送远程分叉 Commit"
if sillytavern_rollback_refresh_versions; then fail "分叉状态仍生成回退列表"; fi
[[ "$ST_ROLLBACK_ERROR" == *"本地 Commit"* || "$ST_ROLLBACK_ERROR" == *"分叉"* ]] \
    || fail "分叉拒绝原因不明确"
git_quiet -C "$local_repo" fetch origin || fail "无法刷新分叉恢复目标"
git_quiet -C "$local_repo" reset --hard origin/release || fail "无法恢复分叉 Fixture"

sillytavern_rollback_refresh_versions || fail "保护备份失败测试刷新失败"
target_version="${ST_ROLLBACK_VERSIONS[0]}"
target_tag="${ST_ROLLBACK_TAGS[0]}"
target_commit="${ST_ROLLBACK_COMMITS[0]}"
before_commit="$(git_current_commit "$local_repo")"
BACKUP_SHOULD_FAIL=true
if sillytavern_rollback_execute "$target_version" "$target_tag" "$target_commit"; then
    fail "保护备份失败后仍执行回退"
fi
[[ "$(git_current_commit "$local_repo")" == "$before_commit" ]] || fail "保护备份失败后 Git 状态变化"
[[ "$ST_ROLLBACK_LAST_GIT_RESULT" == not_run ]] || fail "保护备份失败后执行了 Git"
BACKUP_SHOULD_FAIL=false

sillytavern_rollback_refresh_versions || fail "正常回退前刷新失败"
target_version="${ST_ROLLBACK_VERSIONS[0]}"
target_tag="${ST_ROLLBACK_TAGS[0]}"
target_commit="${ST_ROLLBACK_COMMITS[0]}"
BACKUP_CALLED=0
SYNC_CALLED=0
sillytavern_rollback_execute "$target_version" "$target_tag" "$target_commit" \
    || fail "正常回退失败：$ST_ROLLBACK_ERROR"
[[ "$(sillytavern_read_local_version)" == 1.17.0 ]] || fail "回退后 package.json 版本错误"
[[ "$(git_current_branch "$local_repo")" == release ]] || fail "回退后进入 detached HEAD"
[[ "$(git_current_upstream "$local_repo")" == origin/release ]] || fail "回退后 upstream 丢失"
(( BACKUP_CALLED == 1 && SYNC_CALLED == 1 )) || fail "保护备份或依赖同步未执行一次"
[[ -f "$local_repo/data/default-user/chats/chat.txt" \
    && -f "$local_repo/public/scripts/extensions/third-party/TestExtension/settings.json" ]] \
    || fail "Git 回退误删用户数据或扩展数据"

sillytavern_update_refresh || fail "回退后更新检查失败：$ST_UPDATE_ERROR"
[[ "$ST_UPDATE_STATUS" == update_available ]] || fail "回退后未识别可重新升级"
sillytavern_update_execute || fail "回退后重新升级失败：$ST_UPDATE_ERROR"
[[ "$(sillytavern_read_local_version)" == 1.18.0 ]] || fail "重新升级后版本错误"
[[ "$(git_current_branch "$local_repo")" == release \
    && "$(git_current_upstream "$local_repo")" == origin/release ]] \
    || fail "重新升级后分支或 upstream 异常"

sillytavern_rollback_refresh_versions || fail "依赖失败测试刷新失败"
target_version="${ST_ROLLBACK_VERSIONS[0]}"
target_tag="${ST_ROLLBACK_TAGS[0]}"
target_commit="${ST_ROLLBACK_COMMITS[0]}"
before_commit="$(git_current_commit "$local_repo")"
SYNC_SHOULD_FAIL=true
if sillytavern_rollback_execute "$target_version" "$target_tag" "$target_commit"; then
    fail "依赖同步失败被报告为成功"
fi
[[ "$ST_ROLLBACK_LAST_DEPENDENCY_RESULT" == failed ]] || fail "依赖失败状态未记录"
[[ "$ST_ROLLBACK_LAST_GIT_RESULT" == restored ]] || fail "依赖失败后未恢复原 Commit"
[[ "$(git_current_commit "$local_repo")" == "$before_commit" \
    && "$(sillytavern_read_local_version)" == 1.18.0 ]] || fail "依赖失败后代码未恢复"
SYNC_SHOULD_FAIL=false

sillytavern_rollback_refresh_versions || fail "Git 失败测试刷新失败"
target_version="${ST_ROLLBACK_VERSIONS[0]}"
target_tag="${ST_ROLLBACK_TAGS[0]}"
target_commit="${ST_ROLLBACK_COMMITS[0]}"
before_commit="$(git_current_commit "$local_repo")"
real_reset_definition="$(declare -f git_reset_hard_to_commit)"
git_reset_hard_to_commit() { GIT_LAST_ERROR="mock reset failure"; return 1; }
if sillytavern_rollback_execute "$target_version" "$target_tag" "$target_commit"; then
    fail "Git reset 失败被报告为成功"
fi
[[ "$ST_ROLLBACK_LAST_GIT_RESULT" == failed ]] || fail "Git 失败结果未记录"
[[ "$(git_current_commit "$local_repo")" == "$before_commit" ]] || fail "Git 失败后 HEAD 变化"
eval "$real_reset_definition"

eval "$real_official_remote_definition"
sillytavern_rollback_refresh_versions || fail "非官方 remote 时本地 tag 不可用"
[[ "$ST_ROLLBACK_FETCH_STATUS" == skipped_non_official ]] \
    || fail "非官方 remote 未跳过联网 tag 刷新"

rollback_log="$(sillytavern_rollback_log_file)"
[[ -s "$rollback_log" ]] || fail "未生成回退日志"
grep -Fq $'\t1.18.0\t' "$rollback_log" || fail "回退日志缺少原版本"
grep -Fq $'\t1.17.0\t' "$rollback_log" || fail "回退日志缺少目标版本"
grep -Fq $'\tsuccess\tsuccess\tsuccess\t' "$rollback_log" \
    || fail "回退日志缺少备份、Git 与依赖成功结果"
if rg -n 'GITHUB_PROXY|github.*proxy|mirror' "$PROJECT_ROOT/modules/sillytavern/rollback.sh" >/dev/null 2>&1; then
    fail "回退实现包含第三方 GitHub 代理逻辑"
fi

printf '%s\n' 'PASS: Phase 6 正式 tag、保护备份、安全回退、失败恢复及重新升级测试通过'
