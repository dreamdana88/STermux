#!/usr/bin/env bash

BACKUP_LAST_ERROR=""
BACKUP_LAST_PATH=""
BACKUP_SEQUENCE=0
BACKUP_DELETE_SUCCESS=0
BACKUP_DELETE_FAILED=0
BACKUP_DELETE_SKIPPED=0
BACKUP_PROGRESS_LAST_DURATION=0
BACKUP_PROGRESS_CANCELLED=false

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

backup_type_display() {
    case "$1" in
        manual) printf '%s\n' "手动备份" ;;
        protective) printf '%s\n' "保护备份" ;;
        scheduled) printf '%s\n' "计划备份" ;;
        catchup) printf '%s\n' "补做备份" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

backup_elapsed_display() {
    local seconds="${1:-0}"

    [[ "$seconds" =~ ^[0-9]+$ ]] || seconds=0
    if (( seconds >= 60 )); then
        printf '%s 分 %s 秒\n' "$((seconds / 60))" "$((seconds % 60))"
    else
        printf '%s 秒\n' "$seconds"
    fi
}

backup_run_with_progress() {
    local step="$1" label="$2"
    shift 2
    local heartbeat_interval="${BACKUP_PROGRESS_HEARTBEAT_SECONDS:-10}"
    local started_seconds=$SECONDS heartbeat_pid status=0 elapsed

    [[ "$heartbeat_interval" =~ ^[1-9][0-9]*$ ]] || heartbeat_interval=10
    BACKUP_PROGRESS_LAST_DURATION=0
    BACKUP_PROGRESS_CANCELLED=false
    ui_info "[$step] 正在$label..."
    (
        local heartbeat_elapsed=0 next_heartbeat="$heartbeat_interval"
        while sleep 0.2; do
            heartbeat_elapsed=$((SECONDS - started_seconds))
            if (( heartbeat_elapsed >= next_heartbeat )); then
                ui_info "[$step] $label：仍在进行，已用时 $(backup_elapsed_display "$heartbeat_elapsed")..."
                next_heartbeat=$((next_heartbeat + heartbeat_interval))
            fi
        done
    ) &
    heartbeat_pid=$!

    "$@" || status=$?
    kill "$heartbeat_pid" 2>/dev/null || true
    wait "$heartbeat_pid" 2>/dev/null || true
    elapsed=$((SECONDS - started_seconds))
    (( elapsed >= 0 )) || elapsed=0
    BACKUP_PROGRESS_LAST_DURATION="$elapsed"

    if (( status == 0 )); then
        ui_success "[$step] $label：已完成（用时 $(backup_elapsed_display "$elapsed")）"
        return 0
    fi
    if (( status == 130 || status == 143 )); then
        BACKUP_PROGRESS_CANCELLED=true
        ui_warning "[$step] $label已由用户取消。"
    fi
    return "$status"
}

backup_automatic_keep_value() {
    local keep="${AUTOMATIC_BACKUP_KEEP:-2}"

    if [[ "$keep" =~ ^[0-9]+$ ]] && (( keep >= 1 && keep <= 20 )); then
        printf '%s\n' "$keep"
    else
        printf '%s\n' 2
    fi
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
    local third_party_status="$8" data_archive_size="$9" third_party_archive_size="${10}"
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
        printf 'BACKUP_DATA_ARCHIVE_SIZE=%s\n' "$data_archive_size"
        printf 'BACKUP_THIRD_PARTY_STATUS=%s\n' "$third_party_status"
        printf 'BACKUP_THIRD_PARTY_ARCHIVE_SIZE=%s\n' "$third_party_archive_size"
        printf 'BACKUP_STATUS=success\n'
        printf 'ST_COMMIT=%s\n' "$commit"
        printf 'ST_BRANCH=%s\n' "$branch"
        printf 'BACKUP_RULE_VERSION=2\n'
    } > "$file"
}

backup_archive_is_valid() {
    local archive="$1"
    [[ -s "$archive" ]] || return 1
    tar -tzf "$archive" >/dev/null 2>&1
}

backup_directory_is_valid() {
    local directory="$1"
    local third_party_status backup_status size data_archive_size third_party_archive_size
    local actual_data_size actual_config_size actual_third_party_size=0 actual_total_size

    [[ -f "$directory/config.yaml" && -r "$directory/config.yaml" ]] || return 1
    backup_archive_is_valid "$directory/backup.tar.gz" || return 1
    backup_status="$(backup_metadata_get "$directory/metadata.conf" BACKUP_STATUS)" || return 1
    [[ "$backup_status" == success ]] || return 1
    size="$(backup_metadata_get "$directory/metadata.conf" BACKUP_SIZE)" || return 1
    data_archive_size="$(backup_metadata_get "$directory/metadata.conf" BACKUP_DATA_ARCHIVE_SIZE)" \
        || return 1
    third_party_archive_size="$(backup_metadata_get "$directory/metadata.conf" BACKUP_THIRD_PARTY_ARCHIVE_SIZE)" \
        || return 1
    [[ "$size" =~ ^[1-9][0-9]*$ && "$data_archive_size" =~ ^[1-9][0-9]*$ \
        && "$third_party_archive_size" =~ ^[0-9]+$ ]] || return 1
    actual_data_size="$(wc -c < "$directory/backup.tar.gz" | tr -d '[:space:]')"
    actual_config_size="$(wc -c < "$directory/config.yaml" | tr -d '[:space:]')"
    [[ "$actual_data_size" == "$data_archive_size" ]] || return 1
    third_party_status="$(backup_metadata_get "$directory/metadata.conf" BACKUP_THIRD_PARTY_STATUS)" \
        || return 1
    case "$third_party_status" in
        present)
            backup_archive_is_valid "$directory/third-party.tar.gz" || return 1
            actual_third_party_size="$(wc -c < "$directory/third-party.tar.gz" | tr -d '[:space:]')"
            [[ "$actual_third_party_size" == "$third_party_archive_size" ]] || return 1
            ;;
        missing)
            [[ ! -e "$directory/third-party.tar.gz" ]] || return 1
            [[ "$third_party_archive_size" == 0 ]] || return 1
            ;;
        *)
            return 1
            ;;
    esac
    actual_total_size=$((actual_data_size + actual_config_size + actual_third_party_size))
    [[ "$actual_total_size" == "$size" ]]
}

backup_create() {
    local type="$1" reason="${2:-unspecified}"
    local root data_root third_party_root staging epoch display_time id final
    local data_archive third_party_archive size data_archive_size config_size
    local third_party_archive_size=0 third_party_status
    local total_started_seconds=$SECONDS total_duration

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
    third_party_status="$BACKUP_SOURCE_THIRD_PARTY_STATUS"
    if [[ "$third_party_status" == present ]]; then
        third_party_root="$(path_canonicalize_directory "$BACKUP_SOURCE_THIRD_PARTY_DIR")" || {
            BACKUP_LAST_ERROR="无法解析 SillyTavern third-party 目录"
            return 1
        }
        if [[ "$root" == "$third_party_root" || "$root" == "$third_party_root/"* ]]; then
            BACKUP_LAST_ERROR="备份根目录不得位于 SillyTavern third-party 目录内"
            return 1
        fi
        if find "$third_party_root" -type l -print -quit | grep -q .; then
            BACKUP_LAST_ERROR="SillyTavern third-party 包含符号链接，为保证备份可安全恢复已停止"
            return 1
        fi
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
    data_archive="$staging/backup.tar.gz"
    third_party_archive="$staging/third-party.tar.gz"

    ui_info "正在创建$(backup_type_display "$type")，大数据备份期间会持续显示已用时间。"
    if ! backup_run_with_progress '1/4' '归档 SillyTavern data' \
        tar -C "$BACKUP_SOURCE_DATA_DIR" -czf "$data_archive" .; then
        if [[ "$BACKUP_PROGRESS_CANCELLED" == true ]]; then
            BACKUP_LAST_ERROR="用户取消了 SillyTavern data 归档"
        else
            BACKUP_LAST_ERROR="无法归档 SillyTavern data 目录"
        fi
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    fi
    if ! backup_run_with_progress '1/4' '验证 SillyTavern data 归档' \
        backup_archive_is_valid "$data_archive"; then
        BACKUP_LAST_ERROR="data 备份归档验证失败"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    fi
    if [[ "$third_party_status" == present ]]; then
        if ! backup_run_with_progress '2/4' '归档 third-party 扩展' \
            tar -C "$BACKUP_SOURCE_THIRD_PARTY_DIR" -czf "$third_party_archive" .; then
            if [[ "$BACKUP_PROGRESS_CANCELLED" == true ]]; then
                BACKUP_LAST_ERROR="用户取消了 SillyTavern third-party 归档"
            else
                BACKUP_LAST_ERROR="无法归档 SillyTavern third-party 目录"
            fi
            backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
            backup_staging_remove "$staging" || true
            return 1
        fi
        if ! backup_run_with_progress '2/4' '验证 third-party 扩展归档' \
            backup_archive_is_valid "$third_party_archive"; then
            BACKUP_LAST_ERROR="third-party 备份归档验证失败"
            backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
            backup_staging_remove "$staging" || true
            return 1
        fi
    else
        ui_info "[2/4] third-party 目录不存在，本次备份已记录为缺失。"
    fi
    ui_info "[3/4] 正在保存 config.yaml 并生成备份元数据..."
    cp -- "$BACKUP_SOURCE_CONFIG_FILE" "$staging/config.yaml" || {
        BACKUP_LAST_ERROR="无法保存 config.yaml"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    }
    data_archive_size="$(wc -c < "$data_archive" | tr -d '[:space:]')"
    config_size="$(wc -c < "$staging/config.yaml" | tr -d '[:space:]')"
    if [[ "$third_party_status" == present ]]; then
        third_party_archive_size="$(wc -c < "$third_party_archive" | tr -d '[:space:]')"
    fi
    [[ "$data_archive_size" =~ ^[1-9][0-9]*$ && "$config_size" =~ ^[0-9]+$ \
        && "$third_party_archive_size" =~ ^[0-9]+$ ]] || {
        BACKUP_LAST_ERROR="无法确认备份文件大小"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    }
    size=$((data_archive_size + config_size + third_party_archive_size))
    backup_write_metadata "$staging/metadata.conf" "$id" "$epoch" "$display_time" \
        "$type" "$reason" "$size" "$third_party_status" "$data_archive_size" \
        "$third_party_archive_size" || {
        BACKUP_LAST_ERROR="无法写入备份元数据"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    }
    ui_success "[3/4] 配置与备份元数据已保存。"
    if ! backup_run_with_progress '4/4' '验证备份完整性' \
        backup_directory_is_valid "$staging"; then
        BACKUP_LAST_ERROR="备份内容完整性验证失败"
        backup_log create failed "$id" "$BACKUP_LAST_ERROR" || true
        backup_staging_remove "$staging" || true
        return 1
    fi
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
    total_duration=$((SECONDS - total_started_seconds))
    (( total_duration >= 0 )) || total_duration=0
    backup_log create success "$id" \
        "$type;third-party=$third_party_status;duration_seconds=$total_duration" || true
    if backup_type_is_automatic "$type"; then
        backup_rotate_automatic || ui_warning "备份已创建，但自动备份池清理失败：$BACKUP_LAST_ERROR"
    fi
    ui_success "备份创建完成（总用时 $(backup_elapsed_display "$total_duration")，大小 $(backup_size_display "$size")）。"
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
    local keep index automatic_seen=0 removed=0 failed=0 last_error=""

    keep="$(backup_automatic_keep_value)"
    backup_inventory_scan || return 1
    for ((index = 0; index < ${#BACKUP_IDS[@]}; index++)); do
        if backup_type_is_automatic "${BACKUP_TYPES[index]}"; then
            automatic_seen=$((automatic_seen + 1))
            if (( automatic_seen > keep )); then
                if ! backup_delete_path "${BACKUP_PATHS[index]}" automatic; then
                    failed=$((failed + 1))
                    last_error="$BACKUP_LAST_ERROR"
                else
                    removed=$((removed + 1))
                fi
            fi
        fi
    done
    if (( failed > 0 )); then
        BACKUP_LAST_ERROR="自动备份池有 $failed 个旧备份清理失败：$last_error"
        backup_log rotate failed automatic-pool \
            "keep=$keep;seen=$automatic_seen;removed=$removed;failed=$failed" || true
        return 1
    fi
    backup_log rotate success automatic-pool \
        "keep=$keep;seen=$automatic_seen;removed=$removed" || true
}

backup_automatic_count() {
    local index count=0

    backup_inventory_scan || return 1
    for ((index = 0; index < ${#BACKUP_TYPES[@]}; index++)); do
        backup_type_is_automatic "${BACKUP_TYPES[index]}" && count=$((count + 1))
    done
    printf '%s\n' "$count"
}

backup_set_automatic_keep() {
    local new_keep="$1" current_keep automatic_count cleanup_count confirm

    [[ "$new_keep" =~ ^[0-9]+$ ]] && (( new_keep >= 1 && new_keep <= 20 )) || {
        BACKUP_LAST_ERROR="最大自动备份数量必须是 1 到 20 的整数"
        return 1
    }
    current_keep="$(backup_automatic_keep_value)"
    automatic_count="$(backup_automatic_count)" || return 1
    if (( automatic_count > new_keep )); then
        cleanup_count=$((automatic_count - new_keep))
        printf '\n当前自动备份数量：%s\n' "$automatic_count"
        printf '新的最大保留数量：%s\n' "$new_keep"
        printf '将清理最旧备份：%s\n\n' "$cleanup_count"
        printf '手动备份不会受到影响。\n'
        printf '确认修改并清理旧备份？[y/N] '
        IFS= read -r confirm || return 2
        if [[ "$confirm" != y && "$confirm" != Y ]]; then
            return 2
        fi
    fi
    if ! config_set_value AUTOMATIC_BACKUP_KEEP "$new_keep"; then
        BACKUP_LAST_ERROR="无法保存最大自动备份数量"
        return 1
    fi
    AUTOMATIC_BACKUP_KEEP="$new_keep"
    if (( automatic_count > new_keep )); then
        backup_rotate_automatic || return 1
    fi
    backup_log settings success "automatic-keep" "$current_keep->$new_keep" || true
    return 0
}

backup_toggle_automatic_interactive() {
    local target action confirm

    if backup_scheduler_enabled; then
        target=false
        action="关闭"
    else
        target=true
        action="开启"
    fi
    printf '确认%s自动备份？[y/N] ' "$action"
    IFS= read -r confirm || return 1
    if [[ "$confirm" != y && "$confirm" != Y ]]; then
        ui_info "已取消${action}自动备份。"
        return 0
    fi
    if backup_scheduler_set_enabled "$target"; then
        ui_success "已${action}自动备份。"
    else
        ui_error "$AUTO_BACKUP_LAST_ERROR"
        return 1
    fi
}

backup_set_interval_interactive() {
    local input

    printf '请输入备份频率天数 [1-30]：'
    IFS= read -r input || input=""
    if backup_scheduler_set_interval_days "$input"; then
        ui_success "备份频率已设置为每 $(backup_scheduler_interval_days) 天。"
    else
        ui_error "$AUTO_BACKUP_LAST_ERROR"
        return 1
    fi
}

backup_set_keep_interactive() {
    local input status=0

    printf '请输入新的最大数量 [1-20]：'
    IFS= read -r input || input=""
    backup_set_automatic_keep "$input" || status=$?
    case "$status" in
        0) ui_success "最大自动备份数量已设置为 $(backup_automatic_keep_value) 份。" ;;
        2) ui_info "已取消修改，配置和备份均未改变。" ;;
        *) ui_error "$BACKUP_LAST_ERROR"; return 1 ;;
    esac
}

backup_automatic_settings_menu() {
    local choice

    while true; do
        ui_clear
        ui_page_header '自动备份设置'
        printf '\n自动备份：%s\n' "$(backup_scheduler_status_text)"
        printf '备份频率：每 %s 天\n' "$(backup_scheduler_interval_days)"
        printf '下次备份：%s\n' "$(backup_scheduler_next_display)"
        printf '最大自动备份数量：%s 份\n\n' "$(backup_automatic_keep_value)"
        printf '1. 开启 / 关闭自动备份\n'
        printf '2. 设置备份频率\n'
        printf '3. 设置最大自动备份数量\n\n'
        printf '0. 返回\n\n'
        ui_menu_prompt '0-3'
        IFS= read -r choice || return 0
        case "$choice" in
            1)
                backup_toggle_automatic_interactive || true
                ui_pause
                ;;
            2)
                backup_set_interval_interactive || true
                ui_pause
                ;;
            3)
                backup_set_keep_interactive || true
                ui_pause
                ;;
            0)
                return 0
                ;;
            *)
                ui_warning '无效选项，请输入 0 到 3。'
                ui_pause
                ;;
        esac
    done
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
    printf '\n'
    ui_page_header '备份列表'
    printf '\n'
    if (( ${#BACKUP_IDS[@]} == 0 )); then ui_info "暂无备份。"; return 0; fi
    for ((index = 0; index < ${#BACKUP_IDS[@]}; index++)); do
        printf '%d. %s | %s | %s | %s\n' "$((index + 1))" "${BACKUP_TIMES[index]}" \
            "$(backup_type_display "${BACKUP_TYPES[index]}")" \
            "$(backup_size_display "${BACKUP_SIZES[index]}")" "${BACKUP_IDS[index]}"
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
        printf -- '- %s | %s | %s\n' "${BACKUP_TIMES[index]}" \
            "$(backup_type_display "${BACKUP_TYPES[index]}")" "${BACKUP_IDS[index]}"
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
        .stermux-restore-stage.*|.stermux-restore-old-data.*|.stermux-restore-old-config.*|.stermux-restore-old-third-party.*)
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

backup_restore_rollback_after_swap() {
    local stage="$1" data_target="$2" config_target="$3" third_party_target="$4"
    local old_data="$5" old_config="$6" old_third_party="$7"
    local sync_third_party="$8" had_third_party="$9"
    local failed=0

    if [[ -e "$data_target" ]]; then
        mv -- "$data_target" "$stage/failed-data" || failed=$((failed + 1))
    fi
    if [[ -e "$config_target" ]]; then
        mv -- "$config_target" "$stage/failed-config.yaml" || failed=$((failed + 1))
    fi
    if [[ "$sync_third_party" == true && -e "$third_party_target" ]]; then
        mv -- "$third_party_target" "$stage/failed-third-party" || failed=$((failed + 1))
    fi
    if [[ -e "$old_data" ]]; then
        mv -- "$old_data" "$data_target" || failed=$((failed + 1))
    fi
    if [[ -e "$old_config" ]]; then
        mv -- "$old_config" "$config_target" || failed=$((failed + 1))
    fi
    if [[ "$sync_third_party" == true && "$had_third_party" == true && -e "$old_third_party" ]]; then
        mv -- "$old_third_party" "$third_party_target" || failed=$((failed + 1))
    fi
    (( failed == 0 ))
}

backup_restore_path() {
    local backup_path="$1" archive third_party_archive id stage old_data old_config
    local old_third_party third_party_status third_party_target third_party_parent
    local cleanup_failed=0 sync_third_party=false had_third_party=false
    BACKUP_LAST_ERROR=""
    backup_delete_path_is_safe "$backup_path" || { BACKUP_LAST_ERROR="恢复目标不是安全备份目录"; return 1; }
    archive="$backup_path/backup.tar.gz"
    third_party_archive="$backup_path/third-party.tar.gz"
    id="$(backup_metadata_get "$backup_path/metadata.conf" BACKUP_ID)" || {
        BACKUP_LAST_ERROR="备份元数据缺少标识"
        return 1
    }
    backup_archive_is_valid "$archive" && backup_archive_members_are_safe "$archive" || {
        BACKUP_LAST_ERROR="备份归档无效或包含危险路径"
        return 1
    }
    third_party_status="$(backup_metadata_get "$backup_path/metadata.conf" BACKUP_THIRD_PARTY_STATUS)" \
        || third_party_status="legacy"
    case "$third_party_status" in
        present)
            sync_third_party=true
            backup_archive_is_valid "$third_party_archive" \
                && backup_archive_members_are_safe "$third_party_archive" || {
                BACKUP_LAST_ERROR="third-party 备份归档无效或包含危险路径"
                return 1
            }
            ;;
        missing)
            sync_third_party=true
            [[ ! -e "$third_party_archive" ]] || {
                BACKUP_LAST_ERROR="元数据记录 third-party 缺失，但备份中存在冲突归档"
                return 1
            }
            ;;
        legacy)
            ;;
        *)
            BACKUP_LAST_ERROR="备份中的 third-party 状态无效"
            return 1
            ;;
    esac
    if [[ "$third_party_status" != legacy ]] && ! backup_directory_is_valid "$backup_path"; then
        BACKUP_LAST_ERROR="备份内容或大小验证失败"
        return 1
    fi
    sillytavern_backup_resolve_source || return 1
    third_party_target="$(sillytavern_backup_third_party_path)"
    third_party_parent="$(dirname -- "$third_party_target")"
    if [[ "$sync_third_party" == true ]]; then
        mkdir -p -- "$third_party_parent" || {
            BACKUP_LAST_ERROR="无法准备 third-party 父目录"
            return 1
        }
    fi
    stage="$(mktemp -d "$ST_PATH/.stermux-restore-stage.XXXXXX")" || {
        BACKUP_LAST_ERROR="无法创建恢复临时目录"
        return 1
    }
    old_data="$ST_PATH/.stermux-restore-old-data.$$.${RANDOM:-0}"
    old_config="$ST_PATH/.stermux-restore-old-config.$$.${RANDOM:-0}"
    old_third_party="$ST_PATH/.stermux-restore-old-third-party.$$.${RANDOM:-0}"
    [[ ! -e "$old_data" && ! -e "$old_config" && ! -e "$old_third_party" ]] || {
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
    if [[ "$third_party_status" == present ]]; then
        mkdir -p -- "$stage/third-party" || {
            BACKUP_LAST_ERROR="无法准备 third-party 恢复目录"
            backup_restore_temp_remove "$stage" || true
            return 1
        }
        tar -C "$stage/third-party" -xzf "$third_party_archive" || {
            BACKUP_LAST_ERROR="无法解压 third-party 备份"
            backup_restore_temp_remove "$stage" || true
            backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
            return 1
        }
        if find "$stage/third-party" -type l -print -quit | grep -q .; then
            BACKUP_LAST_ERROR="恢复的 third-party 包含符号链接，为避免路径逃逸已拒绝恢复"
            backup_restore_temp_remove "$stage" || true
            backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
            return 1
        fi
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
    if [[ "$sync_third_party" == true && -d "$third_party_target" ]]; then
        if ! mv -- "$third_party_target" "$old_third_party"; then
            mv -- "$old_data" "$BACKUP_SOURCE_DATA_DIR" || true
            mv -- "$old_config" "$BACKUP_SOURCE_CONFIG_FILE" || true
            BACKUP_LAST_ERROR="无法暂存当前 third-party 目录，未执行恢复"
            backup_restore_temp_remove "$stage" || true
            backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
            return 1
        fi
        had_third_party=true
    fi
    if ! mv -- "$stage/data" "$BACKUP_SOURCE_DATA_DIR"; then
        backup_restore_rollback_after_swap "$stage" "$BACKUP_SOURCE_DATA_DIR" \
            "$BACKUP_SOURCE_CONFIG_FILE" "$third_party_target" "$old_data" "$old_config" \
            "$old_third_party" "$sync_third_party" "$had_third_party" || true
        BACKUP_LAST_ERROR="无法安装恢复后的 data 目录"
        backup_restore_temp_remove "$stage" || true
        backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    fi
    if ! mv -- "$stage/config.yaml" "$BACKUP_SOURCE_CONFIG_FILE"; then
        backup_restore_rollback_after_swap "$stage" "$BACKUP_SOURCE_DATA_DIR" \
            "$BACKUP_SOURCE_CONFIG_FILE" "$third_party_target" "$old_data" "$old_config" \
            "$old_third_party" "$sync_third_party" "$had_third_party" || true
        BACKUP_LAST_ERROR="无法恢复 config.yaml，已尝试回滚"
        backup_restore_temp_remove "$stage" || true
        backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    fi
    if [[ "$third_party_status" == present ]] \
        && ! mv -- "$stage/third-party" "$third_party_target"; then
        backup_restore_rollback_after_swap "$stage" "$BACKUP_SOURCE_DATA_DIR" \
            "$BACKUP_SOURCE_CONFIG_FILE" "$third_party_target" "$old_data" "$old_config" \
            "$old_third_party" "$sync_third_party" "$had_third_party" || true
        BACKUP_LAST_ERROR="无法恢复 third-party，已尝试回滚"
        backup_restore_temp_remove "$stage" || true
        backup_log restore failed "$id" "$BACKUP_LAST_ERROR" || true
        return 1
    fi
    backup_restore_temp_remove "$old_data" || cleanup_failed=$((cleanup_failed + 1))
    backup_restore_temp_remove "$old_config" || cleanup_failed=$((cleanup_failed + 1))
    backup_restore_temp_remove "$old_third_party" || cleanup_failed=$((cleanup_failed + 1))
    backup_restore_temp_remove "$stage" || cleanup_failed=$((cleanup_failed + 1))
    if (( cleanup_failed > 0 )); then
        BACKUP_LAST_ERROR="数据已恢复，但清理恢复临时内容失败"
        backup_log restore warning "$id" "$BACKUP_LAST_ERROR" || true
        return 2
    fi
    backup_log restore success "$id" "data,config.yaml,third-party=$third_party_status" || true
}

backup_restore_interactive() {
    local input confirm index restore_status
    backup_show_list || return 1
    (( ${#BACKUP_IDS[@]} > 0 )) || return 0
    printf '请输入要恢复的一个备份编号：'; IFS= read -r input || return 1
    backup_parse_selection "$input" || { ui_warning "没有有效的备份编号。"; return 1; }
    [[ ${#BACKUP_SELECTED_INDEXES[@]} -eq 1 ]] || { ui_warning "恢复只能选择一个备份。"; return 1; }
    index="${BACKUP_SELECTED_INDEXES[0]}"
    printf '将恢复：%s | %s | %s\n' "${BACKUP_TIMES[index]}" \
        "$(backup_type_display "${BACKUP_TYPES[index]}")" "${BACKUP_IDS[index]}"
    ui_warning "恢复前会先创建保护备份。"
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
        ui_page_header '备份与恢复'
        printf '\n1. 创建手动备份\n2. 查看备份列表\n3. 恢复备份\n4. 删除一个备份\n5. 选择多个备份删除\n6. 自动备份设置\n\n0. 返回主菜单\n\n'
        ui_menu_prompt '0-6'
        IFS= read -r choice || return 0
        case "$choice" in
            1) if backup_create manual "user-request"; then ui_success "手动备份创建成功：$(basename -- "$BACKUP_LAST_PATH")"; else ui_error "$BACKUP_LAST_ERROR"; fi; ui_pause ;;
            2) backup_show_list || true; ui_pause ;;
            3) backup_restore_interactive || true; ui_pause ;;
            4) backup_delete_interactive false || true; ui_pause ;;
            5) backup_delete_interactive true || true; ui_pause ;;
            6) backup_automatic_settings_menu ;;
            0) return 0 ;;
            *) ui_warning "无效选项，请输入 0 到 6。"; ui_pause ;;
        esac
    done
}
