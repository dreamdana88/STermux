#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-config.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-config.*)
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

mkdir -p -- "$TEST_TMP_ROOT/config" || exit 1
grep -Fxq 'AUTOMATIC_BACKUP_KEEP=2' "$PROJECT_ROOT/config/default.conf" \
    || fail "项目默认自动备份保留数量不是 2"
grep -Fxq 'BACKUP_ROOT="$STERMUX_ROOT/backups/sillytavern"' "$PROJECT_ROOT/config/default.conf" \
    || fail "项目默认备份根目录配置缺失"
grep -Fxq 'AUTO_BACKUP_BEFORE_UPDATE=true' "$PROJECT_ROOT/config/default.conf" \
    || fail "项目默认更新前保护备份未启用"
grep -Fxq 'AUTO_ENTER_MANAGER=false' "$PROJECT_ROOT/config/default.conf" \
    || fail "自动进入 STermux 默认值不是关闭"
grep -Fxq 'COLOR_ENABLED=true' "$PROJECT_ROOT/config/default.conf" \
    || fail "终端颜色安全默认值不是开启"
printf '%s\n' \
    'ST_PATH="$HOME/SillyTavern"' \
    'AUTOMATIC_BACKUP_KEEP=2' \
    'COLOR_ENABLED=true' \
    'FUTURE_SETTING="default"' \
    > "$TEST_TMP_ROOT/config/default.conf"
printf '%s\n' 'FUTURE_SETTING="keep-me"' > "$TEST_TMP_ROOT/config/user.conf"

STERMUX_ROOT="$TEST_TMP_ROOT"
HOME="$TEST_TMP_ROOT/home"
source "$PROJECT_ROOT/core/config.sh"

config_load || fail "无法加载配置"
[[ "$ST_PATH" == "$HOME/SillyTavern" ]] || fail "默认 ST_PATH 未加载"
[[ "$AUTOMATIC_BACKUP_KEEP" == 2 ]] || fail "默认自动备份保留数量未加载为 2"
[[ "$COLOR_ENABLED" == true ]] || fail "默认颜色设置未加载"
[[ "$FUTURE_SETTING" == "keep-me" ]] || fail "用户配置未覆盖默认配置"

expected_path="$TEST_TMP_ROOT/Silly Tavern 中文"
config_set_value "ST_PATH" "$expected_path" || fail "无法保存 ST_PATH"

unset ST_PATH AUTOMATIC_BACKUP_KEEP FUTURE_SETTING
source "$TEST_TMP_ROOT/config/user.conf"
[[ "$ST_PATH" == "$expected_path" ]] || fail "保存后的 ST_PATH 不一致"
[[ "$FUTURE_SETTING" == "keep-me" ]] || fail "保存 ST_PATH 时破坏了其他配置"

config_set_value "COLOR_ENABLED" "false" || fail "无法保存颜色设置"
unset COLOR_ENABLED
source "$TEST_TMP_ROOT/config/user.conf"
[[ "$COLOR_ENABLED" == false ]] || fail "保存后的颜色设置不一致"
[[ "$ST_PATH" == "$expected_path" ]] || fail "保存颜色设置时破坏了 ST_PATH"

if config_set_value "UNKNOWN_SETTING" "value" >/dev/null 2>&1; then
    fail "未知配置项未被拒绝"
fi

printf '%s\n' 'PASS: 配置加载、覆盖、保存与保留测试通过'
