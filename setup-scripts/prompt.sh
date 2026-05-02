#!/usr/bin/env bash
# ── Clean Bash Prompt (v4 — Production Grade) ─────────────────

[[ -z "${BASH_VERSION-}" ]] && return 0 2>/dev/null
[[ $- != *i* ]] && return 0 2>/dev/null

export VIRTUAL_ENV_DISABLE_PROMPT=1
shopt -s checkwinsize

# ── Glyphs & Colors ───────────────────────────────────────────
G_TL=$'\u256d'      # ╭
G_BL=$'\u2570'      # ╰
G_V=$'\u2502'        # │
G_H=$'\u2500'        # ─
G_RARROW=$'\u276f'   # ❯
G_GEAR=$'\u2699'     # ⚙
G_CROSS=$'\u2717'    # ✗
G_UP=$'\u2191'       # ↑
G_DOWN=$'\u2193'     # ↓
G_STASH=$'\u2261'    # ≡
G_TIMER=$'\u23f1'    # ⏱

# Powerline glyph with plain-text fallback
if [[ "$TERM" == *256color* || "$TERM" == *rxvt* || "$TERM" == *alacritty* ]]; then
    G_BRANCH=$'\ue0a0'   #  (Nerd/Powerline font)
else
    G_BRANCH=$'\u2261'   # ≡ (plain fallback)
fi

C_CYAN='\[\e[1;36m\]'
C_YELLOW='\[\e[1;33m\]'
C_RED='\[\e[1;31m\]'
C_GREEN='\[\e[1;32m\]'
C_MAGENTA='\[\e[1;35m\]'
C_BLUE='\[\e[1;34m\]'
C_RESET='\[\e[0m\]'

# ── Environment Checks ────────────────────────────────────────
IS_SSH=0
[[ -n "${SSH_CONNECTION-}" || -n "${SSH_CLIENT-}" || -n "${SSH_TTY-}" ]] && IS_SSH=1

# ── Timer Logic ───────────────────────────────────────────────
__timer_running=0
__timer_start_time=0
__prompt_building=0

__prompt_timer_trap() {
    [[ "${BASH_COMMAND-}" == *"__prompt_build"* ]] && return
    (( __prompt_building == 1 )) && return

    # Invalidate git cache when any git command runs — fixes stale
    # status after git add/commit/stash/checkout without cd
    if [[ "${BASH_COMMAND-}" == git[\ \	]* ]]; then
        __git_cached=0
    fi

    if (( __timer_running == 0 )); then
        __timer_start_time=${EPOCHSECONDS:-$SECONDS}
        __timer_running=1
    fi
}
trap '__prompt_timer_trap' DEBUG

# ── Git Cache (repo-root based, stat-free) ────────────────────
# Stores the repo ROOT path so lateral cd within the same repo
# (src/ → ../docs/) doesn't re-run git commands.
__git_cached=0
__git_cache_root=""
__git_cache_branch=""
__git_cache_state=""

__git_has_cmd=0
__git_checked=0

__get_git() {
    # Cache git binary existence once
    if (( __git_checked == 0 )); then
        command -v git &>/dev/null && __git_has_cmd=1
        __git_checked=1
    fi
    (( __git_has_cmd == 0 )) && return

    local cwd="$PWD"

    # Fast path: inside the same cached repo tree — no git calls
    if (( __git_cached == 1 )) && [[ "$cwd" == "$__git_cache_root"/* || "$cwd" == "$__git_cache_root" ]]; then
        [[ -n "$__git_cache_branch" ]] && \
            echo "${C_GREEN}${G_BRANCH} ${__git_cache_branch}${__git_cache_state}${C_RESET}"
        return
    fi

    # Full git check — only on directory change or cache invalidation
    local repo_root
    repo_root=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --show-toplevel 2>/dev/null) || {
        __git_cached=1
        __git_cache_root=""
        __git_cache_branch=""
        __git_cache_state=""
        return
    }

    local branch state="" status_out ahead behind

    branch=$(GIT_OPTIONAL_LOCKS=0 git branch --show-current 2>/dev/null || \
             GIT_OPTIONAL_LOCKS=0 git describe --tags --exact-match 2>/dev/null || \
             GIT_OPTIONAL_LOCKS=0 git rev-parse --short HEAD 2>/dev/null)
    [[ -z "$branch" ]] && return

    status_out=$(GIT_OPTIONAL_LOCKS=0 git status --porcelain 2>/dev/null)
    [[ -n "$status_out" ]] && state="*"

    if GIT_OPTIONAL_LOCKS=0 git rev-parse --verify --quiet '@{u}' &>/dev/null; then
        read -r ahead behind <<< "$(GIT_OPTIONAL_LOCKS=0 git rev-list --left-right --count HEAD...@{u} 2>/dev/null)"
        [[ -n "$ahead" && "$ahead" != "0" ]] && state+=" ${G_UP}${ahead}"
        [[ -n "$behind" && "$behind" != "0" ]] && state+=" ${G_DOWN}${behind}"
    fi

    GIT_OPTIONAL_LOCKS=0 git rev-parse --verify --quiet refs/stash &>/dev/null && \
        state+=" ${G_STASH}"

    # Update cache with repo ROOT — not cwd — so lateral cd reuses it
    __git_cached=1
    __git_cache_root="$repo_root"
    __git_cache_branch="$branch"
    __git_cache_state="$state"

    echo "${C_GREEN}${G_BRANCH} ${branch}${state}${C_RESET}"
}

__get_venv() {
    if [[ -n "${VIRTUAL_ENV-}" ]]; then
        local vname="${VIRTUAL_ENV##*/}"
        echo "${G_H}(${C_MAGENTA}py:${vname}${C_RESET})"
    elif [[ -n "${CONDA_DEFAULT_ENV-}" && "${CONDA_DEFAULT_ENV}" != "base" ]]; then
        echo "${G_H}(${C_MAGENTA}env:$CONDA_DEFAULT_ENV${C_RESET})"
    fi
}

__get_jobs() {
    local n=0 job
    for job in $(jobs -p); do
        (( n++ ))
    done 2>/dev/null
    (( n > 0 )) && echo "${C_MAGENTA}${G_GEAR} ${n}${C_RESET}"
}

# ── Main Prompt Builder ───────────────────────────────────────
__prompt_build() {
    local last_rc=$?
    __prompt_building=1

    local duration=""
    if (( __timer_running == 1 )); then
        local end_time=${EPOCHSECONDS:-$SECONDS}
        local d=$(( end_time - __timer_start_time ))
        __timer_running=0

        if (( d >= 1 )); then
            if (( d >= 3600 )); then
                printf -v duration "${C_YELLOW}${G_TIMER} %dh %dm %ds${C_RESET}" \
                    $((d / 3600)) $((d % 3600 / 60)) $((d % 60))
            elif (( d >= 60 )); then
                printf -v duration "${C_YELLOW}${G_TIMER} %dm %ds${C_RESET}" \
                    $((d / 60)) $((d % 60))
            else
                printf -v duration "${C_YELLOW}${G_TIMER} %ds${C_RESET}" "$d"
            fi
        fi
    fi

    local venv git jobs
    venv=$(__get_venv)
    git=$(__get_git)
    jobs=$(__get_jobs)

    local user_color=$C_CYAN
    (( EUID == 0 )) && user_color=$C_RED
    local host_color=$C_CYAN
    (( IS_SSH == 1 )) && host_color=$C_BLUE

    local title=""
    [[ "${TERM-}" == xterm* || "${TERM-}" == rxvt* || "${TERM-}" == alacritty* ]] && \
        title='\[\e]0;\u@\h:\w\a\]'

    local top_line="${title}${G_TL}${G_H}(${user_color}\u${C_RESET}@${host_color}\h${C_RESET})${G_H}[${C_YELLOW}\w${C_RESET}]${venv}"

    local mid_line=""
    local sep="  "

    [[ -n "$git" ]] && mid_line+="${git}${sep}"
    [[ -n "$jobs" ]] && mid_line+="${jobs}${sep}"
    [[ -n "$duration" ]] && mid_line+="${duration}${sep}"
    (( last_rc != 0 )) && mid_line+="${C_RED}${G_CROSS} ${last_rc}${C_RESET}"

    local pc_color=$C_GREEN
    (( last_rc != 0 || EUID == 0 )) && pc_color=$C_RED
    local bottom_line="${G_BL}${G_H}${pc_color}${G_RARROW}${C_RESET} "

    if [[ -n "$mid_line" ]]; then
        PS1="\n${top_line}\n${G_V}  ${mid_line}\n${bottom_line}"
    else
        PS1="\n${top_line}\n${bottom_line}"
    fi

    __prompt_building=0
}

# ── Safe Install ──────────────────────────────────────────────
__prompt_install() {
    if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
        local new_pc=() cmd
        for cmd in "${PROMPT_COMMAND[@]}"; do
            [[ "$cmd" != "__prompt_build" ]] && new_pc+=("$cmd")
        done
        PROMPT_COMMAND=("__prompt_build" "${new_pc[@]}")
    else
        if [[ -z "${PROMPT_COMMAND-}" ]]; then
            PROMPT_COMMAND="__prompt_build"
        else
            PROMPT_COMMAND="${PROMPT_COMMAND//__prompt_build;/}"
            PROMPT_COMMAND="${PROMPT_COMMAND//__prompt_build/}"
            PROMPT_COMMAND="__prompt_build${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
        fi
    fi
}
__prompt_install
unset -f __prompt_install
