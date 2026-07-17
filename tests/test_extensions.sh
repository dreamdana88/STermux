#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-extensions.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-extensions.*) rm -rf -- "$TEST_TMP_ROOT" ;;
        *) printf '拒绝清理非测试目录：%s\n' "$TEST_TMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
git_quiet() { git "$@" >/dev/null 2>&1; }

create_git_extension() {
    local fixture_id="$1"
    local extension_name="$2"
    local remote="$TEST_TMP_ROOT/remotes/$fixture_id.git"
    local source_repo="$TEST_TMP_ROOT/sources/$fixture_id"
    local target="$EXTENSIONS_ROOT/$extension_name"

    mkdir -p -- "$TEST_TMP_ROOT/remotes" "$TEST_TMP_ROOT/sources" || return 1
    git_quiet init --bare "$remote" || return 1
    git_quiet init "$source_repo" || return 1
    git -C "$source_repo" config user.name "STermux Test"
    git -C "$source_repo" config user.email "stermux-test@example.invalid"
    git_quiet -C "$source_repo" checkout -b release || return 1
    printf '%s\n' 'version=1' > "$source_repo/version.txt"
    git_quiet -C "$source_repo" add version.txt || return 1
    git_quiet -C "$source_repo" commit -m "initial" || return 1
    git_quiet -C "$source_repo" remote add origin "$remote" || return 1
    git_quiet -C "$source_repo" push -u origin release || return 1
    git_quiet clone -b release "$remote" "$target" || return 1
    git -C "$target" config user.name "STermux Test"
    git -C "$target" config user.email "stermux-test@example.invalid"
    LAST_EXTENSION_SOURCE="$source_repo"
    LAST_EXTENSION_PATH="$target"
}

push_extension_update() {
    local source_repo="$1"
    local value="$2"

    printf '%s\n' "$value" > "$source_repo/version.txt" || return 1
    git_quiet -C "$source_repo" add version.txt || return 1
    git_quiet -C "$source_repo" commit -m "$value" || return 1
    git_quiet -C "$source_repo" push || return 1
}

extension_index_by_name() {
    local wanted="$1"
    local index

    for ((index = 0; index < ${#EXTENSION_NAMES[@]}; index++)); do
        if [[ "${EXTENSION_NAMES[index]}" == "$wanted" ]]; then
            printf '%s\n' "$index"
            return 0
        fi
    done
    return 1
}

STERMUX_ROOT="$TEST_TMP_ROOT/stermux"
ST_PATH="$TEST_TMP_ROOT/Silly Tavern 测试"
EXTENSIONS_ROOT="$ST_PATH/public/scripts/extensions/third-party"
mkdir -p -- "$STERMUX_ROOT/config" "$EXTENSIONS_ROOT" || exit 1
printf '%s\n' '# test policy file' 'ManualExt=manual' > \
    "$STERMUX_ROOT/config/extension-policy.conf"

create_git_extension "latest" "LatestExt" || fail "无法创建最新扩展 Fixture"
LATEST_PATH="$LAST_EXTENSION_PATH"
create_git_extension "auto" "自动 扩展" || fail "无法创建自动更新扩展 Fixture"
AUTO_SOURCE="$LAST_EXTENSION_SOURCE"
AUTO_PATH="$LAST_EXTENSION_PATH"
push_extension_update "$AUTO_SOURCE" "version=2-auto" || fail "无法创建自动扩展远程更新"
create_git_extension "manual" "ManualExt" || fail "无法创建仅手动扩展 Fixture"
MANUAL_SOURCE="$LAST_EXTENSION_SOURCE"
MANUAL_PATH="$LAST_EXTENSION_PATH"
push_extension_update "$MANUAL_SOURCE" "version=2-manual" || fail "无法创建手动扩展远程更新"
create_git_extension "failure" "A-Failure" || fail "无法创建失败扩展 Fixture"
FAILURE_SOURCE="$LAST_EXTENSION_SOURCE"
FAILURE_PATH="$LAST_EXTENSION_PATH"
push_extension_update "$FAILURE_SOURCE" "version=2-failure" || fail "无法创建失败扩展远程更新"
create_git_extension "bulk" "BulkSuccess" || fail "无法创建批量成功扩展 Fixture"
BULK_SOURCE="$LAST_EXTENSION_SOURCE"
BULK_PATH="$LAST_EXTENSION_PATH"
push_extension_update "$BULK_SOURCE" "version=2-bulk" || fail "无法创建批量扩展远程更新"
create_git_extension "no-upstream" "NoUpstream" || fail "无法创建无 upstream 扩展 Fixture"
NO_UPSTREAM_PATH="$LAST_EXTENSION_PATH"
git_quiet -C "$NO_UPSTREAM_PATH" branch --unset-upstream || fail "无法移除扩展 upstream"
create_git_extension "fetch-failure" "FetchFailure" || fail "无法创建 fetch 失败扩展 Fixture"
FETCH_FAILURE_PATH="$LAST_EXTENSION_PATH"
git_quiet -C "$FETCH_FAILURE_PATH" remote set-url origin \
    "$TEST_TMP_ROOT/remotes/missing.git" || fail "无法设置失效扩展远程"
mkdir -p -- "$EXTENSIONS_ROOT/NonGit/nested-extension" || fail "无法创建非 Git 扩展 Fixture"

GIT_NETWORK_TIMEOUT_SECONDS=10
source "$PROJECT_ROOT/core/utils.sh"
source "$PROJECT_ROOT/core/git.sh"
source "$PROJECT_ROOT/core/ui.sh"
source "$PROJECT_ROOT/modules/sillytavern/extensions.sh"
ui_initialize

sillytavern_extensions_scan || fail "扩展扫描失败：$EXTENSION_SCAN_ERROR"
[[ "$EXTENSION_TOTAL_COUNT" == 8 ]] || fail "一级扩展数量错误：$EXTENSION_TOTAL_COUNT"
[[ "$EXTENSION_GIT_COUNT" == 7 ]] || fail "Git 扩展数量错误：$EXTENSION_GIT_COUNT"
[[ "$EXTENSION_NON_GIT_COUNT" == 1 ]] || fail "非 Git 扩展数量错误：$EXTENSION_NON_GIT_COUNT"

latest_index="$(extension_index_by_name "LatestExt")" || fail "未扫描 LatestExt"
auto_index="$(extension_index_by_name "自动 扩展")" || fail "未扫描中文空格扩展"
manual_index="$(extension_index_by_name "ManualExt")" || fail "未扫描 ManualExt"
failure_index="$(extension_index_by_name "A-Failure")" || fail "未扫描失败扩展"
bulk_index="$(extension_index_by_name "BulkSuccess")" || fail "未扫描批量扩展"
no_upstream_index="$(extension_index_by_name "NoUpstream")" || fail "未扫描无 upstream 扩展"
fetch_failure_index="$(extension_index_by_name "FetchFailure")" || fail "未扫描 fetch 失败扩展"
non_git_index="$(extension_index_by_name "NonGit")" || fail "未扫描非 Git 扩展"

sillytavern_extensions_refresh_all || fail "扩展批量检测意外失败"
[[ "${EXTENSION_STATUSES[latest_index]}" == "latest" ]] || fail "最新扩展状态错误"
[[ "${EXTENSION_STATUSES[auto_index]}" == "update_available" ]] || fail "自动扩展更新状态错误"
[[ "${EXTENSION_STATUSES[manual_index]}" == "manual_only_update_available" ]] \
    || fail "仅手动扩展更新状态错误"
[[ "${EXTENSION_STATUSES[failure_index]}" == "update_available" ]] || fail "失败 Fixture 初始状态错误"
[[ "${EXTENSION_STATUSES[bulk_index]}" == "update_available" ]] || fail "批量 Fixture 初始状态错误"
[[ "${EXTENSION_STATUSES[no_upstream_index]}" == "no_upstream" ]] || fail "无 upstream 状态错误"
[[ "${EXTENSION_STATUSES[fetch_failure_index]}" == "fetch_failed" ]] || fail "fetch 失败状态错误"
[[ "${EXTENSION_STATUSES[non_git_index]}" == "not_git" ]] || fail "非 Git 状态错误"
[[ "$EXTENSION_UPDATE_COUNT" == 3 ]] || fail "自动可更新数量错误：$EXTENSION_UPDATE_COUNT"
[[ "$EXTENSION_MANUAL_UPDATE_COUNT" == 1 ]] || fail "仅手动可更新数量错误"
[[ "$EXTENSION_FAILED_COUNT" == 2 ]] || fail "检测失败数量错误"

list_output="$(sillytavern_extensions_show_list 2>&1)"
[[ "$list_output" == *"自动 扩展 — 可更新 1 个 Commit"* ]] || fail "列表缺少可更新状态"
[[ "$list_output" == *"ManualExt — 可更新 1 个 Commit，仅手动"* ]] || fail "列表缺少手动状态"
[[ "$list_output" == *"NonGit — 非 Git 安装"* ]] || fail "列表缺少非 Git 扩展"
details_output="$(sillytavern_extension_show_details "$manual_index")"
[[ "$details_output" == *"策略：manual"* ]] || fail "扩展详情缺少更新策略"
[[ "$details_output" == *"Upstream：origin/release"* ]] || fail "扩展详情缺少 upstream"
[[ "$details_output" == *"ahead / behind：领先 0，落后 1"* ]] || fail "扩展详情缺少 Commit 差异"

selection_input="$((auto_index + 1)),$((manual_index + 1)) $((auto_index + 1)) invalid 999"
sillytavern_extension_parse_selection "$selection_input" || fail "多选解析失败"
[[ "${#EXTENSION_SELECTED_INDEXES[@]}" == 2 ]] || fail "多选未正确过滤和去重"
[[ "${EXTENSION_SELECTED_INDEXES[0]}" == "$auto_index" ]] || fail "多选顺序错误"
[[ "${EXTENSION_SELECTED_INDEXES[1]}" == "$manual_index" ]] || fail "多选第二项错误"

sillytavern_extension_policy_set "自动 扩展" manual || fail "中文空格策略保存失败"
[[ "$(sillytavern_extension_policy_get "自动 扩展")" == "manual" ]] || fail "手动策略读取失败"
grep -Fq '# test policy file' "$STERMUX_ROOT/config/extension-policy.conf" \
    || fail "保存策略时丢失原有注释"
sillytavern_extension_policy_set "自动 扩展" auto || fail "取消手动策略失败"
[[ "$(sillytavern_extension_policy_get "自动 扩展")" == "auto" ]] || fail "默认 auto 策略恢复失败"
if sillytavern_extension_policy_set "bad=name" manual; then fail "含等号的不安全扩展名意外写入策略"; fi

git_pull_rebase_autostash() {
    local repository="$1"
    if [[ "$repository" == "$FAILURE_PATH" ]]; then
        GIT_LAST_ERROR="simulated extension pull failure"
        return 1
    fi
    git_run_network_command "$repository" pull --rebase --autostash
}

sillytavern_extension_batch_update explicit "$failure_index" "$auto_index"
[[ "$EXTENSION_BATCH_SUCCESS" == 1 ]] || fail "单项失败后成功扩展未继续更新"
[[ "$EXTENSION_BATCH_FAILED" == 1 ]] || fail "模拟 pull 失败未计入失败"
[[ "$(< "$AUTO_PATH/version.txt")" == "version=2-auto" ]] || fail "失败隔离后的扩展未更新"
[[ "$(< "$FAILURE_PATH/version.txt")" == "version=1" ]] || fail "失败扩展工作区被意外更新"

sillytavern_extension_batch_update auto "$manual_index" "$bulk_index" "$non_git_index"
[[ "$EXTENSION_BATCH_SUCCESS" == 1 ]] || fail "批量自动更新成功数量错误"
[[ "$EXTENSION_BATCH_FAILED" == 0 ]] || fail "批量自动更新意外失败"
[[ "$EXTENSION_BATCH_SKIPPED" == 2 ]] || fail "手动与非 Git 扩展未被正确跳过"
[[ "$(< "$BULK_PATH/version.txt")" == "version=2-bulk" ]] || fail "允许自动更新的扩展未更新"
[[ "$(< "$MANUAL_PATH/version.txt")" == "version=1" ]] || fail "仅手动扩展被批量更新"

sillytavern_extension_batch_update explicit "$manual_index"
[[ "$EXTENSION_BATCH_SUCCESS" == 1 ]] || fail "用户主动选择时无法更新仅手动扩展"
[[ "$(< "$MANUAL_PATH/version.txt")" == "version=2-manual" ]] || fail "仅手动扩展主动更新失败"

log_file="$(sillytavern_extension_log_file)"
[[ -s "$log_file" ]] || fail "扩展更新未写入日志"
grep -Fq $'A-Failure\t' "$log_file" || fail "扩展失败日志缺少名称"
grep -Fq $'success\t-' "$log_file" || fail "扩展成功日志缺少结果"

create_git_extension "delete-git" "DeleteGit" || fail "无法创建待删除 Git 扩展"
DELETE_GIT_PATH="$LAST_EXTENSION_PATH"
mkdir -p -- "$EXTENSIONS_ROOT/DeleteNonGit" "$EXTENSIONS_ROOT/DeleteFailure" \
    "$EXTENSIONS_ROOT/DeleteAfterFailure" || fail "无法创建扩展删除 Fixture"
printf '%s\n' delete > "$EXTENSIONS_ROOT/DeleteNonGit/index.js"
printf '%s\n' keep > "$EXTENSIONS_ROOT/DeleteFailure/index.js"
printf '%s\n' delete > "$EXTENSIONS_ROOT/DeleteAfterFailure/index.js"
sillytavern_extension_policy_set DeleteGit manual || fail "无法准备待清理 manual 策略"
sillytavern_extensions_scan || fail "扩展删除前扫描失败"

delete_git_index="$(extension_index_by_name DeleteGit)" || fail "无法定位待删除 Git 扩展"
cancel_output="$(printf '%s\n\n' "$((delete_git_index + 1))" | \
    sillytavern_extension_delete_interactive 2>&1)"
[[ "$cancel_output" == *"已取消扩展删除"* ]] || fail "扩展删除默认 N 未取消"
[[ -d "$DELETE_GIT_PATH" ]] || fail "取消后 Git 扩展仍被删除"

sillytavern_extension_delete_selected "$delete_git_index"
[[ "$EXTENSION_DELETE_SUCCESS" == 1 && "$EXTENSION_DELETE_FAILED" == 0 ]] \
    || fail "单个 Git 扩展删除结果错误"
[[ ! -e "$DELETE_GIT_PATH" ]] || fail "单个 Git 扩展未删除"
[[ "$(sillytavern_extension_policy_get DeleteGit)" == auto ]] \
    || fail "扩展删除后 manual 策略未同步清理"

sillytavern_extensions_scan || fail "非 Git 删除前扫描失败"
delete_non_git_index="$(extension_index_by_name DeleteNonGit)" || fail "无法定位待删除非 Git 扩展"
sillytavern_extension_delete_selected "$delete_non_git_index"
[[ ! -e "$EXTENSIONS_ROOT/DeleteNonGit" ]] || fail "单个非 Git 扩展未删除"

sillytavern_extensions_scan || fail "批量删除前扫描失败"
delete_failure_index="$(extension_index_by_name DeleteFailure)" || fail "无法定位删除失败扩展"
delete_after_index="$(extension_index_by_name DeleteAfterFailure)" || fail "无法定位失败后扩展"
sillytavern_extension_parse_selection \
    "$((delete_failure_index + 1)),$((delete_after_index + 1)) $((delete_after_index + 1)) invalid 999" \
    || fail "扩展删除多选解析失败"
[[ "${#EXTENSION_SELECTED_INDEXES[@]}" == 2 ]] || fail "扩展删除多选未过滤非法编号或去重"
sillytavern_extension_remove_directory() {
    [[ "$1" == "$EXTENSIONS_ROOT/DeleteFailure" ]] && return 1
    rm -rf -- "$1"
}
sillytavern_extension_delete_selected "${EXTENSION_SELECTED_INDEXES[@]}"
[[ "$EXTENSION_DELETE_FAILED" == 1 && "$EXTENSION_DELETE_SUCCESS" == 1 ]] \
    || fail "扩展删除失败未与后续项目隔离"
[[ -d "$EXTENSIONS_ROOT/DeleteFailure" && ! -e "$EXTENSIONS_ROOT/DeleteAfterFailure" ]] \
    || fail "扩展删除失败隔离后的目录状态错误"
sillytavern_extension_remove_directory() { rm -rf -- "$1"; }

OUTSIDE_EXTENSION="$TEST_TMP_ROOT/outside-extension"
mkdir -p -- "$OUTSIDE_EXTENSION"
printf '%s\n' outside > "$OUTSIDE_EXTENSION/sentinel.txt"
sillytavern_extensions_scan || fail "越界测试前扫描失败"
safe_index="$(extension_index_by_name DeleteFailure)" || fail "无法定位越界测试扩展"
original_path="${EXTENSION_PATHS[safe_index]}"
original_name="${EXTENSION_NAMES[safe_index]}"
EXTENSION_PATHS[safe_index]="$OUTSIDE_EXTENSION"
EXTENSION_NAMES[safe_index]="$(basename -- "$OUTSIDE_EXTENSION")"
if sillytavern_extension_delete_index "$safe_index"; then fail "third-party 外扩展被允许删除"; fi
[[ -f "$OUTSIDE_EXTENSION/sentinel.txt" ]] || fail "扩展越界保护破坏外部数据"
EXTENSION_PATHS[safe_index]="$EXTENSIONS_ROOT/../$(basename -- "$OUTSIDE_EXTENSION")"
if sillytavern_extension_delete_index "$safe_index"; then fail "路径穿越目标被允许删除"; fi
[[ -f "$OUTSIDE_EXTENSION/sentinel.txt" ]] || fail "路径穿越保护破坏外部数据"
EXTENSION_PATHS[safe_index]="$EXTENSIONS_ROOT"
EXTENSION_NAMES[safe_index]="$(basename -- "$EXTENSIONS_ROOT")"
if sillytavern_extension_delete_index "$safe_index"; then fail "third-party 根目录被允许删除"; fi
[[ -d "$EXTENSIONS_ROOT" ]] || fail "third-party 根目录被破坏"
EXTENSION_PATHS[safe_index]="$original_path"
EXTENSION_NAMES[safe_index]="$original_name"

if ln -s "$OUTSIDE_EXTENSION" "$EXTENSIONS_ROOT/EscapeLink" 2>/dev/null \
    && [[ -L "$EXTENSIONS_ROOT/EscapeLink" ]]; then
    sillytavern_extensions_scan || fail "符号链接测试前扫描失败"
    escape_index="$(extension_index_by_name EscapeLink)" || fail "扫描未包含符号链接 Fixture"
    if sillytavern_extension_delete_index "$escape_index"; then fail "符号链接逃逸扩展被允许删除"; fi
    [[ -f "$OUTSIDE_EXTENSION/sentinel.txt" ]] || fail "符号链接逃逸破坏外部数据"
fi
grep -Fq $'DeleteGit\tunknown\tunknown\tdelete_success' "$log_file" \
    || fail "扩展删除成功未写入现有扩展日志"
grep -Fq $'DeleteFailure\tunknown\tunknown\tdelete_failed' "$log_file" \
    || fail "扩展删除失败未写入现有扩展日志"

ST_PATH="$TEST_TMP_ROOT/Empty SillyTavern"
sillytavern_extensions_scan || fail "扩展目录不存在时不应致命失败"
[[ "$EXTENSION_TOTAL_COUNT" == 0 ]] || fail "空扩展环境仍保留旧扫描结果"

printf '%s\n' 'PASS: 扩展扫描、更新、策略、安全删除、多选及失败隔离测试通过'
