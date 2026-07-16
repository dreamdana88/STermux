#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-backup.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-backup.*) rm -rf -- "$TEST_TMP_ROOT" ;;
        *) printf '拒绝清理非测试目录：%s\n' "$TEST_TMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

backup_index_by_id() {
    local wanted="$1" index
    for ((index = 0; index < ${#BACKUP_IDS[@]}; index++)); do
        if [[ "${BACKUP_IDS[index]}" == "$wanted" ]]; then
            printf '%s\n' "$index"
            return 0
        fi
    done
    return 1
}

automatic_count() {
    local index count=0
    backup_inventory_scan || return 1
    for ((index = 0; index < ${#BACKUP_TYPES[@]}; index++)); do
        backup_type_is_automatic "${BACKUP_TYPES[index]}" && count=$((count + 1))
    done
    printf '%s\n' "$count"
}

create_backup_at() {
    TEST_BACKUP_EPOCH="$1"
    backup_create "$2" "$3"
}

STERMUX_ROOT="$TEST_TMP_ROOT/stermux"
ST_PATH="$TEST_TMP_ROOT/Silly Tavern 中文"
BACKUP_ROOT="$STERMUX_ROOT/backups/sillytavern"
AUTOMATIC_BACKUP_KEEP=2
TEST_BACKUP_EPOCH=100
THIRD_PARTY_DIR="$ST_PATH/public/scripts/extensions/third-party"

mkdir -p -- "$STERMUX_ROOT/data/logs" "$ST_PATH/data/default-user/chats" \
    "$THIRD_PARTY_DIR/GitExtension" || exit 1
printf '%s\n' '#!/usr/bin/env bash' > "$ST_PATH/start.sh"
printf '%s\n' '// fixture' > "$ST_PATH/server.js"
printf '%s\n' '{"name":"sillytavern"}' > "$ST_PATH/package.json"
printf '%s\n' 'dataRoot: ./data' 'port: 8000' > "$ST_PATH/config.yaml"
printf '%s\n' 'original chat' > "$ST_PATH/data/default-user/chats/chat.txt"
git init -q "$THIRD_PARTY_DIR/GitExtension" || fail "无法创建 third-party Git 仓库 Fixture"
printf '%s\n' 'extension snapshot' > "$THIRD_PARTY_DIR/GitExtension/index.js"
printf '%s\n' 'hidden extension setting' > "$THIRD_PARTY_DIR/GitExtension/.hidden-setting"
printf '%s\n' 'root hidden file' > "$THIRD_PARTY_DIR/.backup-hidden"

source "$PROJECT_ROOT/core/utils.sh"
source "$PROJECT_ROOT/core/ui.sh"
source "$PROJECT_ROOT/core/git.sh"
source "$PROJECT_ROOT/modules/sillytavern/backup-rules.sh"
source "$PROJECT_ROOT/core/backup.sh"
ui_initialize

backup_current_epoch() { printf '%s\n' "$TEST_BACKUP_EPOCH"; }
backup_current_display_time() { printf 'test-time-%s\n' "$TEST_BACKUP_EPOCH"; }

create_backup_at 100 manual "manual fixture" || fail "无法创建 manual 备份：$BACKUP_LAST_ERROR"
MANUAL_PATH="$BACKUP_LAST_PATH"
MANUAL_ID="$(basename -- "$MANUAL_PATH")"
[[ -s "$MANUAL_PATH/backup.tar.gz" ]] || fail "manual 归档不存在"
[[ -s "$MANUAL_PATH/metadata.conf" ]] || fail "manual 元数据不存在"
[[ -f "$MANUAL_PATH/config.yaml" ]] || fail "manual 未保存 config.yaml"
[[ -s "$MANUAL_PATH/third-party.tar.gz" ]] || fail "manual 未保存 third-party 归档"
grep -Fxq 'BACKUP_TYPE=manual' "$MANUAL_PATH/metadata.conf" || fail "manual 类型元数据错误"
grep -Fxq 'BACKUP_THIRD_PARTY_STATUS=present' "$MANUAL_PATH/metadata.conf" \
    || fail "third-party 存在状态未写入元数据"
tar -tzf "$MANUAL_PATH/third-party.tar.gz" > "$TEST_TMP_ROOT/third-party-members.txt" \
    || fail "无法读取 third-party 归档成员"
grep -Fq './GitExtension/.git/HEAD' "$TEST_TMP_ROOT/third-party-members.txt" \
    || fail "third-party 归档未包含 Git 隐藏目录"
grep -Fq './GitExtension/.hidden-setting' "$TEST_TMP_ROOT/third-party-members.txt" \
    || fail "third-party 归档未包含扩展隐藏文件"
grep -Fq './.backup-hidden' "$TEST_TMP_ROOT/third-party-members.txt" \
    || fail "third-party 归档未包含根隐藏文件"

create_backup_at 200 protective "before update" || fail "无法创建 protective 备份"
PROTECTIVE_PATH="$BACKUP_LAST_PATH"
[[ -s "$PROTECTIVE_PATH/third-party.tar.gz" ]] || fail "protective 未使用统一 third-party 范围"
create_backup_at 300 scheduled "scheduled fixture" || fail "无法创建 scheduled 备份"
SCHEDULED_PATH="$BACKUP_LAST_PATH"
[[ -s "$SCHEDULED_PATH/third-party.tar.gz" ]] || fail "scheduled 未使用统一 third-party 范围"
create_backup_at 400 catchup "single catchup fixture" || fail "无法创建 catchup 备份"
CATCHUP_PATH="$BACKUP_LAST_PATH"
[[ -s "$CATCHUP_PATH/third-party.tar.gz" ]] || fail "catchup 未使用统一 third-party 范围"

[[ -d "$MANUAL_PATH" ]] || fail "manual 被自动轮换删除"
[[ ! -e "$PROTECTIVE_PATH" ]] || fail "自动池未删除最旧 protective"
[[ -d "$SCHEDULED_PATH" && -d "$CATCHUP_PATH" ]] || fail "自动池没有保留最新两份"
[[ "$(automatic_count)" == 2 ]] || fail "自动备份池不是最新 2 份"
if backup_delete_path "$MANUAL_PATH" automatic; then fail "自动清理路径允许删除 manual"; fi
[[ -d "$MANUAL_PATH" ]] || fail "manual 被自动清理接口删除"

list_output="$(backup_show_list 2>&1)"
[[ "$list_output" == *"test-time-400 | catchup"* ]] || fail "列表缺少创建时间或 catchup 类型"
[[ "$list_output" == *"$MANUAL_ID"* ]] || fail "列表缺少 manual 唯一标识"
[[ "$list_output" == *" B |"* || "$list_output" == *" KiB |"* || "$list_output" == *" MiB |"* ]] \
    || fail "列表缺少文件大小"

backup_inventory_scan || fail "无法扫描备份"
backup_parse_selection '1,2 1 invalid 999' || fail "安全多选解析失败"
[[ ${#BACKUP_SELECTED_INDEXES[@]} -eq 2 ]] || fail "多选未过滤非法编号或去重"

manual_index="$(backup_index_by_id "$MANUAL_ID")" || fail "无法定位 manual 备份"
cancel_output="$(printf '%s\n\n' "$((manual_index + 1))" | backup_delete_interactive false 2>&1)"
[[ "$cancel_output" == *"已取消删除"* ]] || fail "默认 N 未取消删除"
[[ -d "$MANUAL_PATH" ]] || fail "取消后 manual 仍被删除"

create_backup_at 500 manual "single manual deletion" || fail "无法创建单删 manual Fixture"
DELETE_MANUAL_PATH="$BACKUP_LAST_PATH"
DELETE_MANUAL_ID="$(basename -- "$DELETE_MANUAL_PATH")"
backup_inventory_scan || fail "单删前扫描失败"
delete_manual_index="$(backup_index_by_id "$DELETE_MANUAL_ID")" || fail "无法定位单删 manual"
printf '%s\ny\n' "$((delete_manual_index + 1))" | backup_delete_interactive false >/dev/null \
    || fail "单个 manual 删除流程失败"
[[ ! -e "$DELETE_MANUAL_PATH" ]] || fail "用户确认后未删除 manual"

backup_inventory_scan || fail "单删自动备份前扫描失败"
scheduled_id="$(basename -- "$SCHEDULED_PATH")"
scheduled_index="$(backup_index_by_id "$scheduled_id")" || fail "无法定位 scheduled"
printf '%s\ny\n' "$((scheduled_index + 1))" | backup_delete_interactive false >/dev/null \
    || fail "单个 automatic 删除流程失败"
[[ ! -e "$SCHEDULED_PATH" ]] || fail "用户确认后未删除 automatic"

create_backup_at 600 manual "batch one" || fail "无法创建批量 Fixture 1"
BATCH_ONE_PATH="$BACKUP_LAST_PATH"
create_backup_at 700 manual "batch two" || fail "无法创建批量 Fixture 2"
BATCH_TWO_PATH="$BACKUP_LAST_PATH"
backup_inventory_scan || fail "批量删除前扫描失败"
batch_one_index="$(backup_index_by_id "$(basename -- "$BATCH_ONE_PATH")")" || fail "无法定位批量 Fixture 1"
batch_two_index="$(backup_index_by_id "$(basename -- "$BATCH_TWO_PATH")")" || fail "无法定位批量 Fixture 2"
printf '%s,%s %s invalid 999\ny\n' "$((batch_one_index + 1))" "$((batch_two_index + 1))" \
    "$((batch_one_index + 1))" | backup_delete_interactive true >/dev/null || fail "批量删除流程失败"
[[ ! -e "$BATCH_ONE_PATH" && ! -e "$BATCH_TWO_PATH" ]] || fail "批量删除未处理全部选择"

create_backup_at 800 manual "failure isolation" || fail "无法创建失败隔离 Fixture"
FAILURE_PATH="$BACKUP_LAST_PATH"
create_backup_at 900 manual "success after failure" || fail "无法创建后续删除 Fixture"
AFTER_FAILURE_PATH="$BACKUP_LAST_PATH"
backup_inventory_scan || fail "失败隔离前扫描失败"
failure_index="$(backup_index_by_id "$(basename -- "$FAILURE_PATH")")" || fail "无法定位失败 Fixture"
after_failure_index="$(backup_index_by_id "$(basename -- "$AFTER_FAILURE_PATH")")" || fail "无法定位后续 Fixture"
backup_remove_directory() {
    [[ "$1" == "$FAILURE_PATH" ]] && return 1
    rm -rf -- "$1"
}
backup_delete_selected "$failure_index" "$after_failure_index"
[[ "$BACKUP_DELETE_FAILED" == 1 && "$BACKUP_DELETE_SUCCESS" == 1 ]] || fail "单项删除失败未与后续项隔离"
[[ -d "$FAILURE_PATH" && ! -e "$AFTER_FAILURE_PATH" ]] || fail "失败隔离后的目录状态错误"
backup_remove_directory() { rm -rf -- "$1"; }

OUTSIDE_PATH="$TEST_TMP_ROOT/outside-backup"
mkdir -p -- "$OUTSIDE_PATH"
printf '%s\n' 'do not delete' > "$OUTSIDE_PATH/sentinel.txt"
if backup_delete_path "$OUTSIDE_PATH" manual; then fail "路径越界备份被删除"; fi
[[ -f "$OUTSIDE_PATH/sentinel.txt" ]] || fail "路径越界保护破坏了外部文件"
if backup_delete_path "$BACKUP_ROOT" manual; then fail "备份根目录本身被允许删除"; fi
if [[ "$(uname -s)" != MINGW* && "$(uname -s)" != MSYS* ]] \
    && ln -s "$OUTSIDE_PATH" "$BACKUP_ROOT/unsafe-link" 2>/dev/null; then
    if backup_delete_path "$BACKUP_ROOT/unsafe-link" manual; then fail "符号链接备份被允许删除"; fi
    [[ -f "$OUTSIDE_PATH/sentinel.txt" ]] || fail "符号链接越界破坏了外部文件"
fi

printf '%s\n' 'snapshot before restore' > "$ST_PATH/data/default-user/chats/chat.txt"
printf '%s\n' 'dataRoot: ./data' 'port: 8000' > "$ST_PATH/config.yaml"
printf '%s\n' 'extension snapshot before restore' > "$THIRD_PARTY_DIR/GitExtension/index.js"
create_backup_at 1000 manual "restore source" || fail "无法创建恢复源备份"
RESTORE_PATH="$BACKUP_LAST_PATH"
printf '%s\n' 'changed after backup' > "$ST_PATH/data/default-user/chats/chat.txt"
printf '%s\n' 'dataRoot: ./data' 'port: 9000' > "$ST_PATH/config.yaml"
rm -f -- "$THIRD_PARTY_DIR/GitExtension/index.js" \
    "$THIRD_PARTY_DIR/GitExtension/.hidden-setting" "$THIRD_PARTY_DIR/.backup-hidden"
mkdir -p -- "$THIRD_PARTY_DIR/AddedAfterBackup"
printf '%s\n' 'must disappear after restore' > "$THIRD_PARTY_DIR/AddedAfterBackup/index.js"
TEST_BACKUP_EPOCH=1100
backup_restore_path "$RESTORE_PATH" || fail "恢复失败：$BACKUP_LAST_ERROR"
[[ "$(< "$ST_PATH/data/default-user/chats/chat.txt")" == "snapshot before restore" ]] || fail "恢复后聊天数据不一致"
grep -Fxq 'port: 8000' "$ST_PATH/config.yaml" || fail "恢复后 config.yaml 不一致"
[[ "$(< "$THIRD_PARTY_DIR/GitExtension/index.js")" == "extension snapshot before restore" ]] \
    || fail "恢复后扩展普通文件不完整"
[[ "$(< "$THIRD_PARTY_DIR/GitExtension/.hidden-setting")" == "hidden extension setting" ]] \
    || fail "恢复后扩展隐藏文件不完整"
[[ -f "$THIRD_PARTY_DIR/GitExtension/.git/HEAD" ]] || fail "恢复后 Git 仓库不完整"
[[ -f "$THIRD_PARTY_DIR/.backup-hidden" ]] || fail "恢复后 third-party 根隐藏文件不完整"
[[ ! -e "$THIRD_PARTY_DIR/AddedAfterBackup" ]] || fail "恢复未同步移除备份后新增的扩展"
[[ "$(automatic_count)" -le 2 ]] || fail "恢复前 protective 备份未遵守自动池上限"
grep -Fq $'restore\tsuccess' "$STERMUX_ROOT/data/logs/backup.log" || fail "恢复成功未写入日志"
grep -Fq 'third-party=present' "$STERMUX_ROOT/data/logs/backup.log" || fail "日志未记录 third-party 存在状态"

mv -- "$THIRD_PARTY_DIR" "$TEST_TMP_ROOT/third-party-held" || fail "无法准备 third-party 缺失 Fixture"
TEST_BACKUP_EPOCH=1120
backup_create manual "third-party missing fixture" || fail "third-party 缺失时备份失败：$BACKUP_LAST_ERROR"
MISSING_THIRD_PARTY_BACKUP="$BACKUP_LAST_PATH"
[[ ! -e "$MISSING_THIRD_PARTY_BACKUP/third-party.tar.gz" ]] || fail "third-party 缺失时仍生成了归档"
grep -Fxq 'BACKUP_THIRD_PARTY_STATUS=missing' "$MISSING_THIRD_PARTY_BACKUP/metadata.conf" \
    || fail "third-party 缺失状态未写入元数据"
grep -Fq 'third-party=missing' "$STERMUX_ROOT/data/logs/backup.log" || fail "日志未记录 third-party 缺失状态"
mkdir -p -- "$THIRD_PARTY_DIR/CurrentOnly"
printf '%s\n' 'must be removed' > "$THIRD_PARTY_DIR/CurrentOnly/index.js"
TEST_BACKUP_EPOCH=1130
backup_restore_path "$MISSING_THIRD_PARTY_BACKUP" || fail "缺失状态 third-party 恢复失败：$BACKUP_LAST_ERROR"
[[ ! -e "$THIRD_PARTY_DIR" ]] || fail "恢复 third-party 缺失快照时未同步移除当前目录"
grep -Fq 'third-party=missing' "$STERMUX_ROOT/data/logs/backup.log" || fail "恢复日志未记录 third-party 缺失状态"

ORIGINAL_BACKUP_ROOT="$BACKUP_ROOT"
BACKUP_ROOT="$ST_PATH/data/nested-backups"
TEST_BACKUP_EPOCH=1150
if backup_create manual "recursive root must stop"; then fail "data 内部备份根目录未被拒绝"; fi
[[ "$BACKUP_LAST_ERROR" == *"不得位于 SillyTavern data"* ]] || fail "data 内部备份根目录缺少明确错误"
rmdir -- "$BACKUP_ROOT" || fail "无法清理空的递归根目录 Fixture"
BACKUP_ROOT="$ORIGINAL_BACKUP_ROOT"

if [[ "$(uname -s)" != MINGW* && "$(uname -s)" != MSYS* ]] \
    && ln -s "$OUTSIDE_PATH" "$ST_PATH/data/unsafe-data-link" 2>/dev/null \
    && [[ -L "$ST_PATH/data/unsafe-data-link" ]]; then
    TEST_BACKUP_EPOCH=1175
    if backup_create manual "symlink data must stop"; then fail "包含符号链接的数据被标记为成功备份"; fi
    [[ "$BACKUP_LAST_ERROR" == *"data 包含符号链接"* ]] || fail "数据符号链接缺少明确错误"
    rm -f -- "$ST_PATH/data/unsafe-data-link"
fi

printf '%s\n' 'dataRoot: /custom/user-data' > "$ST_PATH/config.yaml"
TEST_BACKUP_EPOCH=1200
if backup_create manual "custom dataRoot must stop"; then fail "自定义 dataRoot 被错误当作默认 data 备份"; fi
[[ "$BACKUP_LAST_ERROR" == *"自定义 dataRoot"* ]] || fail "自定义 dataRoot 缺少明确错误"

source "$PROJECT_ROOT/modules/sillytavern/update.sh"
AUTO_BACKUP_BEFORE_UPDATE=true
PROTECTIVE_MARKER="$TEST_TMP_ROOT/protective-called"
UPDATE_MARKER="$TEST_TMP_ROOT/update-called"
sillytavern_update_refresh() {
    ST_UPDATE_STATUS=update_available
    ST_UPDATE_BEHIND=1
    ST_UPDATE_LOCAL_VERSION=1.0.0
    ST_UPDATE_REMOTE_VERSION=1.0.1
    return 0
}
sillytavern_update_show_status() { :; }
git_worktree_has_changes() { return 1; }
backup_create() {
    [[ "$1" == protective && "$2" == before-sillytavern-update ]] || return 1
    printf '%s\n' protective > "$PROTECTIVE_MARKER"
}
sillytavern_update_execute() {
    printf '%s\n' updated > "$UPDATE_MARKER"
    ST_UPDATE_LAST_BEFORE_VERSION=1.0.0
    ST_UPDATE_LAST_AFTER_VERSION=1.0.1
}
printf 'y\n' | sillytavern_update_confirm_and_execute >/dev/null \
    || fail "更新前 protective 集成流程失败"
[[ -f "$PROTECTIVE_MARKER" && -f "$UPDATE_MARKER" ]] || fail "SillyTavern 更新前未先创建 protective 备份"

rm -f -- "$PROTECTIVE_MARKER" "$UPDATE_MARKER"
BACKUP_LAST_ERROR="simulated protective failure"
backup_create() { return 1; }
if printf 'y\n' | sillytavern_update_confirm_and_execute >/dev/null 2>&1; then
    fail "protective 备份失败后仍报告更新成功"
fi
[[ ! -e "$UPDATE_MARKER" ]] || fail "protective 备份失败后仍执行了 SillyTavern 更新"

printf '%s\n' 'PASS: 备份创建、验证、列表、最新 2 份轮换、安全删除、恢复及路径隔离测试通过'
