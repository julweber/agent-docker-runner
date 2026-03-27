# shellcheck shell=bash

# Detect if we have GNU date (Linux) or BSD date (macOS)
_detect_date_variant() {
    # Try GNU date syntax (-d flag parses datetime)
    if date -d "2024-01-01 00:00:00" +%s >/dev/null 2>&1; then
        echo "gnu"
    # Try BSD date syntax (-j flag prevents setting, -f parses datetime)
    elif date -j -f "%Y-%m-%d %H:%M:%S" "2024-01-01 00:00:00" +%s >/dev/null 2>&1; then
        echo "bsd"
    else
        echo "gnu"  # Default to GNU fallback
    fi
}

# Store the detected date variant at script load time
_DATE_VARIANT="$(_detect_date_variant)"

relative_time() {
    local created="$1"
    local created_epoch=""
    local now_epoch=""
    local diff=0
    local minutes=0
    local minute_suffix="s"
    local hours=0
    local hour_suffix="s"
    local days=0
    local day_suffix="s"
    local weeks=0
    local week_suffix="s"

    if [[ -z "$created" || ! "$created" =~ [0-9] ]]; then
        echo "-"
        return
    fi

    # Strip timezone info - use only the datetime portion
    # Docker format: "2026-03-25 12:01:06 +0100 CET" -> "2026-03-25 12:01:06"
    # This strips everything after the first 19 characters (datetime only)
    created="${created:0:19}"

    # Use OS-appropriate date syntax (GNU vs BSD)
    if [[ "$_DATE_VARIANT" == "gnu" ]]; then
        created_epoch=$(date -d "$created" +%s 2>/dev/null) || {
            echo "-"
            return
        }
    else
        # BSD/macOS: date -j -f format_string datetime +format
        created_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$created" +%s 2>/dev/null) || {
            echo "-"
            return
        }
    fi

    now_epoch=$(date +%s)
    diff=$((now_epoch - created_epoch))

    if (( diff < 0 )); then
        echo "(future?)"
        return
    fi

    if (( diff < 60 )); then
        echo "$diff seconds ago"
    elif (( diff < 3600 )); then
        minutes=$((diff / 60))
        [[ $minutes -eq 1 ]] && minute_suffix=""
        echo "$minutes minute${minute_suffix} ago"
    elif (( diff < 86400 )); then
        hours=$((diff / 3600))
        [[ $hours -eq 1 ]] && hour_suffix=""
        echo "$hours hour${hour_suffix} ago"
    elif (( diff < 604800 )); then
        days=$((diff / 86400))
        [[ $days -eq 1 ]] && day_suffix=""
        echo "$days day${day_suffix} ago"
    else
        weeks=$((diff / 604800))
        [[ $weeks -eq 1 ]] && week_suffix=""
        echo "$weeks week${week_suffix} ago"
    fi
}

cmd_status() {
    local has_built=false
    local agent=""
    local tag="${ADR_TAG:-latest}"
    local info=""
    local repo=""
    local image_tag=""
    local size=""
    local created=""
    local rel_time=""

    if ! docker_available; then
        echo "Error: Cannot reach Docker daemon. Is the Docker running?" >&2
        exit 1
    fi

    printf '%-9s %-30s %-10s %-10s %s\n' 'Agent' 'Image' 'Tag' 'Size' 'Built'
    echo "───────── ─────────────────────────────┬─── ────────  ─────────────"

    for agent in "${KNOWN_AGENTS[@]}"; do
        info=$(get_image_info "$agent" "$tag")

        if [[ "$info" == "NOT_FOUND" ]]; then
            printf '%-9s %-30s %-10s %-10s %s\n' "$agent" "(not built)" "-" "-" "-"
        else
            IFS='|' read -r _ repo image_tag size created <<< "$info"
            has_built=true
            rel_time=$(relative_time "$created")
            printf '%-9s %-30s %-10s %-10s %s\n' "$agent" "$repo:$image_tag" "$image_tag" "$size" "$rel_time"
        fi
    done

    if ! $has_built; then
        echo ""
        echo "Run 'adr build <agent>' to build an image."
    fi
}
