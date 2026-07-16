#!/usr/bin/env bash

# 当前依赖与安装方式依据 SillyTavern 官方 Android (Termux) 文档：
# https://docs.sillytavern.app/installation/android-%28termux%29/
ST_INSTALL_REPOSITORY_URL="${ST_INSTALL_REPOSITORY_URL:-https://github.com/SillyTavern/SillyTavern}"
ST_INSTALL_BRANCH="${ST_INSTALL_BRANCH:-release}"
ST_INSTALL_LAST_ERROR=""
ST_INSTALL_LAST_OUTPUT=""
ST_INSTALL_LAST_STAGING_PATH=""
ST_INSTALL_LAST_BACKUP_PATH=""
ST_INSTALL_TARGET=""
ST_INSTALL_TARGET_ACTION=""
ST_INSTALL_USED_EXISTING=false
ST_INSTALL_DEPENDENCY_STATUS="unknown"
ST_INSTALL_DEPENDENCY_OUTPUT=""
ST_INSTALL_MISSING_PACKAGES=()
ST_INSTALL_BROKEN_DEPENDENCIES=()
ST_INSTALL_BROKEN_PACKAGES=()

ST_INSTALL_DEPENDENCY_COMMANDS=(git node npm nano)
ST_INSTALL_DEPENDENCY_PACKAGES=(git nodejs-lts nodejs-lts nano)
ST_INSTALL_DEPENDENCY_ARGUMENTS=(--version --version --version --version)

sillytavern_install_log_file() {
    printf '%s\n' "$STERMUX_ROOT/data/logs/sillytavern-install.log"
}

sillytavern_install_log() {
    local message="$1"
    local log_file

    log_file="$(sillytavern_install_log_file)"
    mkdir -p -- "$(dirname -- "$log_file")" 2>/dev/null || return 1
    printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$message" >> "$log_file"
}

sillytavern_install_set_error() {
    ST_INSTALL_LAST_ERROR="$1"
    sillytavern_install_log "ERROR | $ST_INSTALL_LAST_ERROR" || true
}

sillytavern_install_run_logged() {
    local description="$1"
    shift
    local log_file
    local status

    ST_INSTALL_LAST_OUTPUT=""
    sillytavern_install_log "STEP | $description" || true
    log_file="$(sillytavern_install_log_file)"

    if command -v tee >/dev/null 2>&1 && mkdir -p -- "$(dirname -- "$log_file")" 2>/dev/null; then
        "$@" 2>&1 | tee -a "$log_file"
        status=${PIPESTATUS[0]}
    else
        "$@" 2>&1
        status=$?
    fi
    sillytavern_install_log "RESULT | $description | exit=$status" || true
    return "$status"
}

sillytavern_install_clone_repository() {
    local staging="$1"

    GIT_TERMINAL_PROMPT=0 git clone \
        --progress \
        --branch "$ST_INSTALL_BRANCH" \
        --single-branch \
        "$ST_INSTALL_REPOSITORY_URL" \
        "$staging"
}

sillytavern_install_environment_is_supported() {
    local os_name

    [[ "${PREFIX:-}" == /data/data/*/files/usr ]] || return 1
    os_name="$(uname -o 2>/dev/null)" || return 1
    [[ "$os_name" == "Android" ]]
}

sillytavern_dependency_probe() {
    local command_name="$1"
    shift
    local output
    local status

    ST_INSTALL_DEPENDENCY_STATUS="missing"
    ST_INSTALL_DEPENDENCY_OUTPUT=""

    if ! command -v "$command_name" >/dev/null 2>&1; then
        return 1
    fi

    output="$("$command_name" "$@" 2>&1)"
    status=$?
    ST_INSTALL_DEPENDENCY_OUTPUT="$output"
    if (( status != 0 )); then
        ST_INSTALL_DEPENDENCY_STATUS="broken"
        return 2
    fi

    ST_INSTALL_DEPENDENCY_STATUS="ready"
    return 0
}

sillytavern_install_is_32_bit() {
    local machine

    machine="$(uname -m 2>/dev/null)" || return 1
    case "$machine" in
        armv5*|armv6*|armv7*|i386|i486|i586|i686|x86)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

sillytavern_install_add_missing_package() {
    local package_name="$1"
    local existing

    for existing in "${ST_INSTALL_MISSING_PACKAGES[@]:-}"; do
        [[ "$existing" == "$package_name" ]] && return 0
    done
    ST_INSTALL_MISSING_PACKAGES+=("$package_name")
}

sillytavern_install_check_one_dependency() {
    local command_name="$1"
    local package_name="$2"
    local version_argument="$3"
    local probe_status
    local summary

    sillytavern_dependency_probe "$command_name" "$version_argument"
    probe_status=$?
    case "$probe_status" in
        0)
            summary="${ST_INSTALL_DEPENDENCY_OUTPUT%%$'\n'*}"
            ui_success "$command_name 可正常运行${summary:+：$summary}"
            ;;
        1)
            ui_warning "$command_name 未安装（软件包：$package_name）"
            sillytavern_install_add_missing_package "$package_name"
            ;;
        2)
            summary="${ST_INSTALL_DEPENDENCY_OUTPUT%%$'\n'*}"
            [[ -n "$summary" ]] || summary="命令退出状态异常"
            ui_error "$command_name 已存在但无法运行：$summary"
            ST_INSTALL_BROKEN_DEPENDENCIES+=("$command_name：$summary")
            ST_INSTALL_BROKEN_PACKAGES+=("$package_name")
            ;;
    esac
}

sillytavern_install_check_dependencies() {
    local index

    ST_INSTALL_MISSING_PACKAGES=()
    ST_INSTALL_BROKEN_DEPENDENCIES=()
    ST_INSTALL_BROKEN_PACKAGES=()

    for ((index = 0; index < ${#ST_INSTALL_DEPENDENCY_COMMANDS[@]}; index++)); do
        sillytavern_install_check_one_dependency \
            "${ST_INSTALL_DEPENDENCY_COMMANDS[index]}" \
            "${ST_INSTALL_DEPENDENCY_PACKAGES[index]}" \
            "${ST_INSTALL_DEPENDENCY_ARGUMENTS[index]}"
    done

    if sillytavern_install_is_32_bit; then
        sillytavern_install_check_one_dependency "esbuild" "esbuild" "--version"
    fi

    if (( ${#ST_INSTALL_BROKEN_DEPENDENCIES[@]} > 0 )); then
        return 2
    fi
    if (( ${#ST_INSTALL_MISSING_PACKAGES[@]} > 0 )); then
        return 1
    fi
    return 0
}

sillytavern_install_check_package_manager() {
    sillytavern_dependency_probe "pkg" "list-installed" "termux-tools"
    case "$?" in
        0)
            return 0
            ;;
        1)
            sillytavern_install_set_error "未找到 Termux 软件包管理命令 pkg。"
            ;;
        2)
            sillytavern_install_set_error \
                "pkg 命令存在但无法运行：${ST_INSTALL_DEPENDENCY_OUTPUT%%$'\n'*}"
            ;;
    esac
    return 1
}

sillytavern_install_missing_dependencies() {
    if (( ${#ST_INSTALL_MISSING_PACKAGES[@]} == 0 )); then
        return 0
    fi
    if ! sillytavern_install_check_package_manager; then
        return 1
    fi

    ui_info "正在安装必要软件包：${ST_INSTALL_MISSING_PACKAGES[*]}"
    ui_info "STermux 不会自动执行 pkg upgrade。"
    if ! sillytavern_install_run_logged \
        "安装必要 Termux 软件包" \
        pkg install -y "${ST_INSTALL_MISSING_PACKAGES[@]}"; then
        sillytavern_install_set_error "必要依赖安装失败。请检查上方 pkg 输出和安装日志。"
        return 1
    fi

    ui_info "正在重新验证依赖..."
    if ! sillytavern_install_check_dependencies; then
        sillytavern_install_set_error "软件包安装结束，但必要命令仍未全部正常工作。"
        return 1
    fi
    return 0
}

sillytavern_install_normalize_target() {
    local input="$1"
    local normalized
    local parent
    local parent_canonical
    local base_name
    local target

    normalized="$(path_normalize_input "$input")"
    [[ -n "$normalized" && "$normalized" == /* ]] || return 1
    case "$normalized" in
        /|"${HOME:-}"|"${PREFIX:-}"|"$STERMUX_ROOT"|"$STERMUX_ROOT"/*)
            return 1
            ;;
    esac

    parent="$(dirname -- "$normalized")"
    base_name="$(basename -- "$normalized")"
    [[ "$base_name" != "." && "$base_name" != ".." ]] || return 1
    parent_canonical="$(path_canonicalize_directory "$parent")" || return 1
    target="$parent_canonical/$base_name"

    case "$target" in
        /|"${HOME:-}"|"${PREFIX:-}"|"$STERMUX_ROOT"|"$STERMUX_ROOT"/*)
            return 1
            ;;
    esac

    printf '%s\n' "$target"
}

sillytavern_install_classify_target() {
    local target="$1"

    if [[ ! -e "$target" && ! -L "$target" ]]; then
        printf '%s\n' "missing"
        return 0
    fi
    if sillytavern_path_is_valid "$target"; then
        printf '%s\n' "valid"
        return 0
    fi
    if [[ -L "$target" || ! -d "$target" ]]; then
        printf '%s\n' "occupied"
        return 0
    fi
    if [[ -z "$(find "$target" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        printf '%s\n' "empty"
        return 0
    fi
    if [[ -e "$target/.git" || -e "$target/package.json" || -e "$target/server.js" || -e "$target/start.sh" ]]; then
        printf '%s\n' "incomplete"
        return 0
    fi
    printf '%s\n' "occupied"
}

sillytavern_install_save_path() {
    local target="$1"

    if declare -F set_sillytavern_path >/dev/null 2>&1; then
        set_sillytavern_path "$target"
        return $?
    fi

    ST_PATH="$(path_canonicalize_directory "$target")" || return 1
    config_set_value "ST_PATH" "$ST_PATH"
}

sillytavern_install_finalize_staging() {
    local staging="$1"
    local target="$2"
    local action="$3"
    local target_state
    local backup_path
    local removed_empty=false

    target_state="$(sillytavern_install_classify_target "$target")"
    case "$action:$target_state" in
        install:missing)
            ;;
        install:empty)
            if ! rmdir -- "$target"; then
                sillytavern_install_set_error "目标空目录在安装期间发生变化，已停止写入：$target"
                return 1
            fi
            removed_empty=true
            ;;
        preserve_incomplete:incomplete)
            backup_path="$target.incomplete-$(date '+%Y%m%d-%H%M%S')"
            if [[ -e "$backup_path" || -L "$backup_path" ]]; then
                sillytavern_install_set_error "无法生成不完整安装的保留目录：$backup_path"
                return 1
            fi
            if ! mv -- "$target" "$backup_path"; then
                sillytavern_install_set_error "无法保留原有不完整安装：$target"
                return 1
            fi
            ST_INSTALL_LAST_BACKUP_PATH="$backup_path"
            ;;
        *)
            sillytavern_install_set_error "目标目录状态在安装期间发生变化，未覆盖任何内容：$target"
            return 1
            ;;
    esac

    if ! mv -- "$staging" "$target"; then
        if [[ -n "$ST_INSTALL_LAST_BACKUP_PATH" && ! -e "$target" ]]; then
            mv -- "$ST_INSTALL_LAST_BACKUP_PATH" "$target" 2>/dev/null || true
            ST_INSTALL_LAST_BACKUP_PATH=""
        elif [[ "$removed_empty" == true && ! -e "$target" ]]; then
            mkdir -- "$target" 2>/dev/null || true
        fi
        sillytavern_install_set_error "安装文件无法移动到目标目录：$target"
        return 1
    fi
    ST_INSTALL_LAST_STAGING_PATH=""
    return 0
}

sillytavern_install_execute() {
    local target="$1"
    local action="${2:-install}"
    local parent
    local staging
    local clone_status

    ST_INSTALL_LAST_ERROR=""
    ST_INSTALL_LAST_OUTPUT=""
    ST_INSTALL_LAST_STAGING_PATH=""
    ST_INSTALL_LAST_BACKUP_PATH=""
    parent="$(dirname -- "$target")"

    staging="$(mktemp -d "$parent/.stermux-sillytavern-install.XXXXXX")" || {
        sillytavern_install_set_error "无法在目标位置创建安全的临时安装目录。"
        return 1
    }
    ST_INSTALL_LAST_STAGING_PATH="$staging"

    ui_info "正在获取 SillyTavern $ST_INSTALL_BRANCH 分支..."
    sillytavern_install_run_logged \
        "克隆 SillyTavern $ST_INSTALL_BRANCH 分支" \
        sillytavern_install_clone_repository "$staging"
    clone_status=$?
    if (( clone_status != 0 )); then
        if (( clone_status == 130 )); then
            sillytavern_install_set_error \
                "用户取消了 SillyTavern 下载。未完成内容保留在：$staging"
        else
            sillytavern_install_set_error \
                "下载 SillyTavern 失败。未完成内容保留在：$staging"
        fi
        return 1
    fi

    ui_info "正在验证 SillyTavern 安装结构..."
    if ! sillytavern_path_is_valid "$staging"; then
        sillytavern_install_set_error \
            "下载内容不是完整的 SillyTavern 安装。诊断目录：$staging"
        return 1
    fi

    if ! sillytavern_install_finalize_staging "$staging" "$target" "$action"; then
        return 1
    fi
    if ! sillytavern_path_is_valid "$target"; then
        sillytavern_install_set_error "安装移动完成，但最终结构验证失败：$target"
        return 1
    fi
    if ! sillytavern_install_save_path "$target"; then
        sillytavern_install_set_error \
            "SillyTavern 已安装，但无法保存 ST_PATH。安装目录：$target"
        return 1
    fi

    sillytavern_install_log "SUCCESS | path=$ST_PATH | branch=$ST_INSTALL_BRANCH" || true
    return 0
}

sillytavern_install_prompt_target() {
    local input
    local target
    local state
    local choice
    local default_target="${HOME:-}/SillyTavern"

    ST_INSTALL_TARGET=""
    ST_INSTALL_TARGET_ACTION=""
    ST_INSTALL_USED_EXISTING=false

    while true; do
        printf '\n请输入安装目录（直接回车使用 %s，输入 0 取消）：\n> ' "$default_target"
        IFS= read -r input || return 1
        [[ "$input" != "0" ]] || return 1
        [[ -n "$input" ]] || input="$default_target"

        target="$(sillytavern_install_normalize_target "$input")" || {
            ui_error "安装目录必须是安全的绝对路径，且父目录需要已经存在。"
            continue
        }
        state="$(sillytavern_install_classify_target "$target")"
        case "$state" in
            missing|empty)
                ST_INSTALL_TARGET="$target"
                ST_INSTALL_TARGET_ACTION="install"
                return 0
                ;;
            valid)
                ui_info "该目录已经是有效的 SillyTavern 安装：$target"
                printf '直接使用并保存该路径？[Y/n] '
                IFS= read -r choice || return 1
                if [[ -z "$choice" || "$choice" == "y" || "$choice" == "Y" ]]; then
                    if sillytavern_install_save_path "$target"; then
                        ST_INSTALL_TARGET="$target"
                        ST_INSTALL_TARGET_ACTION="use_existing"
                        ST_INSTALL_USED_EXISTING=true
                        return 0
                    fi
                    ui_error "有效安装路径保存失败。"
                    return 1
                fi
                ;;
            incomplete)
                ui_warning "目标目录疑似为不完整的 SillyTavern 安装：$target"
                printf '%s\n' '1. 保留原目录并重新安装' '2. 选择其他目录' '0. 取消'
                printf '请选择操作：'
                IFS= read -r choice || return 1
                case "$choice" in
                    1)
                        ST_INSTALL_TARGET="$target"
                        ST_INSTALL_TARGET_ACTION="preserve_incomplete"
                        return 0
                        ;;
                    2) continue ;;
                    0) return 1 ;;
                    *) ui_warning "无效选项。" ;;
                esac
                ;;
            occupied)
                ui_error "目标位置已被普通文件、符号链接或非 SillyTavern 内容占用，不会覆盖：$target"
                ;;
        esac
    done
}

sillytavern_install_offer_first_launch() {
    local choice

    printf '\nSillyTavern 安装完成\n\n'
    printf '%s\n' '1. 立即启动' '2. 返回主菜单'
    printf '请选择操作：'
    IFS= read -r choice || return 0
    if [[ "$choice" == "1" ]]; then
        launch_sillytavern || true
    fi
}

sillytavern_install_interactive() {
    local dependency_status
    local confirm

    ST_INSTALL_LAST_ERROR=""
    ui_info "步骤 1/5：检查 Termux 运行环境。"
    if ! sillytavern_install_environment_is_supported; then
        ui_error "当前环境不是可识别的 Android Termux，已停止安装。"
        return 1
    fi

    ui_info "步骤 2/5：检查必要依赖是否真的可以运行。"
    sillytavern_install_check_dependencies
    dependency_status=$?
    if (( dependency_status == 2 )); then
        ui_error "检测到已存在但无法运行的依赖，已停止安装。"
        ui_info "请先修复 Termux 软件包。可尝试：pkg reinstall ${ST_INSTALL_BROKEN_PACKAGES[*]}"
        ui_info "若仍提示动态库缺失或版本不一致，请检查镜像后运行 pkg update，并由你确认是否执行 pkg upgrade。"
        ui_info "STermux 不会自动执行系统升级。诊断信息已显示在上方。"
        return 1
    fi
    if (( dependency_status == 1 )); then
        printf '是否安装缺失的软件包（%s）？[y/N] ' "${ST_INSTALL_MISSING_PACKAGES[*]}"
        IFS= read -r confirm || return 1
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            ui_info "已取消安装，不会修改 Termux 软件包。"
            return 1
        fi
        if ! sillytavern_install_missing_dependencies; then
            ui_error "$ST_INSTALL_LAST_ERROR"
            return 1
        fi
    fi

    ui_info "步骤 3/5：确认安装目录。"
    if ! sillytavern_install_prompt_target; then
        ui_info "已取消 SillyTavern 安装。"
        return 1
    fi
    if [[ "$ST_INSTALL_USED_EXISTING" == true ]]; then
        ui_success "已使用现有 SillyTavern 安装：$ST_PATH"
        return 0
    fi

    printf '\n将从官方仓库获取 %s 分支并安装到：\n%s\n' "$ST_INSTALL_BRANCH" "$ST_INSTALL_TARGET"
    printf '确认开始安装？[y/N] '
    IFS= read -r confirm || return 1
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        ui_info "已取消 SillyTavern 安装。"
        return 1
    fi

    ui_info "步骤 4/5：获取并验证 SillyTavern。"
    if ! sillytavern_install_execute "$ST_INSTALL_TARGET" "$ST_INSTALL_TARGET_ACTION"; then
        ui_error "$ST_INSTALL_LAST_ERROR"
        ui_info "安装日志：$(sillytavern_install_log_file)"
        return 1
    fi

    ui_info "步骤 5/5：保存路径并完成安装。"
    ui_success "SillyTavern 已安装：$ST_PATH"
    if [[ -n "$ST_INSTALL_LAST_BACKUP_PATH" ]]; then
        ui_info "原不完整目录已保留为：$ST_INSTALL_LAST_BACKUP_PATH"
    fi
    sillytavern_install_offer_first_launch
    return 0
}
