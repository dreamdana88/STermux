#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-uninstall.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-uninstall.*) rm -rf -- "$TEST_TMP_ROOT" ;;
        *) printf '拒绝清理非测试目录：%s\n' "$TEST_TMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

create_stermux_fixture() {
    local root="$1"
    mkdir -p -- "$root/core" "$root/config" "$root/data/logs" \
        "$root/backups/sillytavern" || return 1
    printf '%s\n' '#!/usr/bin/env bash' > "$root/manager.sh"
    printf '%s\n' '# fixture' > "$root/core/ui.sh"
    printf '%s\n' 'v0.0.1' > "$root/VERSION"
    : > "$root/config/user.conf"
}

create_sillytavern_fixture() {
    local root="$1"
    mkdir -p -- "$root/data/default-user" "$root/public/scripts/extensions/third-party" || return 1
    printf '%s\n' '#!/usr/bin/env bash' > "$root/start.sh"
    printf '%s\n' '// fixture' > "$root/server.js"
    printf '%s\n' '{"name":"sillytavern"}' > "$root/package.json"
    printf '%s\n' 'dataRoot: ./data' > "$root/config.yaml"
    printf '%s\n' keep > "$root/data/default-user/sentinel.txt"
}

create_backup_fixture() {
    local root="$1" id="$2" type="$3" size="$4" epoch="$5"
    mkdir -p -- "$root/$id" || return 1
    {
        printf 'BACKUP_ID=%s\n' "$id"
        printf 'BACKUP_TIME_EPOCH=%s\n' "$epoch"
        printf 'BACKUP_TIME=test-%s\n' "$epoch"
        printf 'BACKUP_TYPE=%s\n' "$type"
        printf 'BACKUP_SIZE=%s\n' "$size"
        printf 'BACKUP_STATUS=success\n'
    } > "$root/$id/metadata.conf"
}

HOME="$TEST_TMP_ROOT/home"
PREFIX="$TEST_TMP_ROOT/prefix"
mkdir -p -- "$HOME" "$PREFIX/tmp"
SHELL=/bin/bash
STERMUX_AUTOSTART_SHELL=/bin/bash
STERMUX_AUTOSTART_RC_FILE="$HOME/.bashrc"
STERMUX_UNINSTALL_TMPDIR="$PREFIX/tmp"
printf '%s\n' '# user shell setting' > "$HOME/.bashrc"

source "$PROJECT_ROOT/core/utils.sh"
source "$PROJECT_ROOT/core/config.sh"
source "$PROJECT_ROOT/core/ui.sh"
source "$PROJECT_ROOT/core/autostart.sh"
source "$PROJECT_ROOT/core/backup.sh"
source "$PROJECT_ROOT/core/uninstall.sh"
ui_initialize

COLOR_ENABLED=true
ui_terminal_supports_color() { return 0; }
ui_initialize
uninstall_menu_output="$(uninstall_show_menu)"
[[ "$uninstall_menu_output" == *$'\033[37m1. 卸载 STermux'* ]] \
    || fail "卸载主选项未使用白色"
[[ "$uninstall_menu_output" == *$'\033[90m   包含程序、配置、日志及所有备份'* ]] \
    || fail "卸载备注未使用灰色次级文字"
unset -f ui_terminal_supports_color
COLOR_ENABLED=false
ui_initialize

uninstall_parse_selection '1 4 1 invalid 9' || fail "空格多选解析失败"
[[ "${UNINSTALL_SELECTED_ACTIONS[*]}" == '1 4' ]] || fail "空格多选未过滤非法编号或去重"
uninstall_parse_selection '2,3,2' || fail "逗号多选解析失败"
[[ "${UNINSTALL_SELECTED_ACTIONS[*]}" == '2 3' ]] || fail "逗号多选未去重"

STERMUX_ROOT="$TEST_TMP_ROOT/stermux-main"
ST_PATH="$TEST_TMP_ROOT/SillyTavern-main"
BACKUP_ROOT="$STERMUX_ROOT/backups/sillytavern"
create_stermux_fixture "$STERMUX_ROOT" || fail "无法创建 STermux Fixture"
create_sillytavern_fixture "$ST_PATH" || fail "无法创建 SillyTavern Fixture"
printf 'ST_PATH=%q\n' "$ST_PATH" > "$STERMUX_ROOT/config/user.conf"

if sillytavern_uninstall_path_is_valid ''; then fail "空 SillyTavern 路径未被拒绝"; fi
if sillytavern_uninstall_path_is_valid /; then fail "根目录未被拒绝"; fi
if sillytavern_uninstall_path_is_valid "$HOME"; then fail "HOME 路径未被拒绝"; fi
if sillytavern_uninstall_path_is_valid "$PREFIX"; then fail "PREFIX 路径未被拒绝"; fi
mkdir -p -- "$TEST_TMP_ROOT/not-sillytavern"
if sillytavern_uninstall_path_is_valid "$TEST_TMP_ROOT/not-sillytavern"; then
    fail "非 SillyTavern 目录未被拒绝"
fi

cancel_output="$(printf '2\n\n' | uninstall_manager_menu 2>&1)"
[[ "$cancel_output" == *"已取消卸载操作"* ]] || fail "最终确认回车未取消"
[[ -d "$ST_PATH" ]] || fail "回车取消后 SillyTavern 被删除"
cancel_output="$(printf '2\nn\n' | uninstall_manager_menu 2>&1)"
[[ "$cancel_output" == *"已取消卸载操作"* ]] || fail "最终确认 n 未取消"
[[ -d "$ST_PATH" ]] || fail "输入 n 后 SillyTavern 被删除"

uninstall_sillytavern_execute || fail "只卸载 SillyTavern 失败：$UNINSTALL_LAST_ERROR"
[[ ! -e "$ST_PATH" ]] || fail "SillyTavern 目录未删除"
[[ -d "$STERMUX_ROOT" ]] || fail "只卸载 SillyTavern 时误删 STermux"
if grep -Eq '^ST_PATH=' "$STERMUX_ROOT/config/user.conf"; then fail "SillyTavern 删除后 ST_PATH 未清理"; fi

ST_PATH="$TEST_TMP_ROOT/SillyTavern-backups"
create_sillytavern_fixture "$ST_PATH" || fail "无法重建 SillyTavern Fixture"
create_backup_fixture "$BACKUP_ROOT" 100_manual manual 10 100
create_backup_fixture "$BACKUP_ROOT" 200_protective protective 20 200
create_backup_fixture "$BACKUP_ROOT" 300_scheduled scheduled 30 300
create_backup_fixture "$BACKUP_ROOT" 400_catchup catchup 40 400
uninstall_backup_summary || fail "无法统计全部备份"
[[ "$UNINSTALL_BACKUP_COUNT" == 4 ]] || fail "全部备份数量统计错误"
[[ "$UNINSTALL_BACKUP_SIZE" == 100 ]] || fail "全部备份大小统计错误"
uninstall_delete_all_backups || fail "删除全部备份失败：$UNINSTALL_LAST_ERROR"
backup_inventory_scan || fail "删除全部备份后扫描失败"
[[ "${#BACKUP_IDS[@]}" == 0 ]] || fail "全部备份未删除干净"
[[ -d "$STERMUX_ROOT" && -d "$ST_PATH" ]] || fail "删除备份误伤程序或 SillyTavern"

NO_BACKUP_ST_MARKER="$TEST_TMP_ROOT/no-backup-st-marker"
uninstall_sillytavern_execute() { printf '%s\n' called > "$NO_BACKUP_ST_MARKER"; }
printf '2 3\ny\n' | uninstall_manager_menu >/dev/null 2>&1 || true
[[ -f "$NO_BACKUP_ST_MARKER" ]] || fail "组合操作因没有备份而跳过 SillyTavern 卸载"
unset -f uninstall_sillytavern_execute
source "$PROJECT_ROOT/core/uninstall.sh"

autostart_enable || fail "无法准备自动进入 Fixture：$AUTOSTART_LAST_ERROR"
grep -Fq '# >>> STermux autostart >>>' "$HOME/.bashrc" || fail "自动进入 Fixture 未创建"
uninstall_autostart_execute || fail "只删除自动进入配置失败：$UNINSTALL_LAST_ERROR"
grep -Fq '# user shell setting' "$HOME/.bashrc" || fail "删除自动进入配置破坏用户 Shell 内容"
if grep -Fq '# >>> STermux autostart >>>' "$HOME/.bashrc"; then fail "自动进入托管区域未删除"; fi
uninstall_autostart_execute || fail "重复删除未启用的自动进入配置失败"

autostart_enable || fail "无法重新准备自动进入 Fixture"
HANDOFF_MARKER="$TEST_TMP_ROOT/handoff-marker"
uninstall_self_handoff() { printf '%s\n' handoff > "$HANDOFF_MARKER"; }
keep_output="$(printf '1\nn\ny\n' | uninstall_manager_menu 2>&1)"
[[ -f "$HANDOFF_MARKER" ]] || fail "选择保留自动进入时未继续 STermux 卸载"
grep -Fq '# >>> STermux autostart >>>' "$HOME/.bashrc" || fail "用户选择保留时自动进入仍被删除"

rm -f -- "$HANDOFF_MARKER"
printf '1\n\ny\n' | uninstall_manager_menu >/dev/null 2>&1 || true
[[ -f "$HANDOFF_MARKER" ]] || fail "卸载 STermux 并删除自动进入配置时未交接"
if grep -Fq '# >>> STermux autostart >>>' "$HOME/.bashrc"; then
    fail "默认 Y 未随 STermux 卸载删除自动进入托管区域"
fi
grep -Fq '# user shell setting' "$HOME/.bashrc" || fail "组合卸载破坏用户 Shell 配置"

rm -f -- "$HANDOFF_MARKER"
BACKUP_DELETE_MARKER="$TEST_TMP_ROOT/backup-delete-marker"
uninstall_delete_all_backups() { printf '%s\n' called > "$BACKUP_DELETE_MARKER"; }
printf '1 3\nn\ny\n' | uninstall_manager_menu >/dev/null 2>&1 || true
[[ -f "$HANDOFF_MARKER" ]] || fail "STermux + 备份组合未进入自删除交接"
[[ ! -e "$BACKUP_DELETE_MARKER" ]] || fail "卸载 STermux 时重复执行独立备份删除"
unset -f uninstall_delete_all_backups
source "$PROJECT_ROOT/core/uninstall.sh"

rm -f -- "$HANDOFF_MARKER"
uninstall_self_handoff() { printf '%s\n' handoff > "$HANDOFF_MARKER"; }
uninstall_sillytavern_execute() { UNINSTALL_LAST_ERROR='simulated SillyTavern failure'; return 1; }
partial_output="$(printf '1 2\nn\ny\nn\n' | uninstall_manager_menu 2>&1)"
[[ "$partial_output" == *"SillyTavern 卸载失败"* ]] || fail "部分失败结果未明确显示"
[[ "$partial_output" == *"是否仍然继续卸载 STermux"* ]] || fail "部分失败后未再次确认"
[[ ! -e "$HANDOFF_MARKER" ]] || fail "部分失败后用户取消仍执行 STermux 自删除"
unset -f uninstall_sillytavern_execute uninstall_self_handoff
source "$PROJECT_ROOT/core/uninstall.sh"

SELF_ROOT="$TEST_TMP_ROOT/stermux-self-delete"
SELF_ST="$TEST_TMP_ROOT/SillyTavern-preserved"
create_stermux_fixture "$SELF_ROOT" || fail "无法创建自删除 STermux Fixture"
create_sillytavern_fixture "$SELF_ST" || fail "无法创建自删除保留 SillyTavern Fixture"
create_backup_fixture "$SELF_ROOT/backups/sillytavern" self_manual manual 25 500
STERMUX_ROOT="$SELF_ROOT"
ST_PATH="$SELF_ST"
BACKUP_ROOT="$SELF_ROOT/backups/sillytavern"
self_script="$(uninstall_self_script_create)" || fail "无法创建安全自删除临时脚本：$UNINSTALL_LAST_ERROR"
[[ "$self_script" == "$PREFIX/tmp/"* && -x "$self_script" ]] || fail "自删除脚本不在安全临时目录"
self_output="$(bash "$self_script" "$SELF_ROOT" "$HOME" "$PREFIX" "$SELF_ST" true 2>&1)" \
    || fail "自删除临时脚本执行失败"
[[ ! -e "$SELF_ROOT" ]] || fail "STermux 自删除后项目目录仍存在"
[[ ! -e "$SELF_ROOT/backups" ]] || fail "STermux 自删除后内部备份仍存在"
[[ -f "$SELF_ST/data/default-user/sentinel.txt" ]] || fail "只卸载 STermux 时误删 SillyTavern"
[[ "$self_output" == *"STermux 已成功卸载"* ]] || fail "自删除完成缺少告别标题"
[[ "$self_output" == *"SillyTavern 及其用户数据已保留"* ]] || fail "告别信息未说明 SillyTavern 保留"
[[ "$self_output" == *"Termux 公共依赖未被删除"* ]] || fail "告别信息未说明公共依赖保留"
[[ ! -e "$self_script" ]] || fail "临时自删除脚本未自行清理"

if grep -Eq 'pkg +(uninstall|remove)|apt +remove' "$PROJECT_ROOT/core/uninstall.sh"; then
    fail "卸载管理包含公共依赖卸载命令"
fi

printf '%s\n' 'PASS: 卸载组合、安全路径、自删除、备份统计和 autostart 隔离测试通过'
