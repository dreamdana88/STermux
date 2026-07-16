#!/usr/bin/env bash

set -u
set -o pipefail

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 1
TEST_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stermux-test-install.XXXXXX")" || exit 1
ORIGINAL_PATH="$PATH"

cleanup() {
    case "$TEST_TMP_ROOT" in
        "${TMPDIR:-/tmp}"/stermux-test-install.*)
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

create_valid_install() {
    local target="$1"

    mkdir -p -- "$target" || return 1
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$target/start.sh"
    printf '%s\n' '// SillyTavern test fixture' > "$target/server.js"
    printf '%s\n' '{"name":"sillytavern","version":"1.18.0"}' > "$target/package.json"
}

STERMUX_ROOT="$TEST_TMP_ROOT/stermux"
HOME="$TEST_TMP_ROOT/home"
PREFIX="/data/data/com.termux/files/usr"
mkdir -p -- "$STERMUX_ROOT/config" "$HOME"
printf '%s\n' 'ST_PATH="$HOME/SillyTavern"' > "$STERMUX_ROOT/config/default.conf"
printf '%s\n' '# isolated installer test configuration' > "$STERMUX_ROOT/config/user.conf"

source "$PROJECT_ROOT/core/utils.sh"
source "$PROJECT_ROOT/core/config.sh"
source "$PROJECT_ROOT/core/ui.sh"
source "$PROJECT_ROOT/modules/sillytavern/install.sh"
ui_initialize
config_load || fail "无法加载隔离安装测试配置"

test_ready_command() {
    printf '%s\n' 'test-ready 1.0.0'
}

test_broken_command() {
    printf '%s\n' 'CANNOT LINK EXECUTABLE: library libcrypto.so not found' >&2
    return 127
}

sillytavern_dependency_probe test_ready_command --version || fail "可运行命令被误判"
[[ "$ST_INSTALL_DEPENDENCY_STATUS" == "ready" ]] || fail "可运行命令状态不是 ready"

if sillytavern_dependency_probe definitely_missing_stermux_command --version; then
    fail "不存在命令被误判为可运行"
fi
[[ "$ST_INSTALL_DEPENDENCY_STATUS" == "missing" ]] || fail "不存在命令状态不是 missing"

probe_status=0
sillytavern_dependency_probe test_broken_command --version || probe_status=$?
[[ "$probe_status" == 2 ]] || fail "损坏命令未返回独立状态"
[[ "$ST_INSTALL_DEPENDENCY_STATUS" == "broken" ]] || fail "损坏命令状态不是 broken"
[[ "$ST_INSTALL_DEPENDENCY_OUTPUT" == *"CANNOT LINK EXECUTABLE"* ]] || fail "损坏命令诊断信息丢失"

ST_INSTALL_DEPENDENCY_COMMANDS=(test_ready_command definitely_missing_stermux_command test_broken_command)
ST_INSTALL_DEPENDENCY_PACKAGES=(ready-package missing-package broken-package)
ST_INSTALL_DEPENDENCY_ARGUMENTS=(--version --version --version)
dependency_status=0
sillytavern_install_check_dependencies >/dev/null 2>&1 || dependency_status=$?
[[ "$dependency_status" == 2 ]] || fail "损坏依赖未优先于缺失依赖返回"
[[ " ${ST_INSTALL_MISSING_PACKAGES[*]} " == *" missing-package "* ]] || fail "未记录缺失软件包"
[[ "${ST_INSTALL_BROKEN_DEPENDENCIES[*]}" == *"CANNOT LINK EXECUTABLE"* ]] || fail "未记录损坏依赖"
[[ "${ST_INSTALL_BROKEN_PACKAGES[*]}" == *"broken-package"* ]] || fail "未记录损坏依赖对应软件包"

mock_bin="$TEST_TMP_ROOT/mock-bin"
mkdir -p -- "$mock_bin"
mock_installed_tool="$mock_bin/mock-installed-tool"
mock_pkg_calls="$TEST_TMP_ROOT/pkg-calls.log"
MOCK_PKG_INSTALL_STATUS=0
export MOCK_INSTALLED_TOOL="$mock_installed_tool" MOCK_PKG_CALLS="$mock_pkg_calls" MOCK_PKG_INSTALL_STATUS
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'if [[ "${1:-}" == "list-installed" ]]; then exit 0; fi' \
    'printf "%s\n" "$*" >> "$MOCK_PKG_CALLS"' \
    'printf "%s\n" "MOCK PKG: Downloading packages" "MOCK PKG: Unpacking" "MOCK PKG: Setting up"' \
    'if [[ "${1:-}" != "install" || "${2:-}" != "-y" ]]; then printf "missing automatic confirmation flag\\n" >&2; exit 64; fi' \
    'if (( MOCK_PKG_INSTALL_STATUS != 0 )); then printf "MOCK PKG: installation failed\\n" >&2; exit "$MOCK_PKG_INSTALL_STATUS"; fi' \
    'printf "%s\n" "#!/usr/bin/env bash" "printf '\''mock-installed 1.0.0\\n'\''" > "$MOCK_INSTALLED_TOOL"' \
    'chmod +x "$MOCK_INSTALLED_TOOL"' \
    'exit 0' \
    > "$mock_bin/pkg"
chmod +x "$mock_bin/pkg"
PATH="$mock_bin:$ORIGINAL_PATH"
export PATH

ST_INSTALL_DEPENDENCY_COMMANDS=(mock-installed-tool)
ST_INSTALL_DEPENDENCY_PACKAGES=(mock-package)
ST_INSTALL_DEPENDENCY_ARGUMENTS=(--version)
sillytavern_install_check_dependencies >/dev/null 2>&1 || true
[[ "${ST_INSTALL_MISSING_PACKAGES[*]}" == "mock-package" ]] || fail "Mock 缺失依赖未被识别"
pkg_output_file="$TEST_TMP_ROOT/pkg-output.log"
sillytavern_install_missing_dependencies > "$pkg_output_file" 2>&1 \
    || fail "Mock 缺失依赖安装及复验失败"
grep -Fq 'install -y mock-package' "$mock_pkg_calls" || fail "用户确认后 pkg 未使用自动确认参数"
grep -Fq 'MOCK PKG: Downloading packages' "$pkg_output_file" || fail "pkg 正常安装输出被吞掉"
sillytavern_dependency_probe mock-installed-tool --version || fail "pkg 安装成功后未重新验证依赖"

rm -f -- "$mock_installed_tool"
ST_INSTALL_DEPENDENCY_COMMANDS=(mock-failed-tool)
ST_INSTALL_DEPENDENCY_PACKAGES=(failed-package)
ST_INSTALL_DEPENDENCY_ARGUMENTS=(--version)
sillytavern_install_check_dependencies >/dev/null 2>&1 || true
MOCK_PKG_INSTALL_STATUS=42
export MOCK_PKG_INSTALL_STATUS
if sillytavern_install_missing_dependencies > "$pkg_output_file" 2>&1; then
    fail "Mock pkg 安装失败时流程意外成功"
fi
grep -Fq 'MOCK PKG: installation failed' "$pkg_output_file" || fail "pkg 安装错误输出被吞掉"
[[ "$ST_INSTALL_LAST_ERROR" == *"必要依赖安装失败"* ]] || fail "pkg 安装失败缺少明确错误"
MOCK_PKG_INSTALL_STATUS=0
export MOCK_PKG_INSTALL_STATUS

unset PREFIX
if sillytavern_install_environment_is_supported; then
    fail "普通环境被误判为 Termux"
fi
PREFIX="/data/data/com.termux/files/usr"
uname() {
    case "${1:-}" in
        -o) printf '%s\n' 'Android' ;;
        -m) printf '%s\n' 'aarch64' ;;
        *) command uname "$@" ;;
    esac
}
sillytavern_install_environment_is_supported || fail "模拟 Termux 环境未通过检测"

ST_INSTALL_DEPENDENCY_COMMANDS=(test_broken_command)
ST_INSTALL_DEPENDENCY_PACKAGES=(broken-package)
ST_INSTALL_DEPENDENCY_ARGUMENTS=(--version)
broken_flow_output_file="$TEST_TMP_ROOT/broken-flow.log"
if sillytavern_install_interactive > "$broken_flow_output_file" 2>&1; then
    fail "损坏依赖场景仍继续安装"
fi
broken_flow_output="$(< "$broken_flow_output_file")"
[[ "$broken_flow_output" == *"pkg reinstall broken-package"* ]] || fail "损坏依赖缺少明确修复建议"
[[ "$broken_flow_output" == *"不会自动执行系统升级"* ]] || fail "损坏依赖提示未说明禁止自动升级"

target_root="$TEST_TMP_ROOT/targets"
mkdir -p -- "$target_root"
missing_target="$target_root/missing"
empty_target="$target_root/empty"
occupied_target="$target_root/occupied"
incomplete_target="$target_root/incomplete"
valid_target="$target_root/valid"
mkdir -p -- "$empty_target" "$occupied_target" "$incomplete_target"
printf '%s\n' 'ordinary data' > "$occupied_target/file.txt"
printf '%s\n' '{"name":"sillytavern"}' > "$incomplete_target/package.json"
create_valid_install "$valid_target" || fail "无法创建有效安装 Fixture"

[[ "$(sillytavern_install_classify_target "$missing_target")" == "missing" ]] || fail "不存在目录分类错误"
[[ "$(sillytavern_install_classify_target "$empty_target")" == "empty" ]] || fail "空目录分类错误"
[[ "$(sillytavern_install_classify_target "$occupied_target")" == "occupied" ]] || fail "普通非空目录分类错误"
[[ "$(sillytavern_install_classify_target "$incomplete_target")" == "incomplete" ]] || fail "不完整安装分类错误"
[[ "$(sillytavern_install_classify_target "$valid_target")" == "valid" ]] || fail "有效安装分类错误"
if sillytavern_install_normalize_target "/" >/dev/null 2>&1; then
    fail "根目录被接受为安装目标"
fi
if sillytavern_install_normalize_target "$HOME" >/dev/null 2>&1; then
    fail "HOME 被接受为安装目标"
fi
if sillytavern_install_normalize_target "$STERMUX_ROOT" >/dev/null 2>&1; then
    fail "STermux 自身目录被接受为安装目标"
fi

prompt_output_file="$TEST_TMP_ROOT/prompt-output.log"
sillytavern_install_prompt_target <<< "$valid_target"$'\n\n' > "$prompt_output_file" 2>&1 \
    || fail "有效安装未允许直接使用"
existing_prompt_output="$(< "$prompt_output_file")"
[[ "$ST_INSTALL_USED_EXISTING" == true ]] || fail "有效安装未标记为使用现有路径"
expected_valid_target="$(path_canonicalize_directory "$valid_target")" || fail "无法规范化有效安装路径"
[[ "$ST_PATH" == "$expected_valid_target" ]] || fail "有效安装路径未保存：$ST_PATH != $expected_valid_target"

if sillytavern_install_prompt_target <<< "$occupied_target"$'\n0\n' > "$prompt_output_file" 2>&1; then
    fail "普通非空目录冲突流程意外成功"
fi
conflict_output="$(< "$prompt_output_file")"
[[ "$conflict_output" == *"不会覆盖"* ]] || fail "普通非空目录冲突缺少明确提示"

source_repo="$TEST_TMP_ROOT/source-repo"
git_quiet init "$source_repo" || fail "无法创建本地安装源仓库"
git -C "$source_repo" config user.name "STermux Test"
git -C "$source_repo" config user.email "stermux-test@example.invalid"
git_quiet -C "$source_repo" checkout -b release || fail "无法创建 release 分支"
create_valid_install "$source_repo" || fail "无法创建本地 SillyTavern 源 Fixture"
git_quiet -C "$source_repo" add start.sh server.js package.json || fail "无法暂存本地安装源"
git_quiet -C "$source_repo" commit -m "fixture" || fail "无法提交本地安装源"

ST_INSTALL_REPOSITORY_URL="$source_repo"
ST_INSTALL_BRANCH="release"
successful_target="$target_root/installed"
timeout_called_marker="$TEST_TMP_ROOT/timeout-called"
timeout() {
    printf '%s\n' 'CALLED' > "$timeout_called_marker"
    return 124
}
clone_output_file="$TEST_TMP_ROOT/clone-output.log"
sillytavern_install_execute "$successful_target" "install" > "$clone_output_file" 2>&1 \
    || fail "本地仓库模拟安装失败：$ST_INSTALL_LAST_ERROR"
[[ ! -e "$timeout_called_marker" ]] || fail "clone 仍调用固定总时长 timeout"
grep -Fq 'Cloning into' "$clone_output_file" || fail "clone 进度未显示到调用终端"
grep -Fq 'Cloning into' "$(sillytavern_install_log_file)" || fail "clone 进度未同步写入安装日志"
sillytavern_path_is_valid "$successful_target" || fail "模拟安装成功后结构无效"
expected_successful_target="$(path_canonicalize_directory "$successful_target")" || fail "无法规范化模拟安装路径"
[[ "$ST_PATH" == "$expected_successful_target" ]] || fail "模拟安装成功后未更新 ST_PATH"
grep -Eq '^ST_PATH=' "$STERMUX_ROOT/config/user.conf" || fail "模拟安装成功后未保存 ST_PATH"
[[ "$(git -C "$successful_target" branch --show-current)" == "release" ]] \
    || fail "模拟安装未使用 release 分支"

replacement_target="$target_root/replacement"
mkdir -p -- "$replacement_target"
printf '%s\n' '{"name":"sillytavern"}' > "$replacement_target/package.json"
sillytavern_install_execute "$replacement_target" "preserve_incomplete" >/dev/null 2>&1 \
    || fail "保留不完整目录的重新安装失败：$ST_INSTALL_LAST_ERROR"
sillytavern_path_is_valid "$replacement_target" || fail "重新安装后的目标无效"
[[ -n "$ST_INSTALL_LAST_BACKUP_PATH" && -d "$ST_INSTALL_LAST_BACKUP_PATH" ]] \
    || fail "原不完整目录未被改名保留"
[[ -f "$ST_INSTALL_LAST_BACKUP_PATH/package.json" ]] || fail "保留的不完整目录内容丢失"

saved_config_before="$(< "$STERMUX_ROOT/config/user.conf")"
failed_target="$target_root/failed"
ST_INSTALL_REPOSITORY_URL="$TEST_TMP_ROOT/missing-offline-repository"
if sillytavern_install_execute "$failed_target" "install" > "$clone_output_file" 2>&1; then
    fail "不存在的本地源仓库安装意外成功"
fi
[[ -s "$clone_output_file" ]] || fail "clone 失败输出被完全吞掉"
[[ ! -e "$failed_target" ]] || fail "安装失败后创建了目标安装目录"
[[ "$(< "$STERMUX_ROOT/config/user.conf")" == "$saved_config_before" ]] \
    || fail "安装失败时修改了已保存的 ST_PATH"
[[ -n "$ST_INSTALL_LAST_STAGING_PATH" ]] || fail "安装失败未保留诊断目录位置"
[[ "$(basename -- "$ST_INSTALL_LAST_STAGING_PATH")" == .stermux-sillytavern-install.* ]] \
    || fail "安装失败诊断目录不再使用隐藏临时目录"
[[ "$(dirname -- "$ST_INSTALL_LAST_STAGING_PATH")" == "$target_root" ]] \
    || fail "安装失败诊断目录离开了目标父目录"
if sillytavern_path_is_valid "$ST_INSTALL_LAST_STAGING_PATH"; then
    fail "失败临时目录被误识别为完整安装"
fi

save_failure_target="$target_root/save-failure"
ST_INSTALL_REPOSITORY_URL="$source_repo"
if (
    config_set_value() { return 1; }
    if sillytavern_install_execute "$save_failure_target" "install" >/dev/null 2>&1; then
        exit 1
    fi
    sillytavern_path_is_valid "$save_failure_target"
); then
    :
else
    fail "路径保存失败场景未保留可诊断的有效安装"
fi
if grep -Fq "$save_failure_target" "$STERMUX_ROOT/config/user.conf"; then
    fail "路径保存失败时仍写入了 ST_PATH"
fi

printf '%s\n' 'PASS: 安装入口依赖三态、目录安全、离线成功/失败与路径保存测试通过'
