#!/usr/bin/env bash

BACKUP_LAST_ERROR=""
BACKUP_LAST_PATH=""
BACKUP_SEQUENCE=0
BACKUP_DELETE_SUCCESS=0
BACKUP_DELETE_FAILED=0
BACKUP_DELETE_SKIPPED=0

declare -a BACKUP_IDS=()
declare -a BACKUP_PATHS=()
declare -a BACKUP_TIMES=()
declare -a BACKUP_EPOCHS=()
declare -a BACKUP_TYPES=()
declare -a BACKUP_SIZES=()
declare -a BACKUP_SELECTED_INDEXES=()
declare -a BACKUP_DELETE_FAILED_IDS=()
declare -a BACKUP_DELETE_FAILED_ERRORS=()

backup_current_epoch() { date '+%s'; }
backup_current_display_time() { date '+%Y-%m-%d %H:%M:%S %z'; }

backup_root_path() {
    printf '%s\n' "${BACKUP_ROOT:-$STERMUX_ROOT/backups/sillytavern}"
}

backup_log_file() { printf '%s\n' "$STERMUX_ROOT/data/logs/backup.log"; }

backup_one_line() {
    local value="${1:-}"
    value="${value//$'\r'/ }"
    value="${value//$'\n'/ }"
    value="${value//$'\t'/ }"
    printf '%s\n' "$value"
}

backup_log() {
    local action="$1"
    local result="$2"
    local backup_id="${3:-unknown}"
    local detail="${4:-}"
    local log_file

    log_file="$(backup_log_file)"
    mkdir -p -- "$(dirname -- "$log_file")" 2>/dev/null || return 1
    printf '%s\t%s\t%s\t%s\t%s\n' "$(backup_current_display_time)" \
        "$action" "$result" "$(backup_one_line "$backup_id")" \
        "$(backup_one_line "$detail")" >> "$log_file"
}

backup_type_is_valid() {
    case "$1" in manual|protective|scheduled|catchup) return 0 ;; *) return 1 ;; esac
}

backup_type_is_automatic() {
    case "$1" in protective|scheduled|catchup) return 0 ;; *) return 1 ;; esac
}

backup_metadata_get() {
    local file="$1"
    local key="$2"
    local line

    [[ -r "$file" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$key="* ]]; then
            printf '%s\n' "${line#*=}"
            return 0
        fi
    done < "$file"
    return 1
}

backup_root_prepare() {
    local root

    root="$(backup_root_path)"
    [[ -n "$root" && "$root" != "/" && "$root" != "${HOME:-}" && "$root" != "${ST_PATH:-}" ]] || {
        BACKUP_LAST_ERROR="备份根目录为空或危险"
        return 1
    }
    [[ ! -L "$root" ]] || {
        BACKUP_LAST_ERROR="备份根目录不得是符号链接：$root"
        return 1
    }
    mkdir -p -- "$root" || {
        BACKUP_LAST_ERROR="无法创建备份根目录：$root"
        return 1
    }
    path_canonicalize_directory "$root" >/dev/null || {
        BACKUP_LAST_ERROR="无法解析备份根目录：$root"
        return 1
    }
}

backup_staging_remove() {
    local path="$1"
    local root
    local parent

    root="$(path_canonicalize_directory "$(backup_root_path)")" || return 1
    [[ -d "$path" && ! -L "$path" ]] || return 1
    parent="$(path_canonicalize_directory "$(dirname -- "$path")")" || return 1
    [[ "$parent" == "$root" && "$(basename -- "$path")" == .stermux-backup.tmp.* ]] || return 1
    rm -rf -- "$path"
}

backup_write_metadata() {
    local file="$1" id="$2" epoch="$3" display_time="$4" type="$5" reason="$6" size="$7"
    local commit branch

    commit="$(git_current_commit "$ST_PATH" 2>/dev/null || printf '%s' unknown)"
    branch="$(git_current_branch "$ST_PATH" 2>/dev/null || printf '%s' unknown)"
    reason="$(backup_one_line "$reason")"
    {
        printf 'BACKUP_ID=%s\n' "$id"
        printf 'BACKUP_TIME_EPOCH=%s\n' "$epoch"
        printf 'BACKUP_TIME=%s\n' "$display_time"
        printf 'BACKUP_TYPE=%s\n' "$type"
        printf 'BACKUP_REASON=%s\n' "$reason"
        printf 'BACKUP_SIZE=%s\n' "$size"
        printf 'BACKUP_STATUS=success\n'
        printf 'ST_COMMIT=%s\n' "$commit"
        printf 'ST_BRANCH=%s\n' "$branch"
        printf 'BACKUP_RULE_VERSION=1\n'
    } > "$file"
}

backup_archive_is_valid() {
    local archive="$1"
    [[ -s "$archive" ]] || return 1
    tar -tzf "$archive" >/dev/null 2>&1
}

backup_create() {
    local type="$1" reason="${2:-unspecified}"
    local root data_root staging epoch display_time id final archive size

    BACKUP_LAST_ERROR=""
    BACKUP_LAST_PATH=""
    backup_type_is_valid "$type" || { BACKUP_LAST_ERROR="未知备份类型：$type"; return 1; }
    command -v tar >/dev/null 2>&1 || { BACKUP_LAST_ERROR="未找到 tar 命令"; return 1; }
    backup_root_prepare || return 1
    sillytavern_backup_resolve_source || return 1
    root="$(path_canonicalize_directory "$(backup_root_path)")" || return 1
    data_root="$(path_canonicalize_directory "$BACKUP_SOURCE_DATA_DIR")" || {
        BACKUP_LAST_ERROR="无法解析 SillyTavern data 目录"
        return 1
    }
    if [[ "$root" == "$data_root" || "$root" == "$data_root/"* ]]; then
        BACKUP_LAST_ERROR="备份根目录不得位于 SillyTavern data 目录内"
        return 1
    fi
    if find "$data_root" -type l -print -quit | grep -q .; then
        BACKUP_LAST_ERROR="SillyTavern data 包含符号链接，为保证备份可安全恢复已停止"
        return 1
    fi
    staging="$(mktemp -d "$root/.stermux-backup.tmp.XXXXXX")" || {
        BACKUP_LAST_ERROR="无法创建备份临时目录"
        return 1
    }
    epoch="$(backup_current_epoch)"
    display_time="$(backup_current_display_time)"
    BACKUP_SEQUENCE=$((BACKUP_SEQUENCE + 1))
    id="${epoch}_${type}_$$_${BACKUP_SEQUENCE}"
    final="$root/$id"
    archive="$staging/backup.tar.gz"

    ui_info "正在创建 $type 备份..."
    if ! tar -C "$BACKUP_SOURCE_DATA_DIR" -czf "$archive" .; then
        BACKUP_LAST_ERROR="无法归档 SillyTavern data 目录"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    fi
    if ! backup_archive_is_valid "$archive"; then
        BACKUP_LAST_ERROR="备份归档验证失败"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    fi
    cp -- "$BACKUP_SOURCE_CONFIG_FILE" "$staging/config.yaml" || {
        BACKUP_LAST_ERROR="无法保存 config.yaml"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    }
    size="$(wc -c < "$archive" | tr -d '[:space:]')"
    [[ "$size" =~ ^[1-9][0-9]*$ ]] || {
        BACKUP_LAST_ERROR="无法确认备份文件大小"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    }
    backup_write_metadata "$staging/metadata.conf" "$id" "$epoch" "$display_time" \
        "$type" "$reason" "$size" || {
        BACKUP_LAST_ERROR="无法写入备份元数据"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    }
    [[ ! -e "$final" ]] || {
        BACKUP_LAST_ERROR="备份标识冲突：$id"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    }
    mv -- "$staging" "$final" || {
        BACKUP_LAST_ERROR="无法提交完成的备份"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    }
    BACKUP_LAST_PATH="$final"
    backup_log create success "$id" "$type" || true
    if backup_type_is_automatic "$type"; then
        backup_rotate_automatic || ui_warning "备份已创建，但自动备份池清理失败：$BACKUP_LAST_ERROR"
    fi
    return 0
}

backup_inventory_reset() {
    BACKUP_IDS=(); BACKUP_PATHS=(); BACKUP_TIMES=(); BACKUP_EPOCHS=(); BACKUP_TYPES=(); BACKUP_SIZES=()
}

backup_inventory_scan() {
    local root path metadata id epoch time type size status
    local -a entries=() candidates=()
    local entry
    local nullglob_was_set=false

    backup_inventory_reset
    backup_root_prepare || return 1
    root="$(path_canonicalize_directory "$(backup_root_path)")" || return 1
    shopt -q nullglob && nullglob_was_set=true
    shopt -s nullglob
    candidates=("$root"/*)
    [[ "$nullglob_was_set" == true ]] || shopt -u nullglob
    for path in "${candidates[@]}"; do
        [[ -d "$path" && ! -L "$path" ]] || continue
        metadata="$path/metadata.conf"
        id="$(backup_metadata_get "$metadata" BACKUP_ID)" || continue
        epoch="$(backup_metadata_get "$metadata" BACKUP_TIME_EPOCH)" || continue
        time="$(backup_metadata_get "$metadata" BACKUP_TIME)" || continue
        type="$(backup_metadata_get "$metadata" BACKUP_TYPE)" || continue
        size="$(backup_metadata_get "$metadata" BACKUP_SIZE)" || continue
        status="$(backup_metadata_get "$metadata" BACKUP_STATUS)" || continue
        [[ "$status" == success && "$epoch" =~ ^[0-9]+$ ]] || continue
        backup_type_is_valid "$type" || continue
        [[ "$(basename -- "$path")" == "$id" ]] || continue
        entries+=("$epoch"$'\t'"$path")
    done
    if (( ${#entries[@]} > 0 )); then
        mapfile -t entries < <(printf '%s\n' "${entries[@]}" | sort -t $'\t' -k1,1nr)
    fi
    for entry in "${entries[@]}"; do
        epoch="${entry%%$'\t'*}"
        path="${entry#*$'\t'}"
        metadata="$path/metadata.conf"
        BACKUP_PATHS+=("$path")
        BACKUP_IDS+=("$(backup_metadata_get "$metadata" BACKUP_ID)")
        BACKUP_EPOCHS+=("$epoch")
        BACKUP_TIMES+=("$(backup_metadata_get "$metadata" BACKUP_TIME)")
        BACKUP_TYPES+=("$(backup_metadata_get "$metadata" BACKUP_TYPE)")
        BACKUP_SIZES+=("$(backup_metadata_get "$metadata" BACKUP_SIZE)")
    done
}

backup_delete_path_is_safe() {
    local target="$1" root target_canonical parent

    [[ -n "$target" && -d "$target" && ! -L "$target" ]] || return 1
    root="$(path_canonicalize_directory "$(backup_root_path)")" || return 1
    target_canonical="$(path_canonicalize_directory "$target")" || return 1
    parent="$(path_canonicalize_directory "$(dirname -- "$target")")" || return 1
    [[ "$parent" == "$root" && "$target_canonical" == "$root/"* && "$target_canonical" != "$root" ]] || return 1
    [[ "$target_canonical" != "/" && "$target_canonical" != "${HOME:-}" && "$target_canonical" != "${ST_PATH:-}" ]] || return 1
}

backup_remove_directory() { rm -rf -- "$1"; }

backup_delete_path() {
    local target="$1" mode="${2:-manual}" metadata id type

    BACKUP_LAST_ERROR=""
    backup_delete_path_is_safe "$target" || {
        BACKUP_LAST_ERROR="备份路径越界或不安全"
        backup_log delete blocked "$(basename -- "$target" 2>/dev/null || printf unknown)" "$BACKUP_LAST_ERROR" || true
        return 1
    }
    metadata="$target/metadata.conf"
    id="$(backup_metadata_get "$metadata" BACKUP_ID)" || {
        BACKUP_LAST_ERROR="备份元数据缺少标识"
        backup_log delete failed "$(basename -- "$target")" "$BACKUP_LAST_ERROR" || true
        return 1
    }
    type="$(backup_metadata_get "$metadata" BACKUP_TYPE)" || {
        BACKUP_LAST_ERROR="备份元数据缺少类型"
        backup_log delete failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    }
    [[ "$(basename -- "$target")" == "$id" ]] || {
        BACKUP_LAST_ERROR="备份目录与元数据标识不一致"
        backup_log delete failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    }
    backup_type_is_valid "$type" || {
        BACKUP_LAST_ERROR="备份类型无效"
        backup_log delete failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    }
    if [[ "$mode" == automatic ]] && ! backup_type_is_automatic "$type"; then
        BACKUP_LAST_ERROR="自动清理拒绝删除 manual 备份"
        backup_log delete blocked "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    fi
    if ! backup_remove_directory "$target"; then
        BACKUP_LAST_ERROR="删除备份目录失败"
        backup_log delete failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    fi
    backup_log delete success "$id" "$mode" || true
}

backup_rotate_automatic() {
    local keep="${AUTOMATIC_BACKUP_KEEP:-2}" index automatic_seen=0 failed=0 last_error=""

    [[ "$keep" =~ ^[1-9][0-9]*$ ]] || keep=2
    backup_inventory_scan || return 1
    for ((index = 0; index < ${#BACKUP_IDS[@]}; index++)); do
        if backup_type_is_automatic "${BACKUP_TYPES[index]}"; then
            automatic_seen=$((automatic_seen + 1))
            if (( automatic_seen > keep )); then
                if ! backup_delete_path "${BACKUP_PATHS[index]}" automatic; then
                    failed=$((failed + 1))
                    last_error="$BACKUP_LAST_ERROR"
                fi
            fi
        fi
    done
    if (( failed > 0 )); then
        BACKUP_LAST_ERROR="自动备份池有 $failed 个旧备份清理失败：$last_error"
        return 1
    fi
}

backup_size_display() {
    local bytes="$1"
    if (( bytes >= 1048576 )); then printf '%d MiB' "$((bytes / 1048576))"
    elif (( bytes >= 1024 )); then printf '%d KiB' "$((bytes / 1024))"
    else printf '%d B' "$bytes"; fi
}

backup_show_list() {
    local index
    backup_inventory_scan || { ui_error "$BACKUP_LAST_ERROR"; return 1; }
    printf '\n备份列表\n\n'
    if (( ${#BACKUP_IDS[@]} == 0 )); then ui_info "暂无备份。"; return 0; fi
    for ((index = 0; index < ${#BACKUP_IDS[@]}; index++)); do
        printf '%d. %s | %s | %s | %s\n' "$((index + 1))" "${BACKUP_TIMES[index]}" \
            "${BACKUP_TYPES[index]}" "$(backup_size_display "${BACKUP_SIZES[index]}")" "${BACKUP_IDS[index]}"
    done
}

backup_parse_selection() {
    local input="$1" normalized token index existing duplicate
    BACKUP_SELECTED_INDEXES=()
    normalized="${input//,/ }"
    for token in $normalized; do
        [[ "$token" =~ ^[0-9]+$ ]] || continue
        (( token >= 1 && token <= ${#BACKUP_IDS[@]} )) || continue
        index=$((token - 1)); duplicate=false
        for existing in "${BACKUP_SELECTED_INDEXES[@]}"; do
            (( existing == index )) && { duplicate=true; break; }
        done
        [[ "$duplicate" == true ]] || BACKUP_SELECTED_INDEXES+=("$index")
    done
    (( ${#BACKUP_SELECTED_INDEXES[@]} > 0 ))
}

backup_delete_selected() {
    local index id
    BACKUP_DELETE_SUCCESS=0; BACKUP_DELETE_FAILED=0; BACKUP_DELETE_SKIPPED=0
    BACKUP_DELETE_FAILED_IDS=(); BACKUP_DELETE_FAILED_ERRORS=()
    for index in "$@"; do
        id="${BACKUP_IDS[index]}"
        if backup_delete_path "${BACKUP_PATHS[index]}" manual; then
            BACKUP_DELETE_SUCCESS=$((BACKUP_DELETE_SUCCESS + 1))
        else
            BACKUP_DELETE_FAILED=$((BACKUP_DELETE_FAILED + 1))
            BACKUP_DELETE_FAILED_IDS+=("$id")
            BACKUP_DELETE_FAILED_ERRORS+=("$BACKUP_LAST_ERROR")
        fi
    done
}

backup_delete_interactive() {
    local multiple="$1" input confirm index
    backup_show_list || return 1
    (( ${#BACKUP_IDS[@]} > 0 )) || return 0
    if [[ "$multiple" == true ]]; then printf '请输入备份编号（支持空格或逗号分隔）：'
    else printf '请输入一个备份编号：'; fi
    IFS= read -r input || return 1
    backup_parse_selection "$input" || { ui_warning "没有有效的备份编号。"; return 1; }
    if [[ "$multiple" != true && ${#BACKUP_SELECTED_INDEXES[@]} -ne 1 ]]; then ui_warning "只能选择一个备份。"; return 1; fi
    printf '\n即将删除：\n'
    for index in "${BACKUP_SELECTED_INDEXES[@]}"; do
        printf -- '- %s | %s | %s\n' "${BACKUP_TIMES[index]}" "${BACKUP_TYPES[index]}" "${BACKUP_IDS[index]}"
    done
    printf '确认删除以上备份？[y/N] '
    IFS= read -r confirm || return 1
    if [[ "$confirm" != y && "$confirm" != Y ]]; then ui_info "已取消删除。"; return 0; fi
    backup_delete_selected "${BACKUP_SELECTED_INDEXES[@]}"
    printf '删除成功：%s，失败：%s\n' "$BACKUP_DELETE_SUCCESS" "$BACKUP_DELETE_FAILED"
    for ((index = 0; index < ${#BACKUP_DELETE_FAILED_IDS[@]}; index++)); do
        ui_error "${BACKUP_DELETE_FAILED_IDS[index]}：${BACKUP_DELETE_FAILED_ERRORS[index]}"
    done
}

backup_archive_members_are_safe() {
    local archive="$1" entry normalized
    while IFS= read -r entry; do
        normalized="${entry#./}"
        [[ -z "$normalized" ]] && continue
        [[ "$normalized" != /* && "$normalized" != ".." && "$normalized" != ../* && "$normalized" != */../* ]] || return 1
    done < <(tar -tzf "$archive")
    if tar -tvzf "$archive" | grep -Eq '^[lh]'; then
        return 1
    fi
}

backup_restore_temp_path_is_safe() {
    local target="$1" st_root parent name

    [[ -n "$target" && ( -e "$target" || -L "$target" ) && ! -L "$target" ]] || return 1
    st_root="$(path_canonicalize_directory "$ST_PATH")" || return 1
    parent="$(path_canonicalize_directory "$(dirname -- "$target")")" || return 1
    name="$(basename -- "$target")"
    [[ "$parent" == "$st_root" ]] || return 1
    case "$name" in
        .stermux-restore-stage.*|.stermux-restore-old-data.*|.stermux-restore-old-config.*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

backup_restore_temp_remove() {
    local target="$1"

    [[ -e "$target" || -L "$target" ]] || return 0
    backup_restore_temp_path_is_safe "$target" || return 1
    if [[ -d "$target" ]]; then
        rm -rf -- "$target"
    else
        rm -f -- "$target"
    fi
}

backup_restore_path() {
    local backup_path="$1" archive id stage old_data old_config cleanup_failed=0
    BACKUP_LAST_ERROR=""
    backup_delete_path_is_safe "$backup_path" || { BACKUP_LAST_ERROR="恢复目标不是安全备份目录"; return 1; }
    archive="$backup_path/backup.tar.gz"
    id="$(backup_metadata_get "$backup_path/metadata.conf" BACKUP_ID)" || {
        BACKUP_LAST_ERROR="备份元数据缺少标识"
        return 1
    }
    backup_archive_is_valid "$archive" && backup_archive_members_are_safe "$archive" || {
        BACKUP_LAST_ERROR="备份归档无效或包含危险路径"
        return 1
    }
    sillytavern_backup_resolve_source || return 1
    stage="$(mktemp -d "$ST_PATH/.stermux-restore-stage.XXXXXX")" || {
        BACKUP_LAST_ERROR="无法创建恢复临时目录"
        return 1
    }
    old_data="$ST_PATH/.stermux-restore-old-data.$$.${RANDOM:-0}"
    old_config="$ST_PATH/.stermux-restore-old-config.$$.${RANDOM:-0}"
    [[ ! -e "$old_data" && ! -e "$old_config" ]] || {
        BACKUP_LAST_ERROR="存在冲突的恢复临时路径"
        backup_restore_temp_remove "$stage" || true
        return 1
    }
    mkdir -p -- "$stage/data" || {
        BACKUP_LAST_ERROR="无法准备恢复数据目录"
        backup_restore_temp_remove "$stage" || true
        return 1
    }
    tar -C "$stage/data" -xzf "$archive" || {
        BACKUP_LAST_ERROR="无法解压备份"
        backup_restore_temp_remove "$stage" || true
        backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    }
    if find "$stage/data" -type l -print -quit | grep -q .; then
        BACKUP_LAST_ERROR="恢复数据包含符号链接，为避免路径逃逸已拒绝恢复"
        backup_restore_temp_remove "$stage" || true
        backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    fi
    cp -- "$backup_path/config.yaml" "$stage/config.yaml" || {
        BACKUP_LAST_ERROR="备份缺少可读取的 config.yaml"
        backup_restore_temp_remove "$stage" || true
        backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    }
    backup_create protective "pre-restore:$id" || {
        backup_restore_temp_remove "$stage" || true
        backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    }
    mv -- "$BACKUP_SOURCE_DATA_DIR" "$old_data" || {
        BACKUP_LAST_ERROR="无法暂存当前 data 目录"
        backup_restore_temp_remove "$stage" || true
        backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    }
    if ! mv -- "$BACKUP_SOURCE_CONFIG_FILE" "$old_config"; then
        mv -- "$old_data" "$BACKUP_SOURCE_DATA_DIR" || true
        BACKUP_LAST_ERROR="无法暂存当前 config.yaml，未修改现有数据"
        backup_restore_temp_remove "$stage" || true
        backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    fi
    if ! mv -- "$stage/data" "$BACKUP_SOURCE_DATA_DIR"; then
        mv -- "$old_data" "$BACKUP_SOURCE_DATA_DIR" || true
        mv -- "$old_config" "$BACKUP_SOURCE_CONFIG_FILE" || true
        BACKUP_LAST_ERROR="无法安装恢复后的 data 目录"
        backup_restore_temp_remove "$stage" || true
        backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    fi
    if ! mv -- "$stage/config.yaml" "$BACKUP_SOURCE_CONFIG_FILE"; then
        mv -- "$BACKUP_SOURCE_DATA_DIR" "$stage/failed-data" || true
        mv -- "$old_data" "$BACKUP_SOURCE_DATA_DIR" || true
        mv -- "$old_config" "$BACKUP_SOURCE_CONFIG_FILE" || true
        BACKUP_LAST_ERROR="无法恢复 config.yaml，已尝试回滚"
        backup_restore_temp_remove "$stage" || true
        backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    fi
    backup_restore_temp_remove "$old_data" || cleanup_failed=$((cleanup_failed + 1))
    backup_restore_temp_remove "$old_config" || cleanup_failed=$((cleanup_failed + 1))
    backup_restore_temp_remove "$stage" || cleanup_failed=$((cleanup_failed + 1))
    if (( cleanup_failed > 0 )); then
        BACKUP_LAST_ERROR="数据已恢复，但清理恢复临时内容失败"
        backup_log restore warning "$id" "$BACKUP_LAST_ERROR" || true
        return 2
    fi
    backup_log restore success "$id" "data and config.yaml" || true
}

backup_restore_interactive() {
    local input confirm index restore_status
    backup_show_list || return 1
    (( ${#BACKUP_IDS[@]} > 0 )) || return 0
    printf '请输入要恢复的一个备份编号：'; IFS= read -r input || return 1
    backup_parse_selection "$input" || { ui_warning "没有有效的备份编号。"; return 1; }
    [[ ${#BACKUP_SELECTED_INDEXES[@]} -eq 1 ]] || { ui_warning "恢复只能选择一个备份。"; return 1; }
    index="${BACKUP_SELECTED_INDEXES[0]}"
    printf '将恢复：%s | %s | %s\n' "${BACKUP_TIMES[index]}" "${BACKUP_TYPES[index]}" "${BACKUP_IDS[index]}"
    ui_warning "恢复前会先创建 protective 备份。"
    printf '确认恢复？[y/N] '; IFS= read -r confirm || return 1
    [[ "$confirm" == y || "$confirm" == Y ]] || { ui_info "已取消恢复。"; return 0; }
    backup_restore_path "${BACKUP_PATHS[index]}"
    restore_status=$?
    case "$restore_status" in
        0) ui_success "备份恢复成功。" ;;
        2) ui_warning "$BACKUP_LAST_ERROR" ;;
        *) ui_error "备份恢复失败：$BACKUP_LAST_ERROR"; return 1 ;;
    esac
}

backup_menu() {
    local choice
    while true; do
        ui_clear
        printf '\n备份与恢复\n\n1. 创建 manual 备份\n2. 查看备份列表\n3. 恢复备份\n4. 删除一个备份\n5. 选择多个备份删除\n0. 返回主菜单\n\n请选择操作：'
        IFS= read -r choice || return 0
        case "$choice" in
            1) if backup_create manual "user-request"; then ui_success "手动备份创建成功：$(basename -- "$BACKUP_LAST_PATH")"; else ui_error "$BACKUP_LAST_ERROR"; fi; ui_pause ;;
            2) backup_show_list || true; ui_pause ;;
            3) backup_restore_interactive || true; ui_pause ;;
            4) backup_delete_interactive false || true; ui_pause ;;
            5) backup_delete_interactive true || true; ui_pause ;;
            0) return 0 ;;
            *) ui_warning "无效选项，请输入 0 到 5。"; ui_pause ;;
        esac
    done
}
