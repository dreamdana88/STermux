#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-paths.XXXXXX")" || exit 1

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-paths.*)
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

create_valid_install() {
    local path="$1"

    mkdir -p -- "$path" || return 1
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$path/start.sh"
    printf '%s\n' '// test fixture' > "$path/server.js"
    printf '%s\n' '{"name":"sillytavern"}' > "$path/package.json"
}

source "$PROJECT_ROOT/core/utils.sh"

HOME="$TEST_TMP_ROOT/home"
common_path="$HOME/SillyTavern"
space_path="$TEST_TMP_ROOT/Silly Tavern 中文"
invalid_path="$TEST_TMP_ROOT/not-sillytavern"

mkdir -p -- "$invalid_path"
printf '%s\n' '{"name":"another-project"}' > "$invalid_path/package.json"

if sillytavern_path_is_valid "$invalid_path"; then
    fail "无效目录被识别为 SillyTavern"
fi

create_valid_install "$common_path" || fail "无法创建常见路径 Fixture"
create_valid_install "$space_path" || fail "无法创建特殊路径 Fixture"

sillytavern_path_is_valid "$common_path" || fail "常见路径未通过验证"
sillytavern_path_is_valid "$space_path" || fail "空格和中文路径未通过验证"

found_path="$(sillytavern_find_common_path)" || fail "未发现常见路径"
expected_common="$(path_canonicalize_directory "$common_path")" || fail "无法规范化常见路径"
[[ "$found_path" == "$expected_common" ]] || fail "常见路径结果不一致"

normalized="$(path_normalize_input "~/SillyTavern/")"
[[ "$normalized" == "$HOME/SillyTavern" ]] || fail "HOME 路径展开失败"

quoted="$(path_normalize_input "\"$space_path\"")"
[[ "$quoted" == "$space_path" ]] || fail "引号路径规范化失败"

printf '%s\n' 'PASS: 路径识别、常见路径和特殊字符测试通过'
