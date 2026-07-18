#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-scheduler.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-scheduler.*) rm -rf -- "$TEST_TMP_ROOT" ;;
        *) printf '拒绝清理非测试目录：%s\n' "$TEST_TMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

automatic_timed_count() {
    local index count=0

    backup_inventory_scan || return 1
    for ((index = 0; index < ${#BACKUP_TYPES[@]}; index++)); do
        case "${BACKUP_TYPES[index]}" in
            scheduled|catchup) count=$((count + 1)) ;;
        esac
    done
    printf '%s\n' "$count"
}

latest_timed_type() {
    local index

    backup_inventory_scan || return 1
    for ((index = 0; index < ${#BACKUP_TYPES[@]}; index++)); do
        case "${BACKUP_TYPES[index]}" in
            scheduled|catchup)
                printf '%s\n' "${BACKUP_TYPES[index]}"
                return 0
                ;;
        esac
    done
    return 1
}

STERMUX_ROOT="$TEST_TMP_ROOT/project"
HOME="$TEST_TMP_ROOT/home"
ST_PATH="$TEST_TMP_ROOT/Silly Tavern 中文"
BACKUP_ROOT="$TEST_TMP_ROOT/backups"
mkdir -p -- "$STERMUX_ROOT/config" "$ST_PATH/data/default-user/chats" \
    "$ST_PATH/public/scripts/extensions/third-party/TestExtension/.git" || exit 1
: > "$STERMUX_ROOT/config/user.conf"
printf '%s\n' '#!/usr/bin/env bash' > "$ST_PATH/start.sh"
printf '%s\n' '// fixture' > "$ST_PATH/server.js"
printf '%s\n' '{"name":"sillytavern","version":"1.15.0"}' > "$ST_PATH/package.json"
printf '%s\n' 'dataRoot: ./data' > "$ST_PATH/config.yaml"
printf '%s\n' 'scheduled fixture chat' > "$ST_PATH/data/default-user/chats/chat.txt"
printf '%s\n' 'ref: refs/heads/main' > "$ST_PATH/public/scripts/extensions/third-party/TestExtension/.git/HEAD"

source "$PROJECT_ROOT/core/utils.sh"
source "$PROJECT_ROOT/core/config.sh"
source "$PROJECT_ROOT/core/ui.sh"
source "$PROJECT_ROOT/core/git.sh"
source "$PROJECT_ROOT/modules/sillytavern/backup-rules.sh"
source "$PROJECT_ROOT/core/backup.sh"
source "$PROJECT_ROOT/core/scheduler.sh"

COLOR_ENABLED=false
ui_initialize
AUTOMATIC_BACKUP_KEEP=5
unset AUTO_BACKUP_ENABLED AUTO_BACKUP_INTERVAL_DAYS
backup_scheduler_enabled && fail "旧配置缺少 Phase 5 字段时自动备份没有默认关闭"
[[ "$(backup_scheduler_interval_days)" == 7 ]] || fail "旧配置缺少频率字段时没有回退到 7 天"

AUTO_BACKUP_ENABLED=false
AUTO_BACKUP_INTERVAL_DAYS=7
TEST_NOW=1000
backup_current_epoch() { printf '%s\n' "$TEST_NOW"; }
backup_current_display_time() { printf 'test-time-%s\n' "$TEST_NOW"; }

backup_scheduler_set_enabled true || fail "开启自动备份失败：$AUTO_BACKUP_LAST_ERROR"
backup_scheduler_enabled || fail "自动备份开启后状态仍为关闭"
grep -Fxq 'AUTO_BACKUP_ENABLED=true' "$STERMUX_ROOT/config/user.conf" \
    || fail "自动备份开启状态未保存"
backup_scheduler_state_read || fail "开启后未建立时间状态"
interval_seconds=$((7 * 86400))
[[ "$AUTO_BACKUP_NEXT_EPOCH" == $((TEST_NOW + interval_seconds)) ]] \
    || fail "开启后下一次备份时间计算错误"
[[ "$(automatic_timed_count)" == 0 ]] || fail "开启自动备份时错误创建了历史补做备份"

TEST_NOW=$((AUTO_BACKUP_NEXT_EPOCH - 1))
backup_scheduler_check || fail "未到期检查返回失败"
[[ "$(automatic_timed_count)" == 0 ]] || fail "未到时间仍创建了自动备份"

TEST_NOW=$AUTO_BACKUP_NEXT_EPOCH
backup_scheduler_check || fail "到期 scheduled 创建失败：$AUTO_BACKUP_LAST_ERROR"
[[ "$(automatic_timed_count)" == 1 ]] || fail "到期后没有且仅创建一份 scheduled"
[[ "$(latest_timed_type)" == scheduled ]] || fail "正常到期没有标记为 scheduled"
backup_scheduler_state_read || fail "scheduled 成功后状态不可读"
[[ "$AUTO_BACKUP_LAST_SUCCESS_EPOCH" == "$TEST_NOW" \
    && "$AUTO_BACKUP_NEXT_EPOCH" == $((TEST_NOW + interval_seconds)) ]] \
    || fail "scheduled 成功后时间状态错误"

scheduled_cycle_epoch=$TEST_NOW
count_before_recovery="$(automatic_timed_count)"
backup_scheduler_state_write 0 "$scheduled_cycle_epoch" || fail "无法准备状态提交中断 Fixture"
backup_scheduler_check || fail "已完成周期的状态恢复失败"
[[ "$(automatic_timed_count)" == "$count_before_recovery" ]] \
    || fail "备份已完成但状态未提交时重复创建了同周期备份"
backup_scheduler_state_read || fail "已完成周期恢复后状态不可读"
[[ "$AUTO_BACKUP_LAST_SUCCESS_EPOCH" == "$scheduled_cycle_epoch" \
    && "$AUTO_BACKUP_NEXT_EPOCH" == $((scheduled_cycle_epoch + interval_seconds)) ]] \
    || fail "已完成周期没有只补写时间状态"

count_before_repeat="$(automatic_timed_count)"
backup_scheduler_check || fail "同周期重复检查返回失败"
[[ "$(automatic_timed_count)" == "$count_before_repeat" ]] \
    || fail "同一个到期周期重复创建了自动备份"

missed_scheduled_epoch=$AUTO_BACKUP_NEXT_EPOCH
TEST_NOW=$((missed_scheduled_epoch + interval_seconds * 4))
count_before_catchup="$(automatic_timed_count)"
backup_scheduler_check || fail "逾期 catchup 创建失败：$AUTO_BACKUP_LAST_ERROR"
[[ "$(automatic_timed_count)" == $((count_before_catchup + 1)) ]] \
    || fail "错过多个周期没有只创建一份 catchup"
[[ "$(latest_timed_type)" == catchup ]] || fail "长时间逾期没有标记为 catchup"
backup_scheduler_state_read || fail "catchup 成功后状态不可读"
[[ "$AUTO_BACKUP_NEXT_EPOCH" == $((TEST_NOW + interval_seconds)) ]] \
    || fail "catchup 成功后没有从当前成功时间重新计算计划"

failure_due=$AUTO_BACKUP_NEXT_EPOCH
TEST_NOW=$failure_due
state_last_before_failure=$AUTO_BACKUP_LAST_SUCCESS_EPOCH
count_before_failure="$(automatic_timed_count)"
mv -- "$ST_PATH/config.yaml" "$TEST_TMP_ROOT/config.yaml.held" || fail "无法准备失败 Fixture"
if backup_scheduler_check >/dev/null 2>&1; then
    fail "备份源损坏时自动备份仍报告成功"
fi
backup_scheduler_state_read || fail "失败后状态文件损坏"
[[ "$AUTO_BACKUP_LAST_SUCCESS_EPOCH" == "$state_last_before_failure" \
    && "$AUTO_BACKUP_NEXT_EPOCH" == "$failure_due" ]] \
    || fail "备份失败时错误更新了时间状态"
[[ "$(automatic_timed_count)" == "$count_before_failure" ]] \
    || fail "失败的自动备份被记录为完成"
mv -- "$TEST_TMP_ROOT/config.yaml.held" "$ST_PATH/config.yaml" || fail "无法恢复失败 Fixture"
backup_scheduler_check || fail "失败后的下一次检查没有继续重试"
[[ "$(automatic_timed_count)" == $((count_before_failure + 1)) ]] \
    || fail "失败重试没有创建自动备份"

backup_scheduler_state_read || fail "重试成功后状态不可读"
invalid_due=$AUTO_BACKUP_NEXT_EPOCH
TEST_NOW=$invalid_due
valid_st_path="$ST_PATH"
ST_PATH="$TEST_TMP_ROOT/not-installed"
invalid_status=0
backup_scheduler_check >/dev/null 2>&1 || invalid_status=$?
[[ "$invalid_status" == 2 ]] || fail "无效 SillyTavern 路径没有安全跳过"
ST_PATH="$valid_st_path"
backup_scheduler_state_read || fail "无效路径检查破坏了状态文件"
[[ "$AUTO_BACKUP_NEXT_EPOCH" == "$invalid_due" ]] || fail "无效路径检查修改了下一次时间"

count_before_disable="$(automatic_timed_count)"
backup_scheduler_set_enabled false || fail "关闭自动备份失败"
backup_scheduler_enabled && fail "关闭后自动备份状态仍为开启"
grep -Fxq 'AUTO_BACKUP_ENABLED=false' "$STERMUX_ROOT/config/user.conf" \
    || fail "关闭状态未保存"
TEST_NOW=$((TEST_NOW + interval_seconds * 10))
backup_scheduler_check || fail "关闭后的检查不应失败"
[[ "$(automatic_timed_count)" == "$count_before_disable" ]] \
    || fail "自动备份关闭后仍然触发"

backup_scheduler_set_enabled true || fail "重新开启自动备份失败"
backup_scheduler_state_read || fail "重新开启后状态不可读"
[[ "$AUTO_BACKUP_NEXT_EPOCH" == $((TEST_NOW + interval_seconds)) ]] \
    || fail "重新开启后没有建立全新的未来计划"
backup_scheduler_check || fail "重新开启后的未到期检查失败"
[[ "$(automatic_timed_count)" == "$count_before_disable" ]] \
    || fail "重新开启后批量补做了关闭期间的历史备份"

old_interval="$(backup_scheduler_interval_days)"
old_next=$AUTO_BACKUP_NEXT_EPOCH
for invalid_interval in '' text 0 31 -1; do
    if backup_scheduler_set_interval_days "$invalid_interval" >/dev/null 2>&1; then
        fail "无效备份频率被接受：$invalid_interval"
    fi
    [[ "$(backup_scheduler_interval_days)" == "$old_interval" ]] \
        || fail "无效频率修改了现有配置"
    backup_scheduler_state_read || fail "无效频率破坏了状态文件"
    [[ "$AUTO_BACKUP_NEXT_EPOCH" == "$old_next" ]] || fail "无效频率修改了计划时间"
done

backup_scheduler_set_interval_days 3 || fail "设置每 3 天失败"
[[ "$(backup_scheduler_interval_days)" == 3 ]] || fail "每 3 天配置未生效"
grep -Fxq 'AUTO_BACKUP_INTERVAL_DAYS=3' "$STERMUX_ROOT/config/user.conf" \
    || fail "备份频率未持久化"
backup_scheduler_state_read || fail "频率修改后状态不可读"
[[ "$AUTO_BACKUP_NEXT_EPOCH" == $((TEST_NOW + 3 * 86400)) ]] \
    || fail "频率修改后没有重新建立下一次计划"

count_before_corrupt="$(automatic_timed_count)"
printf '%s\n' 'AUTO_BACKUP_NEXT_EPOCH=broken' > "$(backup_scheduler_state_file)"
backup_scheduler_check || fail "损坏状态没有安全初始化：$AUTO_BACKUP_LAST_ERROR"
[[ "$(automatic_timed_count)" == "$count_before_corrupt" ]] \
    || fail "状态损坏时错误创建了补做备份"
backup_scheduler_state_read || fail "损坏状态没有被替换为有效状态"
[[ "$AUTO_BACKUP_NEXT_EPOCH" == $((TEST_NOW + 3 * 86400)) ]] \
    || fail "损坏状态重建的下一次时间错误"

count_before_locked_check="$(automatic_timed_count)"
backup_scheduler_state_write "$AUTO_BACKUP_LAST_SUCCESS_EPOCH" "$TEST_NOW" \
    || fail "无法准备并发检查状态"
mkdir -- "$(backup_scheduler_lock_path)" || fail "无法准备并发检查锁"
printf '%s\n' "$$" > "$(backup_scheduler_lock_path)/pid"
backup_scheduler_check || fail "已有检查运行时没有安全跳过"
[[ "$(automatic_timed_count)" == "$count_before_locked_check" ]] \
    || fail "并发启动绕过检查锁重复创建了备份"
backup_scheduler_lock_release || fail "无法清理并发检查锁 Fixture"
backup_scheduler_reset_schedule || fail "并发检查后无法恢复未来计划"

settings_output="$(printf '0\n' | backup_automatic_settings_menu 2>&1)"
[[ "$settings_output" == *"自动备份：已开启"* \
    && "$settings_output" == *"备份频率：每 3 天"* \
    && "$settings_output" == *"最大自动备份数量：5 份"* \
    && "$settings_output" == *"1. 开启 / 关闭自动备份"* \
    && "$settings_output" == *"2. 设置备份频率"* \
    && "$settings_output" == *"3. 设置最大自动备份数量"* ]] \
    || fail "自动备份设置页信息或菜单不完整"
home_output="$(ui_main_menu '1.15.0' 'v0.0.2' "$(backup_scheduler_status_text)")"
[[ "$home_output" == *"自动备份    : 已开启"* ]] || fail "首页没有显示真实自动备份状态"

grep -Fq $'auto-check\t' "$STERMUX_ROOT/data/logs/backup.log" \
    || fail "日志缺少自动备份检查"
grep -Fq $'scheduled\tsuccess' "$STERMUX_ROOT/data/logs/backup.log" \
    || fail "日志缺少 scheduled 成功记录"
grep -Fq $'catchup\tsuccess' "$STERMUX_ROOT/data/logs/backup.log" \
    || fail "日志缺少 catchup 成功记录"
grep -Fq $'rotate\tsuccess' "$STERMUX_ROOT/data/logs/backup.log" \
    || fail "日志缺少自动轮换结果"

[[ "$(< "$PROJECT_ROOT/VERSION")" == v0.0.2 ]] || fail "项目 VERSION 未更新为 v0.0.2"

printf '%s\n' 'PASS: Phase 5 开关、频率、scheduled/catchup、失败重试、状态与启动检查测试通过'
