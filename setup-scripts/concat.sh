#!/usr/bin/env bash
#
# concat.sh — Recursively concatenates all files in a directory
#             into a single reviewable text file with clear headers.
#
# Usage:
#   ./concat.sh                          # interactive mode (pick dir → done)
#   ./concat.sh /path/to/dir             # concat entire directory
#   ./concat.sh /path/to/dir -o out.txt  # custom output file
#   ./concat.sh -h|--help                # show help
#

set -euo pipefail

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ── Defaults ────────────────────────────────────────────
OUTPUT_FILE=""
TARGET_DIR=""
EXCLUDE_DIRS=()
EXCLUDE_PATTERNS=()
INCLUDE_EXTENSIONS=()
EXPLICIT_FILES=()  # specific files to concat (when not all)

# ── Helpers ─────────────────────────────────────────────
die()  { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

print_banner() {
  echo -e "${BOLD}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║          concat.sh — Directory Merger         ║"
  echo "  ║   Flatten any directory into a single file   ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${NC}"
}

# ── Prompt helpers ──────────────────────────────────────
ask() {
  local prompt="$1"
  local default="${2:-}"
  local response
  if [[ -n "$default" ]]; then
    echo -ne "${CYAN}$prompt${NC} [${DIM}$default${NC}]: " >&2
  else
    echo -ne "${CYAN}$prompt${NC}: " >&2
  fi
  read -r response
  echo "$response"
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local yn
  while true; do
    yn=$(ask "$prompt (y/n)" "$default")
    case "$yn" in
      [Yy]*|"" ) return 0 ;;
      [Nn]*   ) return 1 ;;
      *       ) echo -e "${RED}Please answer y or n.${NC}" >&2 ;;
    esac
  done
}

# ── File listing ────────────────────────────────────────
list_files() {
  local dir="$1"
  local depth="${2:-999}"

  local -a find_args=(-type f -maxdepth "$depth")

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

  for exdir in "${EXCLUDE_DIRS[@]}"; do
    find_args+=(-not -path "*/$exdir/*")
  done

  for pat in "${EXCLUDE_PATTERNS[@]}"; do
    find_args+=(! -name "$pat")
  done

  find "$dir" "${find_args[@]}" 2>/dev/null | sort
}

# Check if file is human-readable (not binary)
is_text() {
  file "$1" 2>/dev/null | grep -qE "text|empty|ASCII"
}

# ── Core concat logic (all files) ──────────────────────
do_concat() {
  local source_dir="$1"
  local out_file="$2"

  info "Concatenating ${BOLD}$source_dir${NC} → ${BOLD}$out_file${NC}"
  echo ""

  > "$out_file"

  local total_files=0
  local total_lines=0
  local skipped=0

  # Write header
  {
    echo "================================================================================"
    echo "  CONCATENATED DIRECTORY OUTPUT"
    echo "  Source : $source_dir"
    echo "  Date   : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  Files  : (counted below)"
    echo "================================================================================"
    echo ""
  } >> "$out_file"

  local all_files
  all_files=$(list_files "$source_dir" 999)

  if [[ -z "$all_files" ]]; then
    warn "No files found matching your criteria!"
    rm -f "$out_file"
    return 1
  fi

  while IFS= read -r filepath; do
    if ! is_text "$filepath"; then
      skipped=$((skipped + 1))
      continue
    fi

    local rel_path="${filepath#$source_dir/}"
    local lines
    lines=$(wc -l < "$filepath" 2>/dev/null || echo "0")
    total_lines=$((total_lines + lines))
    total_files=$((total_files + 1))

    {
      echo "══════════════════════════════════════════════════════════════════════════════"
      echo "  FILE: $rel_path"
      echo "  LINES: $lines"
      echo "══════════════════════════════════════════════════════════════════════════════"
      echo ""
    } >> "$out_file"

    cat "$filepath" >> "$out_file"
    [[ $(tail -c1 "$out_file" | wc -l) -eq 0 ]] && echo "" >> "$out_file"
    echo "" >> "$out_file"

  done <<< "$all_files"

  # Write footer
  {
    echo "══════════════════════════════════════════════════════════════════════════════"
    echo "  SUMMARY"
    echo "  Source directory : $source_dir"
    echo "  Total files      : $total_files"
    echo "  Total lines      : $total_lines"
    echo "  Skipped (binary) : $skipped"
    echo "  Output file      : $out_file"
    echo "  Generated at     : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "══════════════════════════════════════════════════════════════════════════════"
  } >> "$out_file"

  # Update header with actual count
  local out_size
  out_size=$(wc -l < "$out_file")
  sed -i.bak "s/  Files  : (counted below)/  Files  : $total_files (output: $out_size lines)/" "$out_file" && rm -f "$out_file.bak"

  echo ""
  ok "Done!"
  echo -e "  ${BOLD}Files:${NC}    $total_files"
  echo -e "  ${BOLD}Lines:${NC}    $total_lines"
  echo -e "  ${BOLD}Output:${NC}   $out_file"
  echo ""
}

# ── Core concat logic (specific files only) ────────────
do_concat_specific() {
  local source_dir="$1"
  local out_file="$2"
  shift 2
  local -a target_files=("$@")

  info "Concatenating ${BOLD}${#target_files[@]} file(s)${NC} → ${BOLD}$out_file${NC}"
  echo ""

  > "$out_file"

  local total_files=0
  local total_lines=0

  {
    echo "================================================================================"
    echo "  CONCATENATED DIRECTORY OUTPUT (SELECTED FILES)"
    echo "  Source : $source_dir"
    echo "  Date   : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================================================================"
    echo ""
  } >> "$out_file"

  for filepath in "${target_files[@]}"; do
    local rel_path="${filepath#$source_dir/}"
    local lines
    lines=$(wc -l < "$filepath" 2>/dev/null || echo "0")
    total_lines=$((total_lines + lines))
    total_files=$((total_files + 1))

    {
      echo "══════════════════════════════════════════════════════════════════════════════"
      echo "  FILE: $rel_path"
      echo "  LINES: $lines"
      echo "══════════════════════════════════════════════════════════════════════════════"
      echo ""
    } >> "$out_file"

    cat "$filepath" >> "$out_file"
    [[ $(tail -c1 "$out_file" | wc -l) -eq 0 ]] && echo "" >> "$out_file"
    echo "" >> "$out_file"

  done

  {
    echo "══════════════════════════════════════════════════════════════════════════════"
    echo "  SUMMARY"
    echo "  Source directory : $source_dir"
    echo "  Total files      : $total_files"
    echo "  Total lines      : $total_lines"
    echo "  Output file      : $out_file"
    echo "  Generated at     : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "══════════════════════════════════════════════════════════════════════════════"
  } >> "$out_file"

  echo ""
  ok "Done!"
  echo -e "  ${BOLD}Files:${NC}    $total_files"
  echo -e "  ${BOLD}Lines:${NC}    $total_lines"
  echo -e "  ${BOLD}Output:${NC}   $out_file"
  echo ""
}

# ── Interactive mode ────────────────────────────────────
interactive_mode() {
  print_banner

  # ── Step 1: Pick a directory ──
  echo -e "${BOLD}Pick a directory:${NC}"
  echo ""

  local -a available_dirs=()
  local -a dir_labels=()
  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    local bn
    bn=$(basename "$d")
    local item_count
    item_count=$(find "$d" -maxdepth 1 -type f 2>/dev/null | wc -l)
    local sub_count
    sub_count=$(find "$d" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
    local hint=""
    if (( item_count > 0 )); then
      hint="${item_count}f"
      (( sub_count > 0 )) && hint="${hint},${sub_count}d"
    elif (( sub_count > 0 )); then
      hint="${sub_count}d"
    else
      hint="empty"
    fi
    dir_labels+=("$bn  ${DIM}($hint)${NC}")
    available_dirs+=("$d")
  done < <(find "$PWD" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)

  if [[ ${#available_dirs[@]} -eq 0 ]]; then
    local dir_input
    dir_input=$(ask "No subdirs here. Enter a path" "$PWD")
    dir_input="${dir_input/#\~/$HOME}"
    if [[ ! -d "$dir_input" ]]; then
      die "Directory not found: $dir_input"
    fi
    TARGET_DIR=$(realpath "$dir_input")
  else
    for i in "${!dir_labels[@]}"; do
      echo -e "    ${GREEN}[$((i+1))]${NC} ${dir_labels[$i]}"
    done
    echo ""
    local dir_choice
    dir_choice=$(ask "Pick a number or type a custom path" "1")
    if [[ "$dir_choice" =~ ^[0-9]+$ ]] && (( dir_choice >= 1 && dir_choice <= ${#available_dirs[@]} )); then
      TARGET_DIR=$(realpath "${available_dirs[$((dir_choice-1))]}")
    else
      dir_choice="${dir_choice/#\~/$HOME}"
      if [[ ! -d "$dir_choice" ]]; then
        die "Directory not found: $dir_choice"
      fi
      TARGET_DIR=$(realpath "$dir_choice")
    fi
  fi

  ok "$TARGET_DIR"

  # ── Step 2: All files or pick specific? ──
  echo ""

  # Show what's inside the selected dir
  local -a all_file_paths=()
  local -a all_file_labels=()
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if is_text "$f"; then
      local rel="${f#$TARGET_DIR/}"
      local lc
      lc=$(wc -l < "$f")
      all_file_labels+=("$rel  ${DIM}(${lc} lines)${NC}")
      all_file_paths+=("$f")
    fi
  done < <(find "$TARGET_DIR" -type f 2>/dev/null | sort)

  local text_count=${#all_file_paths[@]}

  if [[ $text_count -eq 0 ]]; then
    die "No text files found in $TARGET_DIR"
  fi

  echo -e "  ${DIM}Found $text_count file(s) inside:${NC}"
  for i in "${!all_file_labels[@]}"; do
    echo -e "    ${DIM}[$((i+1))]${NC} ${all_file_labels[$i]}"
  done
  echo ""

  # Default output path
  local dir_name
  dir_name=$(basename "$TARGET_DIR")
  local default_out="$HOME/${dir_name}-concatenated.txt"
  OUTPUT_FILE="$default_out"

  if ask_yes_no "Concat all $text_count files to $OUTPUT_FILE?"; then
    # Just do it — no more questions
    echo ""
    do_concat "$TARGET_DIR" "$OUTPUT_FILE" || exit 1
  else
    # File picker mode
    echo -e "\n  ${BOLD}Which files do you want?${NC}"
    echo -e "  ${DIM}Enter numbers comma-separated (e.g. 1,3,5-8) or 'all'${NC}"
    echo ""
    local file_input
    file_input=$(ask "Files to include")

    if [[ "$file_input" == "all" || "$file_input" == "a" ]]; then
      echo ""
      do_concat "$TARGET_DIR" "$OUTPUT_FILE" || exit 1
    else
      # Parse input: "1,3,5-8" → 1 3 5 6 7 8
      local -a picked_indices=()
      IFS=', ' read -ra parts <<< "$file_input"
      for part in "${parts[@]}"; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
          local start="${BASH_REMATCH[1]}"
          local end="${BASH_REMATCH[2]}"
          for (( j=start; j<=end && j<=text_count; j++ )); do
            picked_indices+=($j)
          done
        elif [[ "$part" =~ ^[0-9]+$ ]] && (( part >= 1 && part <= text_count )); then
          picked_indices+=("$part")
        else
          warn "Ignoring invalid: $part"
        fi
      done

      if [[ ${#picked_indices[@]} -eq 0 ]]; then
        die "No valid files selected. Exiting."
      fi

      # Deduplicate and sort
      local -a sorted_indices
      mapfile -t sorted_indices < <(printf '%s\n' "${picked_indices[@]}" | sort -nu)

      # Build file list
      local -a picked_files=()
      local pick_lines=0
      for idx in "${sorted_indices[@]}"; do
        picked_files+=("${all_file_paths[$((idx-1))]}")
        local lc
        lc=$(wc -l < "${all_file_paths[$((idx-1))]}")
        pick_lines=$((pick_lines + lc))
      done

      echo ""
      info "Selected ${#picked_files[@]} file(s), ~${pick_lines} lines"
      echo ""

      do_concat_specific "$TARGET_DIR" "$OUTPUT_FILE" "${picked_files[@]}"
    fi
  fi
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
      -o|--output)
        OUTPUT_FILE="$2"
        OUTPUT_FILE="${OUTPUT_FILE/#\~/$HOME}"
        shift 2
        ;;
      -e|--ext)
        IFS=', ' read -ra exts <<< "$2"
        for ext in "${exts[@]}"; do
          ext=$(printf '%s' "$ext" | sed 's/^\.//')
          INCLUDE_EXTENSIONS+=("$ext")
        done
        shift 2
        ;;
      -x|--exclude)
        IFS=', ' read -ra pats <<< "$2"
        for p in "${pats[@]}"; do
          EXCLUDE_PATTERNS+=("$p")
        done
        shift 2
        ;;
      -h|--help)
        show_help
        ;;
      *)
        die "Unknown option: $1 (use -h for help)"
        ;;
    esac
  done

  if [[ -z "$OUTPUT_FILE" ]]; then
    local dir_name
    dir_name=$(basename "$TARGET_DIR")
    OUTPUT_FILE="$HOME/${dir_name}-concatenated.txt"
  fi

  local out_dir
  out_dir=$(dirname "$OUTPUT_FILE")
  mkdir -p "$out_dir"

  do_concat "$TARGET_DIR" "$OUTPUT_FILE" || exit 1
}

# ── Help ──────────────────────────────────────────────
show_help() {
  cat <<'EOF'
concat.sh — Flatten any directory into a single reviewable file

Usage:
  ./concat.sh                          Interactive mode (pick dir → done)
  ./concat.sh <dir>                    Concatenate entire directory
  ./concat.sh <dir> -o <file>          Custom output file
  ./concat.sh -h|--help                Show this help

Options:
  -o, --output <file>    Output file path (default: ~/dirname-concatenated.txt)
  -e, --ext <exts>       Only include files with these extensions (comma-separated)
                         Example: -e lua,py,ts
  -x, --exclude <patts>  Exclude files matching patterns (comma-separated)
                         Example: -x "*.min.js,*.lock"
  -h, --help             Show this help message

Examples:
  ./concat.sh ~/.config/nvim
  ./concat.sh ~/projects/myapp -o ~/review.txt
  ./concat.sh ~/src -e lua,ts -x "*.test.lua"
EOF
  exit 0
}

# ── Entry point ─────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  interactive_mode
else
  cli_mode "$@"
fi
