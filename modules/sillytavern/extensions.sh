#!/usr/bin/env bash

EXTENSION_SCAN_ERROR=""
EXTENSION_LAST_REFRESH_COMPLETE=false
EXTENSION_TOTAL_COUNT=0
EXTENSION_GIT_COUNT=0
EXTENSION_NON_GIT_COUNT=0
EXTENSION_UPDATE_COUNT=0
EXTENSION_MANUAL_UPDATE_COUNT=0
EXTENSION_FAILED_COUNT=0
EXTENSION_BATCH_SUCCESS=0
EXTENSION_BATCH_FAILED=0
EXTENSION_BATCH_SKIPPED=0

declare -a EXTENSION_NAMES=()
declare -a EXTENSION_PATHS=()
declare -a EXTENSION_IS_GIT=()
declare -a EXTENSION_POLICIES=()
declare -a EXTENSION_STATUSES=()
declare -a EXTENSION_UPSTREAMS=()
declare -a EXTENSION_AHEADS=()
declare -a EXTENSION_BEHINDS=()
declare -a EXTENSION_ERRORS=()
declare -a EXTENSION_SELECTED_INDEXES=()
declare -a EXTENSION_BATCH_FAILED_NAMES=()
declare -a EXTENSION_BATCH_FAILED_ERRORS=()

sillytavern_extensions_root() {
    printf '%s\n' "$ST_PATH/public/scripts/extensions/third-party"
}

sillytavern_extension_policy_file() {
    printf '%s\n' "$STERMUX_ROOT/config/extension-policy.conf"
}

sillytavern_extension_log_file() {
    printf '%s\n' "$STERMUX_ROOT/data/logs/extension-update.log"
}

sillytavern_extension_name_is_policy_safe() {
    local name="$1"

    [[ -n "$name" ]] || return 1
    [[ "$name" != *$'\n'* && "$name" != *$'\r'* && "$name" != *'='* ]]
}

sillytavern_extension_policy_get() {
    local extension_name="$1"
    local policy_file
    local line
    local key
    local value

    policy_file="$(sillytavern_extension_policy_file)"
    [[ -r "$policy_file" ]] || {
        printf '%s\n' "auto"
        return 0
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ -n "$line" && "$line" != \#* && "$line" == *=* ]] || continue
        key="${line%%=*}"
        value="${line#*=}"
        if [[ "$key" == "$extension_name" ]]; then
            case "$value" in
                auto|manual)
                    printf '%s\n' "$value"
                    return 0
                    ;;
            esac
        fi
    done < "$policy_file"

    printf '%s\n' "auto"
}

sillytavern_extension_policy_set() {
    local extension_name="$1"
    local policy="$2"
    local policy_file
    local policy_dir
    local temporary_file
    local line
    local key

    sillytavern_extension_name_is_policy_safe "$extension_name" || return 1
    [[ "$policy" == "auto" || "$policy" == "manual" ]] || return 1

    policy_file="$(sillytavern_extension_policy_file)"
    policy_dir="$(dirname -- "$policy_file")"
    temporary_file="$policy_file.tmp.$$"
    mkdir -p -- "$policy_dir" || return 1
    : > "$temporary_file" || return 1

    if [[ -f "$policy_file" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            key=""
            if [[ "$line" == *=* ]]; then
                key="${line%%=*}"
            fi
            if [[ "$key" != "$extension_name" ]]; then
                printf '%s\n' "$line" >> "$temporary_file" || return 1
            fi
        done < "$policy_file"
    fi

    if [[ "$policy" == "manual" ]]; then
        printf '%s=manual\n' "$extension_name" >> "$temporary_file" || return 1
    fi

    if ! mv -- "$temporary_file" "$policy_file"; then
        rm -f -- "$temporary_file" 2>/dev/null || true
        return 1
    fi
    return 0
}

sillytavern_extensions_reset_inventory() {
    EXTENSION_SCAN_ERROR=""
    EXTENSION_LAST_REFRESH_COMPLETE=false
    EXTENSION_TOTAL_COUNT=0
    EXTENSION_GIT_COUNT=0
    EXTENSION_NON_GIT_COUNT=0
    EXTENSION_UPDATE_COUNT=0
    EXTENSION_MANUAL_UPDATE_COUNT=0
    EXTENSION_FAILED_COUNT=0
    EXTENSION_NAMES=()
    EXTENSION_PATHS=()
    EXTENSION_IS_GIT=()
    EXTENSION_POLICIES=()
    EXTENSION_STATUSES=()
    EXTENSION_UPSTREAMS=()
    EXTENSION_AHEADS=()
    EXTENSION_BEHINDS=()
    EXTENSION_ERRORS=()
}

sillytavern_extensions_recount() {
    local index
    local status

    EXTENSION_TOTAL_COUNT="${#EXTENSION_NAMES[@]}"
    EXTENSION_GIT_COUNT=0
    EXTENSION_NON_GIT_COUNT=0
    EXTENSION_UPDATE_COUNT=0
    EXTENSION_MANUAL_UPDATE_COUNT=0
    EXTENSION_FAILED_COUNT=0

    for ((index = 0; index < EXTENSION_TOTAL_COUNT; index++)); do
        if [[ "${EXTENSION_IS_GIT[index]}" == true ]]; then
            EXTENSION_GIT_COUNT=$((EXTENSION_GIT_COUNT + 1))
        else
            EXTENSION_NON_GIT_COUNT=$((EXTENSION_NON_GIT_COUNT + 1))
        fi
        status="${EXTENSION_STATUSES[index]}"
        case "$status" in
            update_available)
                EXTENSION_UPDATE_COUNT=$((EXTENSION_UPDATE_COUNT + 1))
                ;;
            manual_only_update_available)
                EXTENSION_MANUAL_UPDATE_COUNT=$((EXTENSION_MANUAL_UPDATE_COUNT + 1))
                ;;
            fetch_failed|no_upstream|update_failed)
                EXTENSION_FAILED_COUNT=$((EXTENSION_FAILED_COUNT + 1))
                ;;
        esac
    done
}

sillytavern_extensions_scan() {
    local root
    local extension_path
    local extension_name
    local policy
    local -a candidates=()
    local nullglob_was_enabled=false

    sillytavern_extensions_reset_inventory
    root="$(sillytavern_extensions_root)"
    if [[ ! -e "$root" ]]; then
        return 0
    fi
    if [[ ! -d "$root" || ! -r "$root" ]]; then
        EXTENSION_SCAN_ERROR="第三方扩展目录无法读取：$root"
        return 1
    fi

    if shopt -q nullglob; then
        nullglob_was_enabled=true
    else
        shopt -s nullglob
    fi
    candidates=("$root"/*)
    if [[ "$nullglob_was_enabled" == false ]]; then
        shopt -u nullglob
    fi
    for extension_path in "${candidates[@]}"; do
        [[ -d "$extension_path" ]] || continue
        extension_name="$(basename -- "$extension_path")"
        policy="$(sillytavern_extension_policy_get "$extension_name")"
        EXTENSION_NAMES+=("$extension_name")
        EXTENSION_PATHS+=("$extension_path")
        EXTENSION_POLICIES+=("$policy")
        EXTENSION_UPSTREAMS+=("unknown")
        EXTENSION_AHEADS+=(0)
        EXTENSION_BEHINDS+=(0)
        EXTENSION_ERRORS+=("")
        if [[ -d "$extension_path/.git" || -f "$extension_path/.git" ]]; then
            EXTENSION_IS_GIT+=(true)
            EXTENSION_STATUSES+=(not_checked)
        else
            EXTENSION_IS_GIT+=(false)
            EXTENSION_STATUSES+=(not_git)
        fi
    done
    sillytavern_extensions_recount
    return 0
}

sillytavern_extension_refresh_index() {
    local index="$1"
    local path
    local policy
    local upstream
    local git_output

    (( index >= 0 && index < ${#EXTENSION_NAMES[@]} )) || return 1
    path="${EXTENSION_PATHS[index]}"
    policy="$(sillytavern_extension_policy_get "${EXTENSION_NAMES[index]}")"
    EXTENSION_POLICIES[index]="$policy"
    EXTENSION_UPSTREAMS[index]="unknown"
    EXTENSION_AHEADS[index]=0
    EXTENSION_BEHINDS[index]=0
    EXTENSION_ERRORS[index]=""

    if [[ "${EXTENSION_IS_GIT[index]}" != true ]]; then
        EXTENSION_STATUSES[index]="not_git"
        return 1
    fi
    if ! command -v git >/dev/null 2>&1; then
        EXTENSION_STATUSES[index]="fetch_failed"
        EXTENSION_ERRORS[index]="未找到 git 命令"
        return 1
    fi
    git_output="$(git --version 2>&1)" || {
        EXTENSION_STATUSES[index]="fetch_failed"
        EXTENSION_ERRORS[index]="git 命令无法运行：$(git_message_one_line "$git_output")"
        return 1
    }
    if ! git_repository_is_valid "$path"; then
        EXTENSION_IS_GIT[index]=false
        EXTENSION_STATUSES[index]="not_git"
        EXTENSION_ERRORS[index]=".git 存在，但目录不是有效 Git 工作区"
        return 1
    fi
    if ! git_current_branch "$path" >/dev/null; then
        EXTENSION_STATUSES[index]="no_upstream"
        EXTENSION_ERRORS[index]="扩展处于 detached HEAD"
        return 1
    fi
    upstream="$(git_current_upstream "$path")" || {
        EXTENSION_STATUSES[index]="no_upstream"
        EXTENSION_ERRORS[index]="当前分支没有 upstream"
        return 1
    }
    EXTENSION_UPSTREAMS[index]="$upstream"
    if ! git_fetch_upstream "$path"; then
        EXTENSION_STATUSES[index]="fetch_failed"
        EXTENSION_ERRORS[index]="$GIT_LAST_ERROR"
        return 1
    fi
    if ! git_compare_upstream "$path"; then
        EXTENSION_STATUSES[index]="fetch_failed"
        EXTENSION_ERRORS[index]="$GIT_LAST_ERROR"
        return 1
    fi

    EXTENSION_UPSTREAMS[index]="$GIT_UPSTREAM"
    EXTENSION_AHEADS[index]="$GIT_AHEAD_COUNT"
    EXTENSION_BEHINDS[index]="$GIT_BEHIND_COUNT"
    if (( GIT_BEHIND_COUNT == 0 )); then
        EXTENSION_STATUSES[index]="latest"
    elif [[ "$policy" == "manual" ]]; then
        EXTENSION_STATUSES[index]="manual_only_update_available"
    else
        EXTENSION_STATUSES[index]="update_available"
    fi
    return 0
}

sillytavern_extensions_refresh_all() {
    local index

    for ((index = 0; index < ${#EXTENSION_NAMES[@]}; index++)); do
        sillytavern_extension_refresh_index "$index" || true
    done
    EXTENSION_LAST_REFRESH_COMPLETE=true
    sillytavern_extensions_recount
    return 0
}

sillytavern_extension_status_text() {
    local index="$1"
    local status="${EXTENSION_STATUSES[index]}"

    case "$status" in
        not_checked) printf '%s\n' "尚未检测" ;;
        latest) printf '%s\n' "最新" ;;
        update_available) printf '可更新 %s 个 Commit\n' "${EXTENSION_BEHINDS[index]}" ;;
        manual_only_update_available) printf '可更新 %s 个 Commit，仅手动\n' "${EXTENSION_BEHINDS[index]}" ;;
        fetch_failed) printf '%s\n' "检测失败" ;;
        no_upstream) printf '%s\n' "无 upstream" ;;
        not_git) printf '%s\n' "非 Git 安装" ;;
        update_failed) printf '%s\n' "更新失败" ;;
        *) printf '%s\n' "未知状态" ;;
    esac
}

sillytavern_extensions_show_list() {
    local index

    printf '\n第三方扩展\n\n'
    printf '已识别：%s  Git：%s  非 Git：%s\n' \
        "$EXTENSION_TOTAL_COUNT" "$EXTENSION_GIT_COUNT" "$EXTENSION_NON_GIT_COUNT"
    printf '可自动更新：%s  仅手动可更新：%s  检测失败：%s\n\n' \
        "$EXTENSION_UPDATE_COUNT" "$EXTENSION_MANUAL_UPDATE_COUNT" "$EXTENSION_FAILED_COUNT"

    if [[ -n "$EXTENSION_SCAN_ERROR" ]]; then
        ui_error "$EXTENSION_SCAN_ERROR"
        return 1
    fi
    if (( EXTENSION_TOTAL_COUNT == 0 )); then
        ui_info "未发现全局 third-party 扩展。"
        return 0
    fi
    for ((index = 0; index < EXTENSION_TOTAL_COUNT; index++)); do
        printf '%d. %s — %s\n' "$((index + 1))" "${EXTENSION_NAMES[index]}" \
            "$(sillytavern_extension_status_text "$index")"
    done
}

sillytavern_extension_show_details() {
    local index="$1"

    (( index >= 0 && index < EXTENSION_TOTAL_COUNT )) || return 1
    printf '\n扩展技术详情\n\n'
    printf '名称：%s\n' "${EXTENSION_NAMES[index]}"
    printf '路径：%s\n' "${EXTENSION_PATHS[index]}"
    printf '策略：%s\n' "${EXTENSION_POLICIES[index]}"
    printf '状态：%s\n' "$(sillytavern_extension_status_text "$index")"
    printf 'Upstream：%s\n' "${EXTENSION_UPSTREAMS[index]}"
    printf 'ahead / behind：领先 %s，落后 %s\n' \
        "${EXTENSION_AHEADS[index]}" "${EXTENSION_BEHINDS[index]}"
    if [[ -n "${EXTENSION_ERRORS[index]}" ]]; then
        printf '错误摘要：%s\n' "${EXTENSION_ERRORS[index]}"
    fi
}

sillytavern_extension_log_result() {
    local extension_name="$1"
    local before_commit="$2"
    local after_commit="$3"
    local result="$4"
    local error_summary="${5:-}"
    local log_file

    log_file="$(sillytavern_extension_log_file)"
    mkdir -p -- "$(dirname -- "$log_file")" 2>/dev/null || return 1
    extension_name="$(git_message_one_line "$extension_name")"
    error_summary="$(git_message_one_line "$error_summary")"
    [[ -n "$error_summary" ]] || error_summary="-"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S %z')" "$extension_name" \
        "$before_commit" "$after_commit" "$result" "$error_summary" >> "$log_file"
}

sillytavern_extension_update_index() {
    local index="$1"
    local already_refreshed="${2:-false}"
    local name
    local path
    local before_commit
    local after_commit

    (( index >= 0 && index < EXTENSION_TOTAL_COUNT )) || return 1
    name="${EXTENSION_NAMES[index]}"
    path="${EXTENSION_PATHS[index]}"
    if [[ "$already_refreshed" != true ]]; then
        sillytavern_extension_refresh_index "$index" || true
    fi

    case "${EXTENSION_STATUSES[index]}" in
        latest)
            before_commit="$(git_current_commit "$path")" || before_commit="unknown"
            sillytavern_extension_log_result "$name" "$before_commit" "$before_commit" \
                "skipped" "已是最新" || true
            return 3
            ;;
        update_available|manual_only_update_available)
            ;;
        *)
            before_commit="$(git_current_commit "$path")" || before_commit="unknown"
            sillytavern_extension_log_result "$name" "$before_commit" "$before_commit" \
                "failed" "${EXTENSION_ERRORS[index]:-当前状态无法更新}" || true
            return 1
            ;;
    esac

    before_commit="$(git_current_commit "$path")" || before_commit="unknown"
    after_commit="$before_commit"
    if git_has_unmerged_files "$path"; then
        EXTENSION_STATUSES[index]="update_failed"
        EXTENSION_ERRORS[index]="存在未解决的合并冲突"
        sillytavern_extension_log_result "$name" "$before_commit" "$after_commit" \
            "failed" "${EXTENSION_ERRORS[index]}" || true
        return 1
    fi
    if ! git_pull_rebase_autostash "$path"; then
        EXTENSION_STATUSES[index]="update_failed"
        EXTENSION_ERRORS[index]="$GIT_LAST_ERROR"
        after_commit="$(git_current_commit "$path")" || after_commit="$before_commit"
        sillytavern_extension_log_result "$name" "$before_commit" "$after_commit" \
            "failed" "${EXTENSION_ERRORS[index]}" || true
        return 1
    fi

    after_commit="$(git_current_commit "$path")" || after_commit="unknown"
    EXTENSION_STATUSES[index]="latest"
    EXTENSION_AHEADS[index]=0
    EXTENSION_BEHINDS[index]=0
    EXTENSION_ERRORS[index]=""
    sillytavern_extension_log_result "$name" "$before_commit" "$after_commit" "success" "" || true
    return 0
}

sillytavern_extension_parse_selection() {
    local input="$1"
    local normalized
    local token
    local index
    local existing
    local duplicate

    EXTENSION_SELECTED_INDEXES=()
    normalized="${input//,/ }"
    for token in $normalized; do
        [[ "$token" =~ ^[0-9]+$ ]] || continue
        (( token >= 1 && token <= EXTENSION_TOTAL_COUNT )) || continue
        index=$((token - 1))
        duplicate=false
        for existing in "${EXTENSION_SELECTED_INDEXES[@]}"; do
            if (( existing == index )); then
                duplicate=true
                break
            fi
        done
        if [[ "$duplicate" == false ]]; then
            EXTENSION_SELECTED_INDEXES+=("$index")
        fi
    done
    (( ${#EXTENSION_SELECTED_INDEXES[@]} > 0 ))
}

sillytavern_extension_reset_batch_result() {
    EXTENSION_BATCH_SUCCESS=0
    EXTENSION_BATCH_FAILED=0
    EXTENSION_BATCH_SKIPPED=0
    EXTENSION_BATCH_FAILED_NAMES=()
    EXTENSION_BATCH_FAILED_ERRORS=()
}

sillytavern_extension_batch_update() {
    local mode="$1"
    shift
    local index
    local update_status

    sillytavern_extension_reset_batch_result
    for index in "$@"; do
        if (( index < 0 || index >= EXTENSION_TOTAL_COUNT )); then
            EXTENSION_BATCH_SKIPPED=$((EXTENSION_BATCH_SKIPPED + 1))
            continue
        fi

        ui_info "正在检查扩展：${EXTENSION_NAMES[index]}"
        sillytavern_extension_refresh_index "$index" || true
        if [[ "$mode" == "auto" && "${EXTENSION_POLICIES[index]}" == "manual" ]]; then
            EXTENSION_BATCH_SKIPPED=$((EXTENSION_BATCH_SKIPPED + 1))
            sillytavern_extension_log_result "${EXTENSION_NAMES[index]}" \
                "$(git_current_commit "${EXTENSION_PATHS[index]}" 2>/dev/null || printf '%s' unknown)" \
                "$(git_current_commit "${EXTENSION_PATHS[index]}" 2>/dev/null || printf '%s' unknown)" \
                "skipped" "仅手动更新策略" || true
            continue
        fi
        if [[ "$mode" == "auto" && "${EXTENSION_STATUSES[index]}" == "not_git" ]]; then
            EXTENSION_BATCH_SKIPPED=$((EXTENSION_BATCH_SKIPPED + 1))
            sillytavern_extension_log_result "${EXTENSION_NAMES[index]}" \
                "unknown" "unknown" "skipped" "非 Git 安装" || true
            continue
        fi

        ui_info "正在处理扩展：${EXTENSION_NAMES[index]}"
        update_status=0
        sillytavern_extension_update_index "$index" true || update_status=$?
        case "$update_status" in
            0)
                EXTENSION_BATCH_SUCCESS=$((EXTENSION_BATCH_SUCCESS + 1))
                ;;
            3)
                EXTENSION_BATCH_SKIPPED=$((EXTENSION_BATCH_SKIPPED + 1))
                ;;
            *)
                EXTENSION_BATCH_FAILED=$((EXTENSION_BATCH_FAILED + 1))
                EXTENSION_BATCH_FAILED_NAMES+=("${EXTENSION_NAMES[index]}")
                EXTENSION_BATCH_FAILED_ERRORS+=("${EXTENSION_ERRORS[index]:-当前状态无法更新}")
                ;;
        esac
    done
    sillytavern_extensions_recount
    return 0
}

sillytavern_extension_show_batch_summary() {
    local index

    printf '\n更新完成\n\n'
    printf '成功：%s\n' "$EXTENSION_BATCH_SUCCESS"
    printf '失败：%s\n' "$EXTENSION_BATCH_FAILED"
    printf '跳过：%s\n' "$EXTENSION_BATCH_SKIPPED"
    if (( EXTENSION_BATCH_FAILED > 0 )); then
        printf '\n失败项目：\n'
        for ((index = 0; index < ${#EXTENSION_BATCH_FAILED_NAMES[@]}; index++)); do
            printf -- '- %s：%s\n' "${EXTENSION_BATCH_FAILED_NAMES[index]}" \
                "${EXTENSION_BATCH_FAILED_ERRORS[index]}"
        done
    fi
}

sillytavern_extension_confirm_selection() {
    local action="$1"
    shift
    local index
    local confirm

    printf '\n即将%s：\n' "$action"
    for index in "$@"; do
        printf -- '- %s\n' "${EXTENSION_NAMES[index]}"
    done
    printf '确认继续？[y/N] '
    IFS= read -r confirm || return 1
    [[ "$confirm" == "y" || "$confirm" == "Y" ]]
}

sillytavern_extension_prompt_selection() {
    local prompt="$1"
    local allow_multiple="$2"
    local input

    (( EXTENSION_TOTAL_COUNT > 0 )) || {
        ui_warning "当前没有可选择的扩展。"
        return 1
    }
    printf '%s' "$prompt"
    IFS= read -r input || return 1
    sillytavern_extension_parse_selection "$input" || {
        ui_warning "没有有效的扩展编号。"
        return 1
    }
    if [[ "$allow_multiple" != true && ${#EXTENSION_SELECTED_INDEXES[@]} -ne 1 ]]; then
        ui_warning "该操作只能选择一个扩展。"
        return 1
    fi
    return 0
}

sillytavern_extension_update_selected_interactive() {
    local allow_multiple="$1"
    local prompt

    if [[ "$allow_multiple" == true ]]; then
        prompt='请输入扩展编号（支持空格或逗号分隔）：'
    else
        prompt='请输入一个扩展编号：'
    fi
    sillytavern_extension_prompt_selection "$prompt" "$allow_multiple" || return 1
    sillytavern_extension_confirm_selection "更新扩展" "${EXTENSION_SELECTED_INDEXES[@]}" || {
        ui_info "已取消扩展更新。"
        return 0
    }
    sillytavern_extension_batch_update "explicit" "${EXTENSION_SELECTED_INDEXES[@]}"
    sillytavern_extension_show_batch_summary
}

sillytavern_extension_update_all_interactive() {
    local index
    local -a all_indexes=()

    for ((index = 0; index < EXTENSION_TOTAL_COUNT; index++)); do
        all_indexes+=("$index")
    done
    (( ${#all_indexes[@]} > 0 )) || {
        ui_warning "当前没有可更新的扩展。"
        return 1
    }
    ui_warning "仅手动更新的扩展会被自动跳过。"
    sillytavern_extension_confirm_selection "检查并更新全部允许自动更新的扩展" \
        "${all_indexes[@]}" || {
        ui_info "已取消批量更新。"
        return 0
    }
    sillytavern_extension_batch_update "auto" "${all_indexes[@]}"
    sillytavern_extension_show_batch_summary
}

sillytavern_extension_set_policy_interactive() {
    local policy="$1"
    local index

    sillytavern_extension_prompt_selection \
        '请输入扩展编号（支持空格或逗号分隔）：' true || return 1
    for index in "${EXTENSION_SELECTED_INDEXES[@]}"; do
        if sillytavern_extension_policy_set "${EXTENSION_NAMES[index]}" "$policy"; then
            EXTENSION_POLICIES[index]="$policy"
            if [[ "${EXTENSION_STATUSES[index]}" == "update_available" && "$policy" == "manual" ]]; then
                EXTENSION_STATUSES[index]="manual_only_update_available"
            elif [[ "${EXTENSION_STATUSES[index]}" == "manual_only_update_available" && "$policy" == "auto" ]]; then
                EXTENSION_STATUSES[index]="update_available"
            fi
            ui_success "${EXTENSION_NAMES[index]} 已设置为 $policy。"
        else
            ui_error "无法保存 ${EXTENSION_NAMES[index]} 的更新策略。"
        fi
    done
    sillytavern_extensions_recount
}

sillytavern_extension_show_policies() {
    local index

    printf '\n第三方扩展更新策略\n\n'
    if (( EXTENSION_TOTAL_COUNT == 0 )); then
        ui_info "暂无扩展策略。"
        return 0
    fi
    for ((index = 0; index < EXTENSION_TOTAL_COUNT; index++)); do
        printf '%d. %s：%s\n' "$((index + 1))" "${EXTENSION_NAMES[index]}" \
            "${EXTENSION_POLICIES[index]}"
    done
}

sillytavern_extension_show_details_interactive() {
    sillytavern_extension_prompt_selection '请输入一个扩展编号：' false || return 1
    sillytavern_extension_refresh_index "${EXTENSION_SELECTED_INDEXES[0]}" || true
    sillytavern_extension_show_details "${EXTENSION_SELECTED_INDEXES[0]}"
}

sillytavern_extensions_menu() {
    local choice

    sillytavern_extensions_scan || true
    while true; do
        ui_clear
        sillytavern_extensions_show_list || true
        printf '\n1. 扫描并检查更新\n'
        printf '2. 更新一个扩展\n'
        printf '3. 选择多个扩展更新\n'
        printf '4. 更新全部允许自动更新的扩展\n'
        printf '5. 设置为仅手动更新\n'
        printf '6. 取消仅手动更新\n'
        printf '7. 查看当前更新策略\n'
        printf '8. 查看扩展技术详情\n'
        printf '0. 返回主菜单\n\n'
        printf '请选择操作：'
        IFS= read -r choice || return 0

        case "$choice" in
            1)
                ui_info "正在重新扫描并检查第三方扩展..."
                if sillytavern_extensions_scan; then
                    sillytavern_extensions_refresh_all
                    sillytavern_extensions_show_list
                else
                    ui_error "$EXTENSION_SCAN_ERROR"
                fi
                ui_pause
                ;;
            2)
                sillytavern_extension_update_selected_interactive false || true
                ui_pause
                ;;
            3)
                sillytavern_extension_update_selected_interactive true || true
                ui_pause
                ;;
            4)
                sillytavern_extension_update_all_interactive || true
                ui_pause
                ;;
            5)
                sillytavern_extension_set_policy_interactive manual || true
                ui_pause
                ;;
            6)
                sillytavern_extension_set_policy_interactive auto || true
                ui_pause
                ;;
            7)
                sillytavern_extension_show_policies
                ui_pause
                ;;
            8)
                sillytavern_extension_show_details_interactive || true
                ui_pause
                ;;
            0)
                return 0
                ;;
            *)
                ui_warning "无效选项，请输入 0 到 8。"
                ui_pause
                ;;
        esac
    done
}
