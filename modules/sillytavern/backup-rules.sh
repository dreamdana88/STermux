#!/usr/bin/env bash

BACKUP_SOURCE_DATA_DIR=""
BACKUP_SOURCE_CONFIG_FILE=""
BACKUP_SOURCE_THIRD_PARTY_DIR=""
BACKUP_SOURCE_THIRD_PARTY_STATUS="missing"

sillytavern_backup_third_party_path() {
    printf '%s\n' "$ST_PATH/public/scripts/extensions/third-party"
}

sillytavern_backup_resolve_source() {
    local config_file="$ST_PATH/config.yaml"
    local data_root_line
    local data_root_value
    local third_party_dir
    local extensions_parent
    local st_canonical
    local parent_canonical

    BACKUP_SOURCE_DATA_DIR=""
    BACKUP_SOURCE_CONFIG_FILE=""
    BACKUP_SOURCE_THIRD_PARTY_DIR=""
    BACKUP_SOURCE_THIRD_PARTY_STATUS="missing"
    sillytavern_path_is_valid "$ST_PATH" || {
        BACKUP_LAST_ERROR="当前 SillyTavern 路径无效"
        return 1
    }
    [[ -r "$config_file" && ! -L "$config_file" ]] || {
        BACKUP_LAST_ERROR="缺少可读取的 SillyTavern config.yaml"
        return 1
    }

    data_root_line="$(grep -E '^[[:space:]]*dataRoot[[:space:]]*:' "$config_file" | head -n 1)"
    if [[ -n "$data_root_line" ]]; then
        data_root_value="${data_root_line#*:}"
        data_root_value="${data_root_value%%#*}"
        data_root_value="${data_root_value#${data_root_value%%[![:space:]]*}}"
        data_root_value="${data_root_value%${data_root_value##*[![:space:]]}}"
        if (( ${#data_root_value} >= 2 )); then
            if [[ "${data_root_value:0:1}" == '"' && "${data_root_value: -1}" == '"' ]] \
                || [[ "${data_root_value:0:1}" == "'" && "${data_root_value: -1}" == "'" ]]; then
                data_root_value="${data_root_value:1:${#data_root_value}-2}"
            fi
        fi
        case "$data_root_value" in
            data|./data|"")
                ;;
            *)
                BACKUP_LAST_ERROR="检测到自定义 dataRoot：$data_root_value；Phase 4 为避免漏备份暂不继续"
                return 1
                ;;
        esac
    fi

    [[ -d "$ST_PATH/data" && -r "$ST_PATH/data" && ! -L "$ST_PATH/data" ]] || {
        BACKUP_LAST_ERROR="SillyTavern 默认 data 目录不存在或无法读取"
        return 1
    }
    BACKUP_SOURCE_DATA_DIR="$ST_PATH/data"
    BACKUP_SOURCE_CONFIG_FILE="$config_file"

    third_party_dir="$(sillytavern_backup_third_party_path)"
    extensions_parent="$(dirname -- "$third_party_dir")"
    if [[ -L "$ST_PATH/public" || -L "$ST_PATH/public/scripts" \
        || -L "$extensions_parent" || -L "$third_party_dir" ]]; then
        BACKUP_LAST_ERROR="third-party 路径或其父目录不得是符号链接"
        return 1
    fi
    if [[ -d "$extensions_parent" ]]; then
        st_canonical="$(path_canonicalize_directory "$ST_PATH")" || return 1
        parent_canonical="$(path_canonicalize_directory "$extensions_parent")" || return 1
        [[ "$parent_canonical" == "$st_canonical/"* ]] || {
            BACKUP_LAST_ERROR="third-party 父目录越出 SillyTavern 安装目录"
            return 1
        }
    fi
    if [[ -d "$third_party_dir" ]]; then
        [[ -r "$third_party_dir" ]] || {
            BACKUP_LAST_ERROR="SillyTavern third-party 目录存在但无法读取"
            return 1
        }
        BACKUP_SOURCE_THIRD_PARTY_DIR="$third_party_dir"
        BACKUP_SOURCE_THIRD_PARTY_STATUS="present"
    elif [[ -e "$third_party_dir" ]]; then
        BACKUP_LAST_ERROR="SillyTavern third-party 路径存在但不是目录"
        return 1
    fi
    return 0
}
