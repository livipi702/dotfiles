#!/usr/bin/env bash
set -euo pipefail

VERSION="2.2.0"
SCRIPT_NAME="$(basename "$0")"

# === Terminal Colors ===
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' RESET=''
fi

# === Defaults ===
ROOT_DIR="."
DRY_RUN=false
VERBOSE=false
PARALLEL_JOBS=1
declare -a EXCLUDE_PATTERNS=()

# === Helpers ===
usage() {
    cat <<EOF
${BOLD}${SCRIPT_NAME}${RESET} v${VERSION} — Safely find and remove node_modules directories

${BOLD}USAGE:${RESET}
    ${SCRIPT_NAME} [OPTIONS]

${BOLD}OPTIONS:${RESET}
    -p <path>            Root directory to scan (default: current directory)
    --dry-run            Show what would be deleted without actually deleting
    -v, --verbose        Verbose output (show each directory with its size)
    -j <N>               Parallel deletion with N worker processes (default: 1)
    --exclude <pattern>  Exclude directories matching <pattern> (repeatable)
                         Matches against the full path using shell glob syntax.
                         Common examples:
                           --exclude .git
                           --exclude .cache
                           --exclude '**/fixtures/**'
    -h, --help           Show this help message
    --version            Show version

${BOLD}EXAMPLES:${RESET}
    ${SCRIPT_NAME}
    ${SCRIPT_NAME} -p ~/dev-journey
    ${SCRIPT_NAME} --dry-run -v
    ${SCRIPT_NAME} -j 4 -v -p ~/projects
    ${SCRIPT_NAME} --exclude .git --exclude '**/fixtures/**'
    ${SCRIPT_NAME} --exclude .cache --dry-run -v
EOF
}

human_size() {
    local kb="${1:-0}"
    if (( kb >= 1048576 )); then
        awk "BEGIN { printf \"%.2f GB\", ${kb} / 1048576 }"
    elif (( kb >= 1024 )); then
        awk "BEGIN { printf \"%.2f MB\", ${kb} / 1024 }"
    else
        printf "%d KB" "$kb"
    fi
}

info()    { printf "%s::%s %s\n" "$BLUE" "$RESET" "$*"; }
warn()    { printf "%s⚠%s  %s\n" "$YELLOW" "$RESET" "$*"; }
error()   { printf "%s✗%s  %s\n" "$RED" "$RESET" "$*" >&2; }
success() { printf "%s✓%s  %s\n" "$GREEN" "$RESET" "$*"; }

# === Signals ===
cleanup() {
    printf "\n"
    warn "Interrupted."
    wait 2>/dev/null || true
    exit 130
}
trap cleanup INT TERM

# === Args ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p)
            if [[ -z "${2:-}" ]]; then
                error "Option ${BOLD}-p${RESET} requires a directory path."
                exit 1
            fi
            ROOT_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -j)
            if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
                error "Option ${BOLD}-j${RESET} requires a positive integer."
                exit 1
            fi
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --exclude)
            if [[ -z "${2:-}" ]]; then
                error "Option ${BOLD}--exclude${RESET} requires a pattern."
                exit 1
            fi
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --version)
            printf "%s v%s\n" "$SCRIPT_NAME" "$VERSION"
            exit 0
            ;;
        -*)
            error "Unknown option: ${BOLD}$1${RESET}"
            printf "\nRun '${BOLD}%s --help${RESET}' for usage information.\n" "$SCRIPT_NAME" >&2
            exit 1
            ;;
        *)
            ROOT_DIR="$1"
            shift
            ;;
    esac
done

# === Validate ===
if [[ ! -d "$ROOT_DIR" ]]; then
    error "Directory does not exist: ${BOLD}${ROOT_DIR}${RESET}"
    exit 1
fi

ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"

# === Build Find ===
find_args=("$ROOT_DIR")

for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    if [[ "$pattern" == *"/"* || "$pattern" == *"*"* ]]; then
        find_args+=(-path "$pattern" -prune -o)
    else
        find_args+=(-path "*/${pattern}" -prune -o)
        find_args+=(-path "*/${pattern}/*" -prune -o)
    fi
done

find_args+=(-type d -name 'node_modules' -prune -print0)

# === Scan ===
if $DRY_RUN; then
    printf "\n"
    warn "${BOLD}DRY RUN${RESET} — no files will be deleted."
fi

printf "\n"
info "Scanning for ${BOLD}node_modules${RESET} in ${BOLD}${ROOT_DIR}${RESET} ..."

if (( ${#EXCLUDE_PATTERNS[@]} > 0 )); then
    info "Excluding patterns: ${CYAN}${EXCLUDE_PATTERNS[*]}${RESET}"
fi

declare -a dirs=()

mapfile -d '' dirs < <(
    find "${find_args[@]}" 2>/dev/null || true
)

count=${#dirs[@]}

if (( count == 1 )) && [[ -z "${dirs[0]:-}" ]]; then
    count=0
    dirs=()
fi

if (( count == 0 )); then
    printf "\n"
    success "No ${BOLD}node_modules${RESET} directories found. Already clean!"
    exit 0
fi

# === Size Calc ===
declare -a sizes=()
total_kb=0

for dir in "${dirs[@]}"; do
    kb="$(du -sk -- "$dir" 2>/dev/null | cut -f1 || true)"
    kb="${kb:-0}"
    sizes+=("$kb")
    total_kb=$((total_kb + kb))
done

# === Display ===
if (( count == 1 )); then label="directory"; else label="directories"; fi

total_human="$(human_size "$total_kb")"

printf "\n"
info "Found ${BOLD}${count}${RESET} node_modules ${label} (${BOLD}${total_human}${RESET} total)"

if $VERBOSE; then
    printf "\n"
    for i in "${!dirs[@]}"; do
        rel_path="${dirs[$i]#"$ROOT_DIR"/}"
        size_str="$(human_size "${sizes[$i]}")"
        printf "  %s%10s%s  ./%s\n" "$DIM" "$size_str" "$RESET" "$rel_path"
    done
fi

if $DRY_RUN; then
    printf "\n"
    info "Dry run complete. Re-run without ${BOLD}--dry-run${RESET} to delete."
    exit 0
fi

# === Confirm ===
printf "\n"
printf "%s⚠%s  Delete %s%d%s node_modules %s and free ~%s%s%s? [y/N] " \
    "$YELLOW" "$RESET" "$BOLD" "$count" "$RESET" "$label" "$BOLD" "$total_human" "$RESET"

read -r confirm < /dev/tty 2>/dev/null || confirm="n"

if [[ ! "$confirm" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    printf "\n"
    info "Aborted. No files were deleted."
    exit 0
fi

# === Delete ===
printf "\n"

start_time=$SECONDS

if (( PARALLEL_JOBS > 1 )); then
    info "Deleting ${BOLD}${count}${RESET} node_modules ${label} (${BOLD}${PARALLEL_JOBS}${RESET} parallel workers) ..."

    printf '%s\0' "${dirs[@]}" \
        | xargs -0 -P "$PARALLEL_JOBS" -I{} bash -c '
            dir="{}"
            if [[ "$(basename "$dir")" != "node_modules" ]]; then
                exit 1
            fi
            rm -rf -- "$dir"
        ' || true

    deleted=0
    failed=0
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            failed=$((failed + 1))
        else
            deleted=$((deleted + 1))
        fi
    done

    if $VERBOSE; then
        for i in "${!dirs[@]}"; do
            rel_path="${dirs[$i]#"$ROOT_DIR"/}"
            if [[ ! -d "${dirs[$i]}" ]]; then
                printf "  %s✓%s  Deleted ./%s\n" "$GREEN" "$RESET" "$rel_path"
            else
                printf "  %s✗%s  Failed  ./%s\n" "$RED" "$RESET" "$rel_path"
            fi
        done
    fi

else
    info "Deleting ${BOLD}${count}${RESET} node_modules ${label} ..."

    deleted=0
    failed=0

    for i in "${!dirs[@]}"; do
        dir="${dirs[$i]}"

        if [[ "$(basename "$dir")" != "node_modules" ]]; then
            error "Refusing to delete unexpected path: ${dir}"
            failed=$((failed + 1))
            continue
        fi

        if rm -rf -- "$dir" 2>/dev/null; then
            deleted=$((deleted + 1))
            if $VERBOSE; then
                rel_path="${dir#"$ROOT_DIR"/}"
                printf "  %s✓%s  Deleted ./%s\n" "$GREEN" "$RESET" "$rel_path"
            fi
        else
            failed=$((failed + 1))
            error "Failed to delete: ${dir}"
        fi
    done
fi

# === Summary ===
elapsed=$(( SECONDS - start_time ))

printf "\n"

if (( failed == 0 )); then
    success "Done! Removed ${BOLD}${deleted}${RESET} node_modules ${label}, freed ~${BOLD}${total_human}${RESET} in ${BOLD}${elapsed}s${RESET}."
else
    warn "Completed with issues: ${BOLD}${deleted}${RESET} deleted, ${BOLD}${failed}${RESET} failed (${elapsed}s)."
    exit 1
fi
