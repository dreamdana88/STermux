#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-autostart.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-autostart.*) rm -rf -- "$TEST_TMP_ROOT" ;;
        *) printf '拒绝清理非测试目录：%s\n' "$TEST_TMP_ROOT" >&2 ;;
    esac
}
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

backup_count() {
    find "$HOME" -maxdepth 1 -type f -name '.bashrc.stermux.bak.*' | wc -l | tr -d '[:space:]'
}

HOME="$TEST_TMP_ROOT/home"
STERMUX_ROOT="$TEST_TMP_ROOT/STermux [测试] \$special path"
STERMUX_AUTOSTART_SHELL=/bin/bash
STERMUX_AUTOSTART_RC_FILE="$HOME/.bashrc"
AUTOSTART_TEST_COUNT="$TEST_TMP_ROOT/manager-count"
AUTOSTART_TEST_RC="$STERMUX_AUTOSTART_RC_FILE"
AUTOSTART_TEST_RETURNED="$TEST_TMP_ROOT/returned-to-shell"
export HOME AUTOSTART_TEST_COUNT AUTOSTART_TEST_RC AUTOSTART_TEST_RETURNED

mkdir -p -- "$HOME" "$STERMUX_ROOT" || exit 1
printf '%s\n' 'export USER_SETTING=keep-me' 'alias user_alias="printf preserved"' > "$HOME/.bashrc"
cp -- "$HOME/.bashrc" "$TEST_TMP_ROOT/original-bashrc"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'count=0' \
    '[[ -f "$AUTOSTART_TEST_COUNT" ]] && count="$(< "$AUTOSTART_TEST_COUNT")"' \
    'count=$((count + 1))' \
    'printf "%s\n" "$count" > "$AUTOSTART_TEST_COUNT"' \
    'if (( count == 1 )); then' \
    '    bash --noprofile --rcfile "$AUTOSTART_TEST_RC" -i -c "exit 0" >/dev/null 2>&1' \
    'fi' \
    > "$STERMUX_ROOT/manager.sh"

source "$PROJECT_ROOT/core/utils.sh"
source "$PROJECT_ROOT/core/autostart.sh"

[[ "$(autostart_status_text)" == "已关闭（Bash）" ]] || fail "默认状态不是关闭"
autostart_enable || fail "开启自动进入失败：$AUTOSTART_LAST_ERROR"
[[ -f "$AUTOSTART_LAST_BACKUP" ]] || fail "修改现有 .bashrc 前未创建备份"
grep -Fxq 'export USER_SETTING=keep-me' "$HOME/.bashrc" || fail "开启时破坏用户原配置"
grep -Fxq 'alias user_alias="printf preserved"' "$HOME/.bashrc" || fail "开启时丢失用户 alias"
[[ "$(grep -Fxc "$AUTOSTART_BEGIN_MARKER" "$HOME/.bashrc")" == 1 ]] || fail "开启后托管区域数量错误"
[[ "$(grep -Fxc "$AUTOSTART_END_MARKER" "$HOME/.bashrc")" == 1 ]] || fail "开启后结束标记数量错误"
grep -Fq '[[ $- == *i* ]]' "$HOME/.bashrc" || fail "自动进入缺少交互式 Shell 判断"
grep -Fq 'STERMUX_AUTOSTART_ACTIVE' "$HOME/.bashrc" || fail "自动进入缺少防递归标记"

backups_after_first_enable="$(backup_count)"
autostart_enable || fail "重复开启失败：$AUTOSTART_LAST_ERROR"
[[ "$(grep -Fxc "$AUTOSTART_BEGIN_MARKER" "$HOME/.bashrc")" == 1 ]] || fail "重复开启产生重复托管区域"
[[ "$(backup_count)" == "$backups_after_first_enable" ]] || fail "无变化的重复开启仍创建配置备份"
[[ "$(autostart_status_text)" == "已开启（Bash）" ]] || fail "开启后状态显示错误"

rm -f -- "$AUTOSTART_TEST_COUNT"
bash --noprofile --rcfile "$HOME/.bashrc" -i -c \
    'printf "%s\n" returned > "$AUTOSTART_TEST_RETURNED"; exit 0' >/dev/null 2>&1 \
    || fail "特殊字符路径自动启动失败"
[[ "$(< "$AUTOSTART_TEST_COUNT")" == 1 ]] || fail "自动进入发生递归启动"
[[ -f "$AUTOSTART_TEST_RETURNED" ]] || fail "退出 STermux 后未返回原交互式 Shell"

rm -f -- "$AUTOSTART_TEST_COUNT"
bash -c 'source "$AUTOSTART_TEST_RC"' >/dev/null 2>&1 || fail "非交互式加载 .bashrc 失败"
[[ ! -e "$AUTOSTART_TEST_COUNT" ]] || fail "非交互式 Shell 意外启动 STermux"

rm -f -- "$AUTOSTART_TEST_COUNT"
STERMUX_AUTOSTART_ACTIVE=1 bash --noprofile --rcfile "$HOME/.bashrc" -i -c 'exit 0' \
    >/dev/null 2>&1 || fail "防递归标记 Shell 执行失败"
[[ ! -e "$AUTOSTART_TEST_COUNT" ]] || fail "防递归标记未阻止再次启动"

mv -- "$STERMUX_ROOT/manager.sh" "$STERMUX_ROOT/manager.sh.missing"
rm -f -- "$AUTOSTART_TEST_COUNT"
bash --noprofile --rcfile "$HOME/.bashrc" -i -c 'exit 0' >/dev/null 2>&1 \
    || fail "manager.sh 缺失时 Shell 启动失败"
[[ ! -e "$AUTOSTART_TEST_COUNT" ]] || fail "manager.sh 缺失时仍执行了入口"
mv -- "$STERMUX_ROOT/manager.sh.missing" "$STERMUX_ROOT/manager.sh"

autostart_disable || fail "关闭自动进入失败：$AUTOSTART_LAST_ERROR"
cmp -s -- "$TEST_TMP_ROOT/original-bashrc" "$HOME/.bashrc" || fail "关闭后未完整保留用户原配置"
if grep -Fq "$AUTOSTART_BEGIN_MARKER" "$HOME/.bashrc"; then fail "关闭后仍保留托管区域"; fi
backups_after_disable="$(backup_count)"
(( backups_after_disable > backups_after_first_enable )) || fail "关闭前未单独备份现有 Shell 配置"
autostart_disable || fail "重复关闭失败：$AUTOSTART_LAST_ERROR"
[[ "$(backup_count)" == "$backups_after_disable" ]] || fail "无变化的重复关闭仍创建配置备份"
cmp -s -- "$TEST_TMP_ROOT/original-bashrc" "$HOME/.bashrc" || fail "重复关闭破坏用户配置"

STERMUX_AUTOSTART_SHELL=/bin/zsh
if autostart_enable; then fail "不支持的 Zsh 被擅自修改"; fi
[[ "$AUTOSTART_LAST_ERROR" == *"当前版本仅支持 Bash"* ]] || fail "Zsh 缺少明确提示"
cmp -s -- "$TEST_TMP_ROOT/original-bashrc" "$HOME/.bashrc" || fail "Zsh 检测修改了 .bashrc"

printf '%s\n' 'PASS: 自动进入开启、幂等关闭、原配置保留、特殊路径、缺失入口及防递归测试通过'
