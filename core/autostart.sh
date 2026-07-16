#!/usr/bin/env bash

AUTOSTART_BEGIN_MARKER='# >>> STermux autostart >>>'
AUTOSTART_END_MARKER='# <<< STermux autostart <<<'
AUTOSTART_LAST_ERROR=""
AUTOSTART_LAST_BACKUP=""
AUTOSTART_STATUS="unknown"
AUTOSTART_SHELL_NAME=""

autostart_detect_shell() {
    local shell_path="${STERMUX_AUTOSTART_SHELL:-${SHELL:-}}"

    if [[ -n "$shell_path" ]]; then
        AUTOSTART_SHELL_NAME="$(basename -- "$shell_path")"
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        AUTOSTART_SHELL_NAME="bash"
    else
        AUTOSTART_SHELL_NAME="unknown"
    fi

    case "$AUTOSTART_SHELL_NAME" in
        bash)
            return 0
            ;;
        zsh)
            AUTOSTART_LAST_ERROR="检测到 Zsh；当前版本仅支持 Bash，未修改任何 Shell 配置"
            return 1
            ;;
        *)
            AUTOSTART_LAST_ERROR="当前 Shell 不受支持：$AUTOSTART_SHELL_NAME；未修改任何 Shell 配置"
            return 1
            ;;
    esac
}

autostart_rc_file() {
    if [[ -n "${STERMUX_AUTOSTART_RC_FILE:-}" ]]; then
        printf '%s\n' "$STERMUX_AUTOSTART_RC_FILE"
    else
        printf '%s\n' "$HOME/.bashrc"
    fi
}

autostart_write_without_managed_blocks() {
    local source_file="$1"
    local destination_file="$2"
    local line
    local inside=false

    : > "$destination_file" || return 1
    [[ -f "$source_file" ]] || return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$AUTOSTART_BEGIN_MARKER" ]]; then
            [[ "$inside" == false ]] || return 1
            inside=true
            continue
        fi
        if [[ "$line" == "$AUTOSTART_END_MARKER" ]]; then
            [[ "$inside" == true ]] || return 1
            inside=false
            continue
        fi
        [[ "$inside" == true ]] || printf '%s\n' "$line" >> "$destination_file" || return 1
    done < "$source_file"

    [[ "$inside" == false ]]
}

autostart_append_managed_block() {
    local destination_file="$1"
    local manager_path="$STERMUX_ROOT/manager.sh"
    local quoted_manager

    printf -v quoted_manager '%q' "$manager_path"
    {
        printf '%s\n' "$AUTOSTART_BEGIN_MARKER"
        printf 'if [[ $- == *i* ]] && [[ -z "${STERMUX_AUTOSTART_ACTIVE:-}" ]] && [[ -f %s ]]; then\n' \
            "$quoted_manager"
        printf '    export STERMUX_AUTOSTART_ACTIVE=1\n'
        printf '    bash %s\n' "$quoted_manager"
        printf '    unset STERMUX_AUTOSTART_ACTIVE\n'
        printf 'fi\n'
        printf '%s\n' "$AUTOSTART_END_MARKER"
    } >> "$destination_file"
}

autostart_temp_path_is_safe() {
    local temporary_file="$1"
    local rc_file="$2"
    local temporary_parent
    local rc_parent
    local expected_prefix

    [[ -n "$temporary_file" && -f "$temporary_file" && ! -L "$temporary_file" ]] || return 1
    temporary_parent="$(path_canonicalize_directory "$(dirname -- "$temporary_file")")" || return 1
    rc_parent="$(path_canonicalize_directory "$(dirname -- "$rc_file")")" || return 1
    expected_prefix="$(basename -- "$rc_file").stermux.tmp."
    [[ "$temporary_parent" == "$rc_parent" \
        && "$(basename -- "$temporary_file")" == "$expected_prefix"* ]]
}

autostart_temp_remove() {
    local temporary_file="$1"
    local rc_file="$2"

    [[ -e "$temporary_file" ]] || return 0
    autostart_temp_path_is_safe "$temporary_file" "$rc_file" || return 1
    rm -f -- "$temporary_file"
}

autostart_commit_file() {
    local rc_file="$1"
    local temporary_file="$2"
    local backup_file

    AUTOSTART_LAST_BACKUP=""
    if [[ -f "$rc_file" ]] && cmp -s -- "$rc_file" "$temporary_file"; then
        autostart_temp_remove "$temporary_file" "$rc_file"
        return $?
    fi
    if [[ -f "$rc_file" ]]; then
        backup_file="$(mktemp "$rc_file.stermux.bak.$(date '+%Y%m%d%H%M%S').XXXXXX")" || {
            AUTOSTART_LAST_ERROR="无法创建 Shell 配置备份文件"
            return 1
        }
        cp -p -- "$rc_file" "$backup_file" || {
            AUTOSTART_LAST_ERROR="无法备份现有 Shell 配置：$rc_file"
            return 1
        }
        chmod --reference="$rc_file" "$temporary_file" 2>/dev/null || true
        AUTOSTART_LAST_BACKUP="$backup_file"
    fi
    mv -- "$temporary_file" "$rc_file" || {
        AUTOSTART_LAST_ERROR="无法写入 Shell 配置：$rc_file"
        return 1
    }
}

autostart_prepare_change() {
    local rc_file="$1"

    [[ -n "${HOME:-}" && -d "$HOME" ]] || {
        AUTOSTART_LAST_ERROR="HOME 目录不存在，无法管理 Shell 配置"
        return 1
    }
    [[ -d "$(dirname -- "$rc_file")" ]] || {
        AUTOSTART_LAST_ERROR="Shell 配置目录不存在：$(dirname -- "$rc_file")"
        return 1
    }
    [[ ! -L "$rc_file" ]] || {
        AUTOSTART_LAST_ERROR="Shell 配置文件是符号链接，为避免误改已停止：$rc_file"
        return 1
    }
    if [[ -e "$rc_file" && ( ! -f "$rc_file" || ! -r "$rc_file" ) ]]; then
        AUTOSTART_LAST_ERROR="Shell 配置文件不可安全读取：$rc_file"
        return 1
    fi
}

autostart_enable() {
    local rc_file
    local temporary_file

    AUTOSTART_LAST_ERROR=""
    autostart_detect_shell || return 1
    rc_file="$(autostart_rc_file)"
    autostart_prepare_change "$rc_file" || return 1
    temporary_file="$rc_file.stermux.tmp.$$.$RANDOM"
    [[ ! -e "$temporary_file" ]] || {
        AUTOSTART_LAST_ERROR="Shell 配置临时文件已存在"
        return 1
    }
    if ! autostart_write_without_managed_blocks "$rc_file" "$temporary_file"; then
        AUTOSTART_LAST_ERROR="STermux 自动进入托管标记不完整，已保留原配置"
        autostart_temp_remove "$temporary_file" "$rc_file" || true
        return 1
    fi
    if ! autostart_append_managed_block "$temporary_file"; then
        AUTOSTART_LAST_ERROR="无法生成 STermux 自动进入配置"
        autostart_temp_remove "$temporary_file" "$rc_file" || true
        return 1
    fi
    autostart_commit_file "$rc_file" "$temporary_file" || {
        autostart_temp_remove "$temporary_file" "$rc_file" || true
        return 1
    }
}

autostart_disable() {
    local rc_file
    local temporary_file

    AUTOSTART_LAST_ERROR=""
    autostart_detect_shell || return 1
    rc_file="$(autostart_rc_file)"
    autostart_prepare_change "$rc_file" || return 1
    [[ -e "$rc_file" ]] || return 0
    temporary_file="$rc_file.stermux.tmp.$$.$RANDOM"
    [[ ! -e "$temporary_file" ]] || {
        AUTOSTART_LAST_ERROR="Shell 配置临时文件已存在"
        return 1
    }
    if ! autostart_write_without_managed_blocks "$rc_file" "$temporary_file"; then
        AUTOSTART_LAST_ERROR="STermux 自动进入托管标记不完整，已保留原配置"
        autostart_temp_remove "$temporary_file" "$rc_file" || true
        return 1
    fi
    autostart_commit_file "$rc_file" "$temporary_file" || {
        autostart_temp_remove "$temporary_file" "$rc_file" || true
        return 1
    }
}

autostart_status() {
    local rc_file
    local line
    local inside=false
    local blocks=0

    AUTOSTART_LAST_ERROR=""
    if ! autostart_detect_shell; then
        AUTOSTART_STATUS="unsupported"
        return 1
    fi
    rc_file="$(autostart_rc_file)"
    if [[ ! -e "$rc_file" ]]; then
        AUTOSTART_STATUS="disabled"
        return 0
    fi
    if [[ ! -f "$rc_file" || ! -r "$rc_file" || -L "$rc_file" ]]; then
        AUTOSTART_STATUS="error"
        AUTOSTART_LAST_ERROR="Shell 配置文件无法安全读取：$rc_file"
        return 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$AUTOSTART_BEGIN_MARKER" ]]; then
            [[ "$inside" == false ]] || {
                AUTOSTART_STATUS="error"
                AUTOSTART_LAST_ERROR="自动进入托管标记发生嵌套"
                return 1
            }
            inside=true
        elif [[ "$line" == "$AUTOSTART_END_MARKER" ]]; then
            [[ "$inside" == true ]] || {
                AUTOSTART_STATUS="error"
                AUTOSTART_LAST_ERROR="自动进入托管结束标记缺少起始标记"
                return 1
            }
            inside=false
            blocks=$((blocks + 1))
        fi
    done < "$rc_file"
    if [[ "$inside" == true ]]; then
        AUTOSTART_STATUS="error"
        AUTOSTART_LAST_ERROR="自动进入托管起始标记缺少结束标记"
        return 1
    fi
    if (( blocks > 0 )); then
        AUTOSTART_STATUS="enabled"
    else
        AUTOSTART_STATUS="disabled"
    fi
}

autostart_status_text() {
    autostart_status >/dev/null 2>&1 || true
    case "$AUTOSTART_STATUS" in
        enabled) printf '%s\n' "已开启（Bash）" ;;
        disabled) printf '%s\n' "已关闭（Bash）" ;;
        unsupported) printf '%s\n' "不支持（$AUTOSTART_SHELL_NAME）" ;;
        error) printf '%s\n' "配置异常" ;;
        *) printf '%s\n' "未知" ;;
    esac
}
