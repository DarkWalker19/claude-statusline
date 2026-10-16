#!/usr/bin/env bash
# Claude Code status line (Linux / macOS / WSL). Needs: bash, jq, awk, date.
export LC_TIME=C   # English weekday names, like the PowerShell version

raw=$(cat)
if ! jq -e . >/dev/null 2>&1 <<<"$raw"; then
    echo "statusline: bad input"
    exit 0
fi

{
    IFS= read -r model
    IFS= read -r ctx
    IFS= read -r five_pct
    IFS= read -r five_at
    IFS= read -r week_pct
    IFS= read -r week_at
} < <(jq -r '
    (.model.display_name // ""),
    (.context_window.used_percentage // ""),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // "")
' <<<"$raw" | tr -d '\r')

esc=$'\033'
dim="${esc}[90m"
off="${esc}[0m"
full="█"
empty="░"

repeat() { # repeat <string> <count>
    local out="" i
    for ((i = 0; i < $2; i++)); do out+="$1"; done
    printf '%s' "$out"
}

# Bar + percentage, e.g. "███░░░░░░░  30%"
bar() {
    local p n color width=10
    read -r p n < <(awk -v p="$1" -v w="$width" 'BEGIN {
        if (p < 0) p = 0; if (p > 100) p = 100
        printf "%.0f %.0f\n", p, p / 100 * w
    }')
    if   ((p >= 85)); then color=31   # red
    elif ((p >= 60)); then color=33   # yellow
    else color=32; fi                 # green
    printf '%s[%sm%s%s%s%s%s %s[%sm%3d%%%s' \
        "$esc" "$color" "$(repeat "$full" "$n")" "$dim" "$(repeat "$empty" $((width - n)))" "$off" "" \
        "$esc" "$color" "$p" "$off"
}

# Unix seconds from a number or (GNU date only) an ISO timestamp
to_epoch() {
    [[ -z $1 ]] && return 1
    if [[ $1 =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        printf '%.0f' "$1"
    else
        date -d "$1" +%s 2>/dev/null
    fi
}

fmt_date() { # fmt_date <epoch> <format>  (GNU date, then BSD date)
    date -d "@$1" "+$2" 2>/dev/null || date -r "$1" "+$2"
}

# Compact countdown for the bottom line, e.g. " 2h12m"
countdown() {
    local left=$(($1 - $(date +%s))) out
    if ((left <= 0)); then
        printf ' ~0m'
        return
    fi
    if ((left >= 86400)); then
        out=$(printf '%dd%dh' $((left / 86400)) $((left % 86400 / 3600)))
    elif ((left >= 3600)); then
        out=$(printf '%dh%02dm' $((left / 3600)) $((left % 3600 / 60)))
    else
        out=$(printf '%dm' $(((left + 59) / 60)))
    fi
    printf ' %s%s%s' "$dim" "$out" "$off"
}

# Absolute reset time for the top line, e.g. "19:06" (today) or "Mon 16:53"
reset_at() {
    if [[ $(fmt_date "$1" %F) == "$(date +%F)" ]]; then
        fmt_date "$1" %H:%M
    else
        fmt_date "$1" "%a %H:%M"
    fi
}

# Visible length: ignore ANSI colour codes, count each bar block as one column
vlen() {
    local s
    s=$(sed -e "s/${esc}\[[0-9;]*m//g" -e "s/$full/#/g" -e "s/$empty/#/g" <<<"$1")
    echo "${#s}"
}

pad() { # pad <string> <width>
    local n=$(($2 - $(vlen "$1")))
    printf '%s' "$1"
    ((n > 0)) && printf '%*s' "$n" ""
}

# Each column is a (top, bottom) pair so both lines line up.
top=()
bot=()

# Before the first message the context % is empty: show 0 instead of hiding the column
top+=("${dim}${model}${off}")
bot+=("ctx $(bar "${ctx:-0}")")

add_limit() { # add_limit <label> <pct> <resets_at>
    [[ -z $2 ]] && return
    local at label_part="$1" cd=""
    if at=$(to_epoch "$3") && [[ -n $at ]]; then
        label_part+="${dim} resets $(reset_at "$at")${off}"
        cd=$(countdown "$at")
    fi
    top+=("$label_part")
    bot+=("$(bar "$2")$cd")
}
add_limit session "$five_pct" "$five_at"
add_limit week "$week_pct" "$week_at"

sep=" ${dim}|${off} "
l1="" l2="" top_text=""
last=$((${#top[@]} - 1))
for i in "${!top[@]}"; do
    a=${top[$i]} b=${bot[$i]}
    top_text+=$a
    if ((i < last)); then
        w=$(vlen "$a"); wb=$(vlen "$b"); ((wb > w)) && w=$wb
        a=$(pad "$a" "$w"); b=$(pad "$b" "$w")
    fi
    ((i > 0)) && { l1+="$sep"; l2+="$sep"; }
    l1+=$a
    l2+=$b
done

# Update check: only when this script lives in a git clone with an upstream.
# Fetches in the background at most every 6 hours (never pulls) and just compares commits.
# Opt out with the STATUSLINE_NO_UPDATE_CHECK environment variable.
update_notice() {
    [[ -n $STATUSLINE_NO_UPDATE_CHECK ]] && return
    command -v git >/dev/null 2>&1 || return
    local dir git_dir stamp behind
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || return
    git_dir=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null) || return
    stamp="$git_dir/statusline-update-check"
    if [[ -z $(find "$stamp" -mmin -360 2>/dev/null) ]]; then
        : >"$stamp"   # stamp first so parallel refreshes don't pile up fetches
        GIT_TERMINAL_PROMPT=0 git -C "$dir" fetch --quiet </dev/null >/dev/null 2>&1 &
        disown 2>/dev/null
    fi
    behind=$(git -C "$dir" rev-list --count 'HEAD..@{u}' 2>/dev/null)
    if [[ $behind =~ ^[1-9] ]]; then
        printf ' %s[33mupdate available%s%s - run: git -C "%s" pull%s' "$esc" "$off" "$dim" "$dir" "$off"
    fi
}

# Top line = labels/details, bottom line = bars
(($(vlen "$top_text") > 0)) && printf '%s%s\n' "$l1" "$(update_notice)"
printf '%s\n' "$l2"
