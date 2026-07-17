#!/usr/bin/env bash

stermux_version_read() {
    local version_file="$STERMUX_ROOT/VERSION"
    local version

    if [[ ! -r "$version_file" ]]; then
        printf '%s\n' "unknown"
        return 0
    fi

    IFS= read -r version < "$version_file" || true
    version="${version%$'\r'}"
    if [[ "$version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
        printf '%s\n' "$version"
    else
        printf '%s\n' "unknown"
    fi
}

stermux_version_display() {
    local version="${1:-$(stermux_version_read)}"

    if [[ -z "$version" || "$version" == "unknown" ]]; then
        printf '%s\n' "版本未知"
    else
        printf '%s\n' "$version"
    fi
}
