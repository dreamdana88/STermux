#!/usr/bin/env bash

path_normalize_input() {
    local path="${1:-}"

    if (( ${#path} >= 2 )); then
        if [[ "${path:0:1}" == '"' && "${path: -1}" == '"' ]]; then
            path="${path:1:${#path}-2}"
        elif [[ "${path:0:1}" == "'" && "${path: -1}" == "'" ]]; then
            path="${path:1:${#path}-2}"
        fi
    fi

    case "$path" in
        "~")
            path="${HOME:-}"
            ;;
        "~/"*)
            path="${HOME:-}/${path#\~/}"
            ;;
    esac

    while [[ "$path" != "/" && "$path" == */ ]]; do
        path="${path%/}"
    done

    printf '%s\n' "$path"
}

path_canonicalize_directory() {
    local path="${1:-}"

    [[ -d "$path" ]] || return 1
    (CDPATH= cd -- "$path" 2>/dev/null && pwd -P)
}

sillytavern_package_is_valid() {
    local package_file="$1"

    [[ -f "$package_file" ]] || return 1
    grep -Eiq '"name"[[:space:]]*:[[:space:]]*"sillytavern"' "$package_file"
}

sillytavern_path_is_valid() {
    local path="${1:-}"

    [[ -n "$path" ]] || return 1
    [[ -d "$path" ]] || return 1
    [[ -r "$path/start.sh" ]] || return 1
    [[ -f "$path/server.js" ]] || return 1
    sillytavern_package_is_valid "$path/package.json"
}

sillytavern_find_common_path() {
    local candidate
    local -a common_paths=()

    if [[ -n "${HOME:-}" ]]; then
        common_paths+=("$HOME/SillyTavern")
    fi

    for candidate in "${common_paths[@]}"; do
        if sillytavern_path_is_valid "$candidate"; then
            path_canonicalize_directory "$candidate"
            return 0
        fi
    done

    return 1
}
