#!/usr/bin/env bash

config_load() {
    local default_config="$STERMUX_ROOT/config/default.conf"
    local user_config="$STERMUX_ROOT/config/user.conf"

    if [[ ! -r "$default_config" ]]; then
        printf '无法读取默认配置：%s\n' "$default_config" >&2
        return 1
    fi

    # shellcheck source=/dev/null
    source "$default_config" || return 1

    if [[ -e "$user_config" ]]; then
        if [[ ! -r "$user_config" ]]; then
            printf '无法读取用户配置：%s\n' "$user_config" >&2
            return 1
        fi

        # shellcheck source=/dev/null
        source "$user_config" || return 1
    fi

    return 0
}

config_set_value() {
    local key="$1"
    local value="$2"
    local user_config="$STERMUX_ROOT/config/user.conf"
    local temporary_config="$user_config.tmp.$$"
    local line
    local quoted_value
    local replaced=false

    case "$key" in
        ST_PATH|COLOR_ENABLED|AUTOMATIC_BACKUP_KEEP)
            ;;
        *)
            printf '拒绝保存未知配置项：%s\n' "$key" >&2
            return 1
            ;;
    esac

    printf -v quoted_value '%q' "$value"

    : > "$temporary_config" || {
        printf '无法创建临时配置文件：%s\n' "$temporary_config" >&2
        return 1
    }

    if [[ -f "$user_config" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "$key="* ]]; then
                if [[ "$replaced" == false ]]; then
                    printf '%s=%s\n' "$key" "$quoted_value" >> "$temporary_config" || return 1
                    replaced=true
                fi
            else
                printf '%s\n' "$line" >> "$temporary_config" || return 1
            fi
        done < "$user_config"
    fi

    if [[ "$replaced" == false ]]; then
        printf '%s=%s\n' "$key" "$quoted_value" >> "$temporary_config" || return 1
    fi

    if ! mv -- "$temporary_config" "$user_config"; then
        printf '无法写入用户配置：%s\n' "$user_config" >&2
        return 1
    fi

    return 0
}

config_remove_value() {
    local key="$1"
    local user_config="$STERMUX_ROOT/config/user.conf"
    local temporary_config="$user_config.tmp.$$"
    local line

    case "$key" in
        ST_PATH|COLOR_ENABLED|AUTOMATIC_BACKUP_KEEP)
            ;;
        *)
            printf '拒绝删除未知配置项：%s\n' "$key" >&2
            return 1
            ;;
    esac

    [[ -e "$user_config" ]] || return 0
    : > "$temporary_config" || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == "$key="* ]] || printf '%s\n' "$line" >> "$temporary_config" || return 1
    done < "$user_config"
    if ! mv -- "$temporary_config" "$user_config"; then
        rm -f -- "$temporary_config" 2>/dev/null || true
        return 1
    fi
}
