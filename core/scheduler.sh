#!/usr/bin/env bash

AUTO_BACKUP_LAST_ERROR=""
AUTO_BACKUP_STATE_STATUS="missing"
AUTO_BACKUP_LAST_SUCCESS_EPOCH=0
AUTO_BACKUP_NEXT_EPOCH=0

backup_scheduler_enabled() {
    [[ "${AUTO_BACKUP_ENABLED:-false}" == true ]]
}

backup_scheduler_status_text() {
    if backup_scheduler_enabled; then
        printf '%s\n' "已开启"
    else
        printf '%s\n' "已关闭"
    fi
}

backup_scheduler_interval_days() {
    local days="${AUTO_BACKUP_INTERVAL_DAYS:-7}"

    if [[ "$days" =~ ^[0-9]+$ ]] && (( days >= 1 && days <= 30 )); then
        printf '%s\n' "$days"
    else
        printf '%s\n' 7
    fi
}

backup_scheduler_interval_seconds() {
    printf '%s\n' $(( $(backup_scheduler_interval_days) * 86400 ))
}

backup_scheduler_state_file() {
    printf '%s\n' "$STERMUX_ROOT/data/state/automatic-backup.conf"
}

backup_scheduler_lock_path() {
    printf '%s.lock\n' "$(backup_scheduler_state_file)"
}

backup_scheduler_state_reset_values() {
    AUTO_BACKUP_STATE_STATUS="missing"
    AUTO_BACKUP_LAST_SUCCESS_EPOCH=0
    AUTO_BACKUP_NEXT_EPOCH=0
}

backup_scheduler_state_read() {
    local state_file line key value
    local seen_last=false seen_next=false

    backup_scheduler_state_reset_values
    state_file="$(backup_scheduler_state_file)"
    [[ -f "$state_file" && -r "$state_file" && ! -L "$state_file" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ "$line" == *=* ]] || continue
        key="${line%%=*}"
        value="${line#*=}"
        case "$key" in
            AUTO_BACKUP_LAST_SUCCESS_EPOCH)
                [[ "$value" =~ ^[0-9]+$ ]] || {
                    AUTO_BACKUP_STATE_STATUS="corrupt"
                    return 2
                }
                AUTO_BACKUP_LAST_SUCCESS_EPOCH="$value"
                seen_last=true
                ;;
            AUTO_BACKUP_NEXT_EPOCH)
                [[ "$value" =~ ^[0-9]+$ ]] || {
                    AUTO_BACKUP_STATE_STATUS="corrupt"
                    return 2
                }
                AUTO_BACKUP_NEXT_EPOCH="$value"
                seen_next=true
                ;;
        esac
    done < "$state_file"

    if [[ "$seen_last" != true || "$seen_next" != true ]]; then
        AUTO_BACKUP_STATE_STATUS="corrupt"
        return 2
    fi
    AUTO_BACKUP_STATE_STATUS="valid"
    return 0
}

backup_scheduler_state_directory_prepare() {
    local state_file state_dir root_canonical state_dir_canonical

    state_file="$(backup_scheduler_state_file)"
    state_dir="$(dirname -- "$state_file")"
    [[ ! -L "$STERMUX_ROOT/data" && ! -L "$state_dir" && ! -L "$state_file" ]] || {
        AUTO_BACKUP_LAST_ERROR="自动备份状态路径不得是符号链接"
        return 1
    }
    mkdir -p -- "$state_dir" || {
        AUTO_BACKUP_LAST_ERROR="无法创建自动备份状态目录"
        return 1
    }
    root_canonical="$(path_canonicalize_directory "$STERMUX_ROOT")" || return 1
    state_dir_canonical="$(path_canonicalize_directory "$state_dir")" || return 1
    [[ "$state_dir_canonical" == "$root_canonical/data/state" ]] || {
        AUTO_BACKUP_LAST_ERROR="自动备份状态目录越出 STermux 项目"
        return 1
    }
}

backup_scheduler_state_write() {
    local last_epoch="$1" next_epoch="$2" state_file temporary_file

    [[ "$last_epoch" =~ ^[0-9]+$ && "$next_epoch" =~ ^[0-9]+$ ]] || {
        AUTO_BACKUP_LAST_ERROR="拒绝写入无效的自动备份时间状态"
        return 1
    }
    backup_scheduler_state_directory_prepare || return 1
    state_file="$(backup_scheduler_state_file)"
    temporary_file="$state_file.tmp.$$"
    if ! (umask 077; {
        printf 'AUTO_BACKUP_LAST_SUCCESS_EPOCH=%s\n' "$last_epoch"
        printf 'AUTO_BACKUP_NEXT_EPOCH=%s\n' "$next_epoch"
    } > "$temporary_file"); then
        AUTO_BACKUP_LAST_ERROR="无法写入自动备份临时状态"
        return 1
    fi
    if ! mv -- "$temporary_file" "$state_file"; then
        rm -f -- "$temporary_file" 2>/dev/null || true
        AUTO_BACKUP_LAST_ERROR="无法提交自动备份时间状态"
        return 1
    fi
    AUTO_BACKUP_LAST_SUCCESS_EPOCH="$last_epoch"
    AUTO_BACKUP_NEXT_EPOCH="$next_epoch"
    AUTO_BACKUP_STATE_STATUS="valid"
}

backup_scheduler_lock_release() {
    local lock_path lock_parent state_parent

    lock_path="$(backup_scheduler_lock_path)"
    [[ -d "$lock_path" && ! -L "$lock_path" ]] || return 0
    lock_parent="$(path_canonicalize_directory "$(dirname -- "$lock_path")")" || return 1
    state_parent="$(path_canonicalize_directory "$(dirname -- "$(backup_scheduler_state_file)")")" \
        || return 1
    [[ "$lock_parent" == "$state_parent" ]] || return 1
    rm -f -- "$lock_path/pid" 2>/dev/null || return 1
    rmdir -- "$lock_path" 2>/dev/null
}

backup_scheduler_lock_acquire() {
    local lock_path owner_pid

    backup_scheduler_state_directory_prepare || return 1
    lock_path="$(backup_scheduler_lock_path)"
    if mkdir -- "$lock_path" 2>/dev/null; then
        printf '%s\n' "$$" > "$lock_path/pid" || {
            backup_scheduler_lock_release || true
            AUTO_BACKUP_LAST_ERROR="无法记录自动备份检查锁"
            return 1
        }
        return 0
    fi
    [[ -d "$lock_path" && ! -L "$lock_path" ]] || {
        AUTO_BACKUP_LAST_ERROR="自动备份检查锁路径异常"
        return 1
    }
    owner_pid=""
    IFS= read -r owner_pid < "$lock_path/pid" 2>/dev/null || owner_pid=""
    if [[ "$owner_pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
        return 2
    fi
    backup_scheduler_lock_release || {
        AUTO_BACKUP_LAST_ERROR="无法清理失效的自动备份检查锁"
        return 1
    }
    if ! mkdir -- "$lock_path" 2>/dev/null; then
        return 2
    fi
    printf '%s\n' "$$" > "$lock_path/pid" || {
        backup_scheduler_lock_release || true
        AUTO_BACKUP_LAST_ERROR="无法记录自动备份检查锁"
        return 1
    }
}

backup_scheduler_format_epoch() {
    local epoch="$1"

    [[ "$epoch" =~ ^[1-9][0-9]*$ ]] || {
        printf '%s\n' "未安排"
        return 0
    }
    date -d "@$epoch" '+%Y-%m-%d %H:%M' 2>/dev/null || printf '%s\n' "未知"
}

backup_scheduler_next_display() {
    local state_status=0

    backup_scheduler_enabled || {
        printf '%s\n' "未安排"
        return 0
    }
    backup_scheduler_state_read || state_status=$?
    if (( state_status != 0 )) || (( AUTO_BACKUP_NEXT_EPOCH <= 0 )); then
        printf '%s\n' "未安排"
        return 0
    fi
    backup_scheduler_format_epoch "$AUTO_BACKUP_NEXT_EPOCH"
}

backup_scheduler_reset_schedule() {
    local now last_epoch=0 next_epoch state_status=0

    now="$(backup_current_epoch)"
    [[ "$now" =~ ^[1-9][0-9]*$ ]] || {
        AUTO_BACKUP_LAST_ERROR="无法读取当前 epoch 时间"
        return 1
    }
    backup_scheduler_state_read || state_status=$?
    if (( state_status == 0 )); then
        last_epoch="$AUTO_BACKUP_LAST_SUCCESS_EPOCH"
    fi
    next_epoch=$((now + $(backup_scheduler_interval_seconds)))
    backup_scheduler_state_write "$last_epoch" "$next_epoch" || return 1
    backup_log schedule success automatic-backup \
        "reset;next=$next_epoch;interval_days=$(backup_scheduler_interval_days)" || true
}

backup_scheduler_set_enabled() {
    local target="$1" last_epoch=0 state_status=0

    [[ "$target" == true || "$target" == false ]] || {
        AUTO_BACKUP_LAST_ERROR="自动备份开关值无效"
        return 1
    }
    if [[ "$target" == true ]]; then
        backup_scheduler_reset_schedule || return 1
        if ! config_set_value AUTO_BACKUP_ENABLED true; then
            AUTO_BACKUP_LAST_ERROR="无法保存自动备份开关"
            return 1
        fi
        AUTO_BACKUP_ENABLED=true
        backup_log settings success auto-backup "enabled" || true
        return 0
    fi

    if ! config_set_value AUTO_BACKUP_ENABLED false; then
        AUTO_BACKUP_LAST_ERROR="无法保存自动备份开关"
        return 1
    fi
    AUTO_BACKUP_ENABLED=false
    backup_scheduler_state_read || state_status=$?
    if (( state_status == 0 )); then
        last_epoch="$AUTO_BACKUP_LAST_SUCCESS_EPOCH"
    fi
    if ! backup_scheduler_state_write "$last_epoch" 0; then
        backup_log settings warning auto-backup "disabled;state_reset_failed=$AUTO_BACKUP_LAST_ERROR" || true
    fi
    backup_log settings success auto-backup "disabled" || true
}

backup_scheduler_set_interval_days() {
    local new_days="$1" old_days

    [[ "$new_days" =~ ^[0-9]+$ ]] && (( new_days >= 1 && new_days <= 30 )) || {
        AUTO_BACKUP_LAST_ERROR="备份频率必须是 1 到 30 天的整数"
        return 1
    }
    old_days="$(backup_scheduler_interval_days)"
    if ! config_set_value AUTO_BACKUP_INTERVAL_DAYS "$new_days"; then
        AUTO_BACKUP_LAST_ERROR="无法保存自动备份频率"
        return 1
    fi
    AUTO_BACKUP_INTERVAL_DAYS="$new_days"
    if backup_scheduler_enabled && ! backup_scheduler_reset_schedule; then
        config_set_value AUTO_BACKUP_INTERVAL_DAYS "$old_days" >/dev/null 2>&1 || true
        AUTO_BACKUP_INTERVAL_DAYS="$old_days"
        return 1
    fi
    backup_log settings success auto-backup-interval "$old_days->$new_days" || true
}

backup_scheduler_initialize_if_needed() {
    local state_status=0 next_epoch now

    backup_scheduler_state_read || state_status=$?
    if (( state_status == 0 )) && (( AUTO_BACKUP_NEXT_EPOCH > 0 )); then
        return 0
    fi
    now="$(backup_current_epoch)"
    [[ "$now" =~ ^[1-9][0-9]*$ ]] || {
        AUTO_BACKUP_LAST_ERROR="无法读取当前 epoch 时间"
        return 1
    }
    next_epoch=$((now + $(backup_scheduler_interval_seconds)))
    backup_scheduler_state_write 0 "$next_epoch" || return 1
    if (( state_status == 2 )); then
        backup_log auto-check warning automatic-backup "corrupt-state-reset;next=$next_epoch" || true
    else
        backup_log auto-check success automatic-backup "state-initialized;next=$next_epoch" || true
    fi
    return 0
}

backup_scheduler_completed_cycle_epoch() {
    local type="$1" scheduled_epoch="$2" expected_reason index reason

    expected_reason="automatic-$type:scheduled=$scheduled_epoch"
    backup_inventory_scan || return 1
    for ((index = 0; index < ${#BACKUP_PATHS[@]}; index++)); do
        [[ "${BACKUP_TYPES[index]}" == "$type" ]] || continue
        reason="$(backup_metadata_get "${BACKUP_PATHS[index]}/metadata.conf" BACKUP_REASON)" \
            || continue
        [[ "$reason" == "$expected_reason" ]] || continue
        backup_directory_is_valid "${BACKUP_PATHS[index]}" || continue
        printf '%s\n' "${BACKUP_EPOCHS[index]}"
        return 0
    done
    return 1
}

backup_scheduler_check_locked() {
    local now next_epoch interval_seconds type success_epoch new_next completed_epoch state_status=0

    AUTO_BACKUP_LAST_ERROR=""
    backup_scheduler_enabled || return 0
    if ! sillytavern_path_is_valid "${ST_PATH:-}"; then
        AUTO_BACKUP_LAST_ERROR="当前 SillyTavern 路径无效，已跳过自动备份"
        backup_log auto-check skipped automatic-backup "invalid-sillytavern-path" || true
        return 2
    fi
    backup_scheduler_initialize_if_needed || return 1
    backup_scheduler_state_read || state_status=$?
    (( state_status == 0 )) || {
        AUTO_BACKUP_LAST_ERROR="无法读取自动备份时间状态"
        return 1
    }

    now="$(backup_current_epoch)"
    [[ "$now" =~ ^[1-9][0-9]*$ ]] || {
        AUTO_BACKUP_LAST_ERROR="无法读取当前 epoch 时间"
        return 1
    }
    next_epoch="$AUTO_BACKUP_NEXT_EPOCH"
    interval_seconds="$(backup_scheduler_interval_seconds)"
    if (( now < next_epoch )); then
        backup_log auto-check success automatic-backup "not-due;now=$now;next=$next_epoch" || true
        return 0
    fi

    type=scheduled
    if (( now >= next_epoch + interval_seconds )); then
        type=catchup
    fi
    backup_log auto-check due automatic-backup \
        "type=$type;now=$now;scheduled=$next_epoch" || true
    completed_epoch="$(backup_scheduler_completed_cycle_epoch "$type" "$next_epoch" 2>/dev/null)" \
        || completed_epoch=""
    if [[ "$completed_epoch" =~ ^[1-9][0-9]*$ ]]; then
        new_next=$((completed_epoch + interval_seconds))
        backup_scheduler_state_write "$completed_epoch" "$new_next" || return 1
        backup_log "$type" recovered automatic-backup \
            "scheduled=$next_epoch;completed=$completed_epoch;next=$new_next" || true
        return 0
    fi
    if ! backup_create "$type" "automatic-$type:scheduled=$next_epoch"; then
        AUTO_BACKUP_LAST_ERROR="${BACKUP_LAST_ERROR:-自动备份创建失败}"
        backup_log "$type" failed automatic-backup "$AUTO_BACKUP_LAST_ERROR" || true
        return 1
    fi

    success_epoch="$(backup_current_epoch)"
    new_next=$((success_epoch + interval_seconds))
    if ! backup_scheduler_state_write "$success_epoch" "$new_next"; then
        backup_log "$type" failed "$(basename -- "${BACKUP_LAST_PATH:-automatic-backup}")" \
            "backup-created;state-update-failed=$AUTO_BACKUP_LAST_ERROR" || true
        return 1
    fi
    backup_log "$type" success "$(basename -- "${BACKUP_LAST_PATH:-automatic-backup}")" \
        "next=$new_next" || true
    backup_log schedule success automatic-backup "next=$new_next" || true
    return 0
}

backup_scheduler_check() {
    local lock_status=0 check_status=0

    backup_scheduler_enabled || return 0
    backup_scheduler_lock_acquire || lock_status=$?
    case "$lock_status" in
        0)
            ;;
        2)
            backup_log auto-check skipped automatic-backup "another-check-is-running" || true
            return 0
            ;;
        *)
            return 1
            ;;
    esac
    backup_scheduler_check_locked || check_status=$?
    if ! backup_scheduler_lock_release; then
        backup_log auto-check warning automatic-backup "lock-release-failed" || true
    fi
    return "$check_status"
}
