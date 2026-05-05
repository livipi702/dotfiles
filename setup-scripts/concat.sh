#!/usr/bin/env bash
#
# concat.sh — Recursively concatenates all files in a directory
#             into a single reviewable text file with clear headers.
#
# Usage:
#   ./concat.sh                          # interactive TUI mode
#   ./concat.sh /path/to/dir             # concat entire directory
#   ./concat.sh /path/to/dir -o out.txt  # custom output file
#   ./concat.sh -h|--help                # show help
#

set -euo pipefail

VERSION="1.0.0"

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'
NC='\033[0m'

# ── Defaults ────────────────────────────────────────────
OUTPUT_FILE=""
TARGET_DIR=""
INCLUDE_EXTENSIONS=()
EXPLICIT_FILES=()

# ── Smart Exclusions ───────────────────────────────────
# Directories that are almost never useful to concat
DEFAULT_EXCLUDE_DIRS=(
  # Version control
  .git
  .svn
  .hg
  .bzr
  .cvsignore

  # Node / JS ecosystem
  node_modules
  .npm
  .yarn
  .pnpm-store
  .pnp
  bower_components
  .cache
  .parcel-cache
  .turbo
  .vercel
  .netlify

  # Build output
  dist
  build
  out
  .next
  .nuxt
  .output
  .svelte-kit
  .astro
  .docusaurus
  .vuepress
  coverage
  .nyc_output

  # Python
  __pycache__
  .mypy_cache
  .pytest_cache
  .ruff_cache
  .venv
  venv
  env
  .env
  .tox
  .nox
  .eggs
  *.egg-info
  site-packages
  .ipynb_checkpoints

  # Go
  vendor

  # Rust
  target

  # Java / JVM
  .gradle
  .mvn
  .classpath
  .settings
  target

  # Ruby
  .bundle
  vendor

  # PHP
  vendor

  # IDE / Editor
  .idea
  .vscode
  .vs
  .eclipse
  .settings

  # OS metadata
  .DS_Store
  .Trash
  .Spotlight-V100
  .fseventsd
  Thumbs.db
  Desktop.ini

  # Docker
  .docker

  # Terraform
  .terraform
  .terraform.d

  # Other
  .direnv
  .envrc
  .local
  .config
  .nuget
  .cargo
  .rustup
)

# File patterns that are almost never useful to concat
DEFAULT_EXCLUDE_PATTERNS=(
  "*.min.js"
  "*.min.css"
  "*.min.mjs"
  "*.map"
  "*.lock"
  "package-lock.json"
  "yarn.lock"
  "pnpm-lock.yaml"
  "bun.lockb"
  "Gemfile.lock"
  "Cargo.lock"
  "poetry.lock"
  "pdm.lock"
  "uv.lock"
  "*.pyc"
  "*.pyo"
  "*.class"
  "*.o"
  "*.so"
  "*.dylib"
  "*.dll"
  "*.exe"
  "*.bin"
  "*.wasm"
  "*.ico"
  "*.png"
  "*.jpg"
  "*.jpeg"
  "*.gif"
  "*.svg"
  "*.webp"
  "*.avif"
  "*.mp3"
  "*.mp4"
  "*.wav"
  "*.flac"
  "*.zip"
  "*.tar"
  "*.gz"
  "*.bz2"
  "*.xz"
  "*.7z"
  "*.rar"
  "*.woff"
  "*.woff2"
  "*.ttf"
  "*.eot"
  "*.otf"
  ".gitignore"
  ".gitattributes"
  ".editorconfig"
  ".prettierrc*"
  ".eslintrc*"
  ".babelrc"
  ".npmrc"
  ".npmignore"
  ".dockerignore"
  ".env*"
)

# Active exclusion lists (user can modify these)
EXCLUDE_DIRS=()
EXCLUDE_PATTERNS=()
SKIP_SMART_DEFAULTS=false

# ── Helpers ─────────────────────────────────────────────
die() {
  echo -e "\n${RED}  ✖ Error:${NC} $*\n" >&2
  exit 1
}
info() { echo -e "  ${CYAN}▸${NC} $*"; }
ok() { echo -e "  ${GREEN}✔${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }

# ── UI Drawing Helpers ─────────────────────────────────
draw_line() {
  local char="${1:-─}"
  local width="${2:-$(tput cols 2>/dev/null || echo 60)}"
  local color="${3:-$DIM}"
  echo -e "${color}$(printf '%*s' "$width" '' | tr ' ' "$char")${NC}"
}

draw_box_top() {
  local width="${1:-60}"
  echo -e "${CYAN}╭$(printf '─%.0s' $(seq 1 $((width - 2))))╮${NC}"
}

draw_box_bottom() {
  local width="${1:-60}"
  echo -e "${CYAN}╰$(printf '─%.0s' $(seq 1 $((width - 2))))╯${NC}"
}

draw_box_line() {
  local text="$1"
  local width="${2:-60}"
  local inner=$((width - 4))
  local color="${3:-$CYAN}"
  echo -e "${color}│${NC} $(printf "%-${inner}s" "$text") ${color}│${NC}"
}

print_banner() {
  local width=54
  echo ""
  echo -e "${BOLD}${CYAN}╭$(printf '─%.0s' $(seq 1 $width))╮${NC}"
  echo -e "${BOLD}${CYAN}│${NC}                                                      ${BOLD}${CYAN}│${NC}"
  echo -e "${BOLD}${CYAN}│${NC}   ${WHITE}concat.sh${NC} ${DIM}v${VERSION}${NC}  —  ${ITALIC}Directory Merger${NC}          ${BOLD}${CYAN}│${NC}"
  echo -e "${BOLD}${CYAN}│${NC}   ${DIM}Flatten any directory into a single file${NC}            ${BOLD}${CYAN}│${NC}"
  echo -e "${BOLD}${CYAN}│${NC}                                                      ${BOLD}${CYAN}│${NC}"
  echo -e "${BOLD}${CYAN}╰$(printf '─%.0s' $(seq 1 $width))╯${NC}"
  echo ""
}

print_section() {
  local title="$1"
  echo ""
  echo -e "  ${BOLD}${WHITE}▸ ${title}${NC}"
  echo -e "  ${DIM}$(printf '─%.0s' $(seq 1 40))${NC}"
}

# ── Prompt helpers ──────────────────────────────────────
ask() {
  local prompt="$1"
  local default="${2:-}"
  local response
  if [[ -n "$default" ]]; then
    echo -ne "  ${CYAN}${prompt}${NC} ${DIM}[${default}]${NC}: " >&2
  else
    echo -ne "  ${CYAN}${prompt}${NC}: " >&2
  fi
  read -r response
  echo "${response:-$default}"
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  while true; do
    local yn
    if [[ "$default" == "y" ]]; then
      echo -ne "  ${CYAN}${prompt}${NC} ${DIM}[Y/n]${NC}: " >&2
    else
      echo -ne "  ${CYAN}${prompt}${NC} ${DIM}[y/N]${NC}: " >&2
    fi
    read -r yn
    yn="${yn:-$default}"
    case "$yn" in
    [Yy]* | "") return 0 ;;
    [Nn]*) return 1 ;;
    *) echo -e "  ${RED}Please answer y or n.${NC}" >&2 ;;
    esac
  done
}

# ── Spinner ─────────────────────────────────────────────
_spinner_pid=""

start_spinner() {
  local msg="${1:-Working...}"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while true; do
    echo -ne "\r  ${CYAN}${frames[$((i % ${#frames[@]}))]}${NC} ${msg}   " >&2
    i=$((i + 1))
    sleep 0.08
  done &
  _spinner_pid=$!
}

stop_spinner() {
  if [[ -n "$_spinner_pid" ]]; then
    kill "$_spinner_pid" 2>/dev/null || true
    wait "$_spinner_pid" 2>/dev/null || true
    _spinner_pid=""
    echo -ne "\r$(printf ' %.0s' $(seq 1 50))\r" >&2
  fi
}

# ── Progress bar ────────────────────────────────────────
show_progress() {
  local current="$1"
  local total="$2"
  local label="${3:-}"
  local width=30
  local pct=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))

  local bar=""
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done

  echo -ne "\r  ${DIM}[${NC}${GREEN}${bar}${DIM}]${NC} ${BOLD}${pct}%${NC} ${DIM}(${current}/${total})${NC} ${DIM}${label}${NC}   "
}

# ── File type icons ────────────────────────────────────
get_file_icon() {
  local ext="${1##*.}"
  local name="$(basename "$1")"
  case "${ext,,}" in
  sh | bash | zsh | fish) echo "🐚" ;;
  py) echo "🐍" ;;
  js | mjs | cjs) echo "📜" ;;
  ts | tsx | mts | cts) echo "🔷" ;;
  jsx) echo "⚛" ;;
  rs) echo "🦀" ;;
  go) echo "🐹" ;;
  java | jar) echo "☕" ;;
  rb) echo "💎" ;;
  php) echo "🐘" ;;
  lua) echo "🌙" ;;
  vim | vimrc) echo "✏" ;;
  md | mdx | rst | txt) echo "📝" ;;
  json | yaml | yml | toml | ini) echo "⚙" ;;
  html | htm) echo "🌐" ;;
  css | scss | sass | less) echo "🎨" ;;
  sql) echo "🗃" ;;
  dockerfile | dockerignore) echo "🐳" ;;
  gitignore | gitattributes) echo "📋" ;;
  conf | cfg | config) echo "🔧" ;;
  *)
    case "$name" in
    Makefile | Dockerfile | Vagrantfile | Gemfile | Rakefile | Cargo.toml | go.mod) echo "📋" ;;
    .env*) echo "🔒" ;;
    *) echo "📄" ;;
    esac
    ;;
  esac
}

# ── Human-readable sizes ───────────────────────────────
human_size() {
  local bytes="$1"
  if ((bytes >= 1073741824)); then
    echo "$(echo "scale=1; $bytes/1073741824" | bc)G"
  elif ((bytes >= 1048576)); then
    echo "$(echo "scale=1; $bytes/1048576" | bc)M"
  elif ((bytes >= 1024)); then
    echo "$(echo "scale=1; $bytes/1024" | bc)K"
  else
    echo "${bytes}B"
  fi
}

# ── Build exclusion lists ──────────────────────────────
build_exclusions() {
  if [[ "$SKIP_SMART_DEFAULTS" == true ]]; then
    return
  fi
  EXCLUDE_DIRS=("${DEFAULT_EXCLUDE_DIRS[@]}")
  EXCLUDE_PATTERNS=("${DEFAULT_EXCLUDE_PATTERNS[@]}")
}

# ── File listing ────────────────────────────────────────
list_files() {
  local dir="$1"
  local depth="${2:-999}"

  local -a find_args=()
  find_args+=(-type f)

  if [[ "$depth" -lt 999 ]]; then
    find_args+=(-maxdepth "$depth")
  fi

  # Include extensions filter
  if [[ ${#INCLUDE_EXTENSIONS[@]} -gt 0 ]]; then
    local -a ext_args=()
    local first=true
    for ext in "${INCLUDE_EXTENSIONS[@]}"; do
      if $first; then
        ext_args+=(-name "*.$ext")
        first=false
      else
        ext_args+=(-o -name "*.$ext")
      fi
    done
    find_args+=\( "${ext_args[@]}" \)
  fi

  # Exclude directories
  for exdir in "${EXCLUDE_DIRS[@]}"; do
    find_args+=(-not -path "*/$exdir/*")
  done

  # Exclude dot directories (anything starting with .)
  if [[ "$SKIP_SMART_DEFAULTS" != true ]]; then
    find_args+=(-not -path "*/.*/*")
  fi

  # Exclude file patterns
  for pat in "${EXCLUDE_PATTERNS[@]}"; do
    find_args+=(! -name "$pat")
  done

  find "$dir" "${find_args[@]}" 2>/dev/null | sort
}

# Check if file is human-readable (not binary)
is_text() {
  local f="$1"
  # Quick check: file command
  if file "$f" 2>/dev/null | grep -qE "text|empty|ASCII|UTF-8|XML|JSON|shell|script|source"; then
    return 0
  fi
  # Fallback: check if first 4KB contains null bytes
  if [[ "$(head -c 4096 "$f" 2>/dev/null | tr -d '\0' | wc -c)" == "$(head -c 4096 "$f" 2>/dev/null | wc -c)" ]]; then
    return 0
  fi
  return 1
}

# ── Count files (for progress) ─────────────────────────
count_files() {
  local dir="$1"
  local count=0
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if is_text "$f"; then
      count=$((count + 1))
    fi
  done < <(list_files "$dir" 999)
  echo "$count"
}

# ── Core concat logic (all files) ──────────────────────
do_concat() {
  local source_dir="$1"
  local out_file="$2"

  info "Scanning ${BOLD}$source_dir${NC}..."
  echo ""

  >"$out_file"

  local total_files=0
  local total_lines=0
  local skipped=0
  local total_bytes=0

  # Write header
  {
    echo "================================================================================"
    echo "  CONCATENATED DIRECTORY OUTPUT"
    echo "  Source  : $source_dir"
    echo "  Date    : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  Excluded: ${#EXCLUDE_DIRS[@]} dir patterns, ${#EXCLUDE_PATTERNS[@]} file patterns"
    echo "================================================================================"
    echo ""
  } >>"$out_file"

  local all_files
  all_files=$(list_files "$source_dir" 999)

  if [[ -z "$all_files" ]]; then
    warn "No files found matching your criteria!"
    rm -f "$out_file"
    return 1
  fi

  # Count total for progress
  local file_list=()
  while IFS= read -r filepath; do
    file_list+=("$filepath")
  done <<<"$all_files"

  local total_count=${#file_list[@]}
  local processed=0

  for filepath in "${file_list[@]}"; do
    if ! is_text "$filepath"; then
      skipped=$((skipped + 1))
      processed=$((processed + 1))
      show_progress "$processed" "$total_count" "scanning..."
      continue
    fi

    local rel_path="${filepath#$source_dir/}"
    local lines
    lines=$(wc -l <"$filepath" 2>/dev/null || echo "0")
    local fsize
    fsize=$(wc -c <"$filepath" 2>/dev/null || echo "0")
    total_lines=$((total_lines + lines))
    total_bytes=$((total_bytes + fsize))
    total_files=$((total_files + 1))

    {
      echo "══════════════════════════════════════════════════════════════════════════════"
      echo "  FILE: $rel_path"
      echo "  LINES: $lines  |  SIZE: $(human_size "$fsize")"
      echo "══════════════════════════════════════════════════════════════════════════════"
      echo ""
    } >>"$out_file"

    cat "$filepath" >>"$out_file"
    # Ensure file ends with newline
    [[ $(tail -c1 "$out_file" | wc -l) -eq 0 ]] && echo "" >>"$out_file"
    echo "" >>"$out_file"

    processed=$((processed + 1))
    show_progress "$processed" "$total_count" "$rel_path"
  done

  echo ""

  # Write footer
  {
    echo "══════════════════════════════════════════════════════════════════════════════"
    echo "  SUMMARY"
    echo "  Source directory : $source_dir"
    echo "  Total files      : $total_files"
    echo "  Total lines      : $total_lines"
    echo "  Total size       : $(human_size "$total_bytes")"
    echo "  Skipped (binary) : $skipped"
    echo "  Output file      : $out_file"
    echo "  Generated at     : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "══════════════════════════════════════════════════════════════════════════════"
  } >>"$out_file"

  echo ""
  ok "Done!"
  echo ""
  echo -e "  ${BOLD}Files:${NC}      $total_files"
  echo -e "  ${BOLD}Lines:${NC}      $total_lines"
  echo -e "  ${BOLD}Size:${NC}       $(human_size "$total_bytes")"
  echo -e "  ${BOLD}Skipped:${NC}    $skipped (binary)"
  echo -e "  ${BOLD}Output:${NC}     $out_file"
  local out_size
  out_size=$(wc -c <"$out_file" 2>/dev/null || echo "0")
  echo -e "  ${BOLD}File size:${NC}  $(human_size "$out_size")"
  echo ""
}

# ── Core concat logic (specific files only) ────────────
do_concat_specific() {
  local source_dir="$1"
  local out_file="$2"
  shift 2
  local -a target_files=("$@")

  info "Concatenating ${BOLD}${#target_files[@]} file(s)${NC}..."
  echo ""

  >"$out_file"

  local total_files=0
  local total_lines=0
  local total_bytes=0

  {
    echo "================================================================================"
    echo "  CONCATENATED DIRECTORY OUTPUT (SELECTED FILES)"
    echo "  Source : $source_dir"
    echo "  Date   : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================================================================"
    echo ""
  } >>"$out_file"

  local processed=0
  local total_count=${#target_files[@]}

  for filepath in "${target_files[@]}"; do
    local rel_path="${filepath#$source_dir/}"
    local lines
    lines=$(wc -l <"$filepath" 2>/dev/null || echo "0")
    local fsize
    fsize=$(wc -c <"$filepath" 2>/dev/null || echo "0")
    total_lines=$((total_lines + lines))
    total_bytes=$((total_bytes + fsize))
    total_files=$((total_files + 1))

    {
      echo "══════════════════════════════════════════════════════════════════════════════"
      echo "  FILE: $rel_path"
      echo "  LINES: $lines  |  SIZE: $(human_size "$fsize")"
      echo "══════════════════════════════════════════════════════════════════════════════"
      echo ""
    } >>"$out_file"

    cat "$filepath" >>"$out_file"
    [[ $(tail -c1 "$out_file" | wc -l) -eq 0 ]] && echo "" >>"$out_file"
    echo "" >>"$out_file"

    processed=$((processed + 1))
    show_progress "$processed" "$total_count" "$rel_path"
  done

  echo ""

  {
    echo "══════════════════════════════════════════════════════════════════════════════"
    echo "  SUMMARY"
    echo "  Source directory : $source_dir"
    echo "  Total files      : $total_files"
    echo "  Total lines      : $total_lines"
    echo "  Total size       : $(human_size "$total_bytes")"
    echo "  Output file      : $out_file"
    echo "  Generated at     : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "══════════════════════════════════════════════════════════════════════════════"
  } >>"$out_file"

  echo ""
  ok "Done!"
  echo ""
  echo -e "  ${BOLD}Files:${NC}      $total_files"
  echo -e "  ${BOLD}Lines:${NC}      $total_lines"
  echo -e "  ${BOLD}Size:${NC}       $(human_size "$total_bytes")"
  echo -e "  ${BOLD}Output:${NC}     $out_file"
  local out_size
  out_size=$(wc -c <"$out_file" 2>/dev/null || echo "0")
  echo -e "  ${BOLD}File size:${NC}  $(human_size "$out_size")"
  echo ""
}

# ── Show exclusion summary ─────────────────────────────
show_exclusions_summary() {
  if [[ "$SKIP_SMART_DEFAULTS" != true ]]; then
    echo -e "  ${DIM}Smart exclusions active: ${#EXCLUDE_DIRS[@]} dirs, ${#EXCLUDE_PATTERNS[@]} patterns${NC}"
    echo -e "  ${DIM}(dotfiles, .git, node_modules, build artifacts, binaries, etc.)${NC}"
  else
    echo -e "  ${YELLOW}Smart exclusions disabled — all files included${NC}"
  fi
}

# ── Interactive mode ────────────────────────────────────
interactive_mode() {
  print_banner

  # Build default exclusions
  build_exclusions

  # ── Step 1: Pick a directory ──
  print_section "Select a directory"
  echo ""

  local -a available_dirs=()
  local -a dir_labels=()

  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    # Skip dot directories in listing
    local bn
    bn=$(basename "$d")
    [[ "$bn" == .* ]] && continue

    local item_count
    item_count=$(find "$d" -maxdepth 1 -type f 2>/dev/null | wc -l)
    local sub_count
    sub_count=$(find "$d" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
    local hint=""
    if ((item_count > 0)); then
      hint="${item_count}f"
      ((sub_count > 0)) && hint="${hint} ${sub_count}d"
    elif ((sub_count > 0)); then
      hint="${sub_count}d"
    else
      hint="empty"
    fi
    dir_labels+=("${bn}  ${DIM}(${hint})${NC}")
    available_dirs+=("$d")
  done < <(find "$PWD" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)

  if [[ ${#available_dirs[@]} -eq 0 ]]; then
    local dir_input
    dir_input=$(ask "No subdirs found. Enter a path" "$PWD")
    dir_input="${dir_input/#\~/$HOME}"
    if [[ ! -d "$dir_input" ]]; then
      die "Directory not found: $dir_input"
    fi
    TARGET_DIR=$(realpath "$dir_input")
  else
    for i in "${!dir_labels[@]}"; do
      echo -e "    ${GREEN}[$((i + 1))]${NC}  ${dir_labels[$i]}"
    done
    echo -e "    ${DIM}[0]  Enter a custom path${NC}"
    echo ""

    local dir_choice
    dir_choice=$(ask "Pick a number" "1")

    if [[ "$dir_choice" == "0" ]]; then
      local custom_path
      custom_path=$(ask "Enter directory path")
      custom_path="${custom_path/#\~/$HOME}"
      if [[ ! -d "$custom_path" ]]; then
        die "Directory not found: $custom_path"
      fi
      TARGET_DIR=$(realpath "$custom_path")
    elif [[ "$dir_choice" =~ ^[0-9]+$ ]] && ((dir_choice >= 1 && dir_choice <= ${#available_dirs[@]})); then
      TARGET_DIR=$(realpath "${available_dirs[$((dir_choice - 1))]}")
    else
      # Maybe it's a path
      dir_choice="${dir_choice/#\~/$HOME}"
      if [[ -d "$dir_choice" ]]; then
        TARGET_DIR=$(realpath "$dir_choice")
      else
        die "Invalid selection: $dir_choice"
      fi
    fi
  fi

  ok "Selected ${BOLD}$TARGET_DIR${NC}"
  echo ""

  # ── Step 2: Exclusion preferences ──
  print_section "Exclusion settings"
  echo ""
  show_exclusions_summary
  echo ""

  if ask_yes_no "Keep smart defaults? (recommended)" "y"; then
    ok "Using smart exclusions"
  else
    if ask_yes_no "Disable ALL exclusions? (includes .git, node_modules, binaries, etc.)" "n"; then
      SKIP_SMART_DEFAULTS=true
      EXCLUDE_DIRS=()
      EXCLUDE_PATTERNS=()
      warn "All exclusions disabled — everything will be included"
    else
      # Let user toggle categories
      echo ""
      echo -e "  ${BOLD}Toggle exclusion categories:${NC}"
      echo ""

      local -a categories=(
        "VCS:Version control (.git, .svn, .hg)"
        "NODE:Node.js (node_modules, .npm, .yarn, .pnpm)"
        "BUILD:Build output (dist, build, .next, coverage)"
        "PYTHON:Python (__pycache__, .venv, .mypy_cache)"
        "RUST:Rust (target/)"
        "IDE:IDE/Editor (.idea, .vscode)"
        "BINARY:Binary files (*.min.js, images, fonts, lockfiles)"
        "OS:OS metadata (.DS_Store, Thumbs.db)"
      )

      local -a cat_choices=()
      for cat_desc in "${categories[@]}"; do
        local cat_name="${cat_desc%%:*}"
        local cat_label="${cat_desc#*:}"
        if ask_yes_no "  Include ${cat_label}?" "n"; then
          cat_choices+=("$cat_name")
        fi
      done

      # Rebuild exclusions excluding chosen categories
      EXCLUDE_DIRS=()
      EXCLUDE_PATTERNS=()

      # Always exclude VCS unless user wants it
      if ! printf '%s\n' "${cat_choices[@]}" | grep -qx "VCS"; then
        EXCLUDE_DIRS+=(.git .svn .hg .bzr)
      fi
      if ! printf '%s\n' "${cat_choices[@]}" | grep -qx "NODE"; then
        EXCLUDE_DIRS+=(node_modules .npm .yarn .pnpm-store .pnp bower_components .cache .parcel-cache .turbo .vercel .netlify)
      fi
      if ! printf '%s\n' "${cat_choices[@]}" | grep -qx "BUILD"; then
        EXCLUDE_DIRS+=(dist build out .next .nuxt .output .svelte-kit .astro coverage .nyc_output)
      fi
      if ! printf '%s\n' "${cat_choices[@]}" | grep -qx "PYTHON"; then
        EXCLUDE_DIRS+=(__pycache__ .mypy_cache .pytest_cache .ruff_cache .venv venv env .tox .nox .eggs .ipynb_checkpoints)
      fi
      if ! printf '%s\n' "${cat_choices[@]}" | grep -qx "RUST"; then
        EXCLUDE_DIRS+=(target)
      fi
      if ! printf '%s\n' "${cat_choices[@]}" | grep -qx "IDE"; then
        EXCLUDE_DIRS+=(.idea .vscode .vs)
      fi
      if ! printf '%s\n' "${cat_choices[@]}" | grep -qx "OS"; then
        EXCLUDE_DIRS+=(.DS_Store .Trash)
      fi
      if ! printf '%s\n' "${cat_choices[@]}" | grep -qx "BINARY"; then
        EXCLUDE_PATTERNS+=("${DEFAULT_EXCLUDE_PATTERNS[@]}")
      fi

      # Still exclude dot dirs if VCS not explicitly included
      if ! printf '%s\n' "${cat_choices[@]}" | grep -qx "VCS"; then
        SKIP_SMART_DEFAULTS=false # keep dot exclusion
      else
        SKIP_SMART_DEFAULTS=true # user wanted VCS/dotfiles, remove dot exclusion
      fi
    fi
  fi
  echo ""

  # ── Step 3: Scan and show files ──
  print_section "Scanning files"
  echo ""

  start_spinner "Scanning directory..."

  local -a all_file_paths=()
  local -a all_file_labels=()
  local -a all_file_sizes=()
  local total_scan_bytes=0

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if is_text "$f"; then
      local rel="${f#$TARGET_DIR/}"
      local lc
      lc=$(wc -l <"$f" 2>/dev/null || echo "0")
      local fsize
      fsize=$(wc -c <"$f" 2>/dev/null || echo "0")
      total_scan_bytes=$((total_scan_bytes + fsize))
      local icon
      icon=$(get_file_icon "$f")
      all_file_labels+=("${icon} ${rel}  ${DIM}(${lc} lines, $(human_size "$fsize"))${NC}")
      all_file_paths+=("$f")
      all_file_sizes+=("$fsize")
    fi
  done < <(list_files "$TARGET_DIR" 999)

  stop_spinner

  local text_count=${#all_file_paths[@]}

  if [[ $text_count -eq 0 ]]; then
    die "No text files found in $TARGET_DIR"
  fi

  # Sort by extension for nicer display
  echo -e "  Found ${BOLD}${text_count}${NC} text file(s) (${DIM}$(human_size "$total_scan_bytes")${NC}):"
  echo ""

  # Show files in columns if many
  if ((text_count <= 30)); then
    for i in "${!all_file_labels[@]}"; do
      local num_color="$DIM"
      printf "    ${num_color}[%3d]${NC} %s\n" "$((i + 1))" "${all_file_labels[$i]}"
    done
  else
    # Show first 15 and last 5 with ellipsis
    for i in $(seq 0 14); do
      printf "    ${DIM}[%3d]${NC} %s\n" "$((i + 1))" "${all_file_labels[$i]}"
    done
    echo -e "    ${DIM}     ... ($((text_count - 20)) more files) ...${NC}"
    for i in $(seq $((text_count - 5)) $((text_count - 1))); do
      printf "    ${DIM}[%3d]${NC} %s\n" "$((i + 1))" "${all_file_labels[$i]}"
    done
  fi
  echo ""

  # ── Step 4: Choose output ──
  local dir_name
  dir_name=$(basename "$TARGET_DIR")
  local default_out="$HOME/${dir_name}-concatenated.txt"
  OUTPUT_FILE="$default_out"

  # ── Step 5: All or select? ──
  print_section "Choose files"
  echo ""

  local choice
  echo -e "  ${BOLD}[1]${NC}  Concat all ${text_count} files"
  echo -e "  ${BOLD}[2]${NC}  Pick specific files"
  echo -e "  ${BOLD}[3]${NC}  Filter by extension"
  echo ""
  choice=$(ask "Your choice" "1")

  case "$choice" in
  1)
    echo ""
    local custom_out
    custom_out=$(ask "Output file" "$OUTPUT_FILE")
    OUTPUT_FILE="${custom_out:-$OUTPUT_FILE}"
    OUTPUT_FILE="${OUTPUT_FILE/#\~/$HOME}"

    echo ""
    do_concat "$TARGET_DIR" "$OUTPUT_FILE" || exit 1
    ;;
  2)
    echo ""
    echo -e "  ${DIM}Enter numbers: 1,3,5-8,12  or  'all'${NC}"
    echo ""
    local file_input
    file_input=$(ask "Files to include")

    if [[ "$file_input" == "all" || "$file_input" == "a" ]]; then
      echo ""
      do_concat "$TARGET_DIR" "$OUTPUT_FILE" || exit 1
    else
      local -a picked_indices=()
      IFS=', ' read -ra parts <<<"$file_input"
      for part in "${parts[@]}"; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
          local start="${BASH_REMATCH[1]}"
          local end="${BASH_REMATCH[2]}"
          for ((j = start; j <= end && j <= text_count; j++)); do
            picked_indices+=($j)
          done
        elif [[ "$part" =~ ^[0-9]+$ ]] && ((part >= 1 && part <= text_count)); then
          picked_indices+=("$part")
        else
          warn "Ignoring invalid: $part"
        fi
      done

      if [[ ${#picked_indices[@]} -eq 0 ]]; then
        die "No valid files selected."
      fi

      # Deduplicate and sort
      local -a sorted_indices
      mapfile -t sorted_indices < <(printf '%s\n' "${picked_indices[@]}" | sort -nu)

      # Build file list
      local -a picked_files=()
      local pick_lines=0
      local pick_bytes=0
      for idx in "${sorted_indices[@]}"; do
        picked_files+=("${all_file_paths[$((idx - 1))]}")
        local lc
        lc=$(wc -l <"${all_file_paths[$((idx - 1))]}" 2>/dev/null || echo "0")
        pick_lines=$((pick_lines + lc))
        pick_bytes=$((pick_bytes + all_file_sizes[$((idx - 1))]))
      done

      echo ""
      info "Selected ${BOLD}${#picked_files[@]}${NC} file(s)  ${DIM}~${pick_lines} lines, $(human_size "$pick_bytes")${NC}"
      echo ""

      do_concat_specific "$TARGET_DIR" "$OUTPUT_FILE" "${picked_files[@]}"
    fi
    ;;
  3)
    echo ""
    # Find unique extensions
    local -a exts=()
    local -A ext_seen=()
    for f in "${all_file_paths[@]}"; do
      local ext="${f##*.}"
      if [[ "$ext" != "$f" && -z "${ext_seen[$ext]:-}" ]]; then
        ext_seen[$ext]=1
        # Count files with this extension
        local count=0
        for f2 in "${all_file_paths[@]}"; do
          [[ "${f2##*.}" == "$ext" ]] && count=$((count + 1))
        done
        exts+=("$ext ($count files)")
      fi
    done

    echo -e "  ${BOLD}Available extensions:${NC}"
    echo ""
    for i in "${!exts[@]}"; do
      printf "    ${DIM}[%2d]${NC} %s\n" "$((i + 1))" "${exts[$i]}"
    done
    echo ""

    local ext_input
    ext_input=$(ask "Pick extensions (comma-separated numbers or names)")
    IFS=', ' read -ra ext_parts <<<"$ext_input"

    local -a chosen_exts=()
    for part in "${ext_parts[@]}"; do
      if [[ "$part" =~ ^[0-9]+$ ]] && ((part >= 1 && part <= ${#exts[@]})); then
        local ext_name="${exts[$((part - 1))]}"
        ext_name="${ext_name%% *}"
        chosen_exts+=("$ext_name")
      else
        chosen_exts+=("$part")
      fi
    done

    if [[ ${#chosen_exts[@]} -eq 0 ]]; then
      die "No extensions selected."
    fi

    # Filter files
    local -a picked_files=()
    for f in "${all_file_paths[@]}"; do
      local ext="${f##*.}"
      for chosen in "${chosen_exts[@]}"; do
        if [[ "${ext,,}" == "${chosen,,}" ]]; then
          picked_files+=("$f")
          break
        fi
      done
    done

    if [[ ${#picked_files[@]} -eq 0 ]]; then
      die "No files matched the selected extensions."
    fi

    echo ""
    info "Found ${BOLD}${#picked_files[@]}${NC} file(s) with extensions: ${chosen_exts[*]}"
    echo ""

    do_concat_specific "$TARGET_DIR" "$OUTPUT_FILE" "${picked_files[@]}"
    ;;
  *)
    die "Invalid choice: $choice"
    ;;
  esac
}

# ── CLI mode (power users) ──────────────────────────────
cli_mode() {
  TARGET_DIR="${1:-.}"
  TARGET_DIR="${TARGET_DIR/#\~/$HOME}"

  if [[ ! -d "$TARGET_DIR" ]]; then
    die "Directory not found: $TARGET_DIR"
  fi
  TARGET_DIR=$(realpath "$TARGET_DIR")

  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -o | --output)
      OUTPUT_FILE="$2"
      OUTPUT_FILE="${OUTPUT_FILE/#\~/$HOME}"
      shift 2
      ;;
    -e | --ext)
      IFS=', ' read -ra exts <<<"$2"
      for ext in "${exts[@]}"; do
        ext=$(printf '%s' "$ext" | sed 's/^\.//')
        INCLUDE_EXTENSIONS+=("$ext")
      done
      shift 2
      ;;
    -x | --exclude-dir)
      IFS=', ' read -ra dirs <<<"$2"
      for d in "${dirs[@]}"; do
        EXCLUDE_DIRS+=("$d")
      done
      shift 2
      ;;
    -p | --exclude-pattern)
      IFS=', ' read -ra pats <<<"$2"
      for p in "${pats[@]}"; do
        EXCLUDE_PATTERNS+=("$p")
      done
      shift 2
      ;;
    --no-smart-defaults)
      SKIP_SMART_DEFAULTS=true
      shift
      ;;
    --include-dotfiles)
      SKIP_SMART_DEFAULTS=true
      shift
      ;;
    -h | --help)
      show_help
      ;;
    *)
      die "Unknown option: $1 (use -h for help)"
      ;;
    esac
  done

  # Build smart defaults unless disabled
  build_exclusions

  if [[ -z "$OUTPUT_FILE" ]]; then
    local dir_name
    dir_name=$(basename "$TARGET_DIR")
    OUTPUT_FILE="$HOME/${dir_name}-concatenated.txt"
  fi

  local out_dir
  out_dir=$(dirname "$OUTPUT_FILE")
  mkdir -p "$out_dir"

  echo ""
  show_exclusions_summary
  echo ""

  do_concat "$TARGET_DIR" "$OUTPUT_FILE" || exit 1
}

# ── Help ──────────────────────────────────────────────
show_help() {
  cat <<EOF

$(print_banner)

${BOLD}Usage:${NC}
  ./concat.sh                            Interactive TUI mode
  ./concat.sh <dir>                      Concatenate entire directory
  ./concat.sh <dir> -o <file>            Custom output file
  ./concat.sh <dir> -e py,ts,sh          Only specific extensions
  ./concat.sh <dir> --no-smart-defaults  Include everything
  ./concat.sh -h|--help                  Show this help

${BOLD}Options:${NC}
  -o, --output <file>          Output file path
                               (default: ~/dirname-concatenated.txt)
  -e, --ext <exts>             Only include these extensions
                               (comma-separated, e.g. -e lua,py,ts)
  -x, --exclude-dir <dirs>     Additional dirs to exclude
                               (comma-separated)
  -p, --exclude-pattern <pats> Additional file patterns to exclude
                               (comma-separated)
      --no-smart-defaults      Disable all smart exclusions
      --include-dotfiles       Include dotfiles/dotdirs
  -h, --help                   Show this help message

${BOLD}Smart Exclusions (enabled by default):${NC}
  ${DIM}Directories:${NC}  .git, .svn, node_modules, dist, build, .next,
                __pycache__, .venv, target/, .idea, .vscode, ...
  ${DIM}Patterns:${NC}     *.min.js, *.lock, *.map, images, fonts,
                binaries, .env*, .gitignore, ...
  ${DIM}Dotdirs:${NC}      All hidden directories (.*)

  Use --no-smart-defaults to include everything.

${BOLD}Examples:${NC}
  ./concat.sh ~/projects/myapp
  ./concat.sh ~/projects/myapp -o ~/review.txt
  ./concat.sh ~/src -e lua,ts -x "*.test.lua"
  ./concat.sh ~/src --no-smart-defaults
  ./concat.sh ~/src --include-dotfiles

EOF
  exit 0
}

# ── Entry point ─────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  interactive_mode
else
  cli_mode "$@"
fi
