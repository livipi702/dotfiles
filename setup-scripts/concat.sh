#!/usr/bin/env bash
#
# concat.sh v3.0 (Lean) — High-Performance Directory Merger
# Relies on: ripgrep (rg), fzf, and awk.
# Note: Manages exclusions via local .rgignore or global ~/.ignore

set -euo pipefail

VERSION="3.0.0-lean"

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
NC='\033[0m'

# ── UI Helpers ──────────────────────────────────────────
die() {
  echo -e "\n${RED}  ✖ Error:${NC} $*\n" >&2
  exit 1
}
info() { echo -e "  ${CYAN}▸${NC} $*"; }
ok() { echo -e "  ${GREEN}✔${NC} $*"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }

print_banner() {
  local width=54
  echo ""
  echo -e "${BOLD}${CYAN}╭$(printf '─%.0s' $(seq 1 $width))╮${NC}"
  echo -e "${BOLD}${CYAN}│${NC}                                                      ${BOLD}${CYAN}│${NC}"
  echo -e "${BOLD}${CYAN}│${NC}   ${WHITE}concat.sh${NC} ${DIM}v${VERSION}${NC}    ${ITALIC}Directory Merger${NC}       ${BOLD}${CYAN}│${NC}"
  echo -e "${BOLD}${CYAN}│${NC}   ${DIM}Lean engine powered by rg, fzf & awk${NC}               ${BOLD}${CYAN}│${NC}"
  echo -e "${BOLD}${CYAN}│${NC}                                                      ${BOLD}${CYAN}│${NC}"
  echo -e "${BOLD}${CYAN}╰$(printf '─%.0s' $(seq 1 $width))╯${NC}"
  echo ""
}

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

# ── Dependency Check ────────────────────────────────────
check_deps() {
  local missing=()
  command -v rg >/dev/null 2>&1 || missing+=("ripgrep (rg)")
  command -v fzf >/dev/null 2>&1 || missing+=("fzf")
  command -v awk >/dev/null 2>&1 || missing+=("awk")

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required dependencies: ${missing[*]}\nPlease install them."
  fi
}

# ── Core Concat Engine (awk) ────────────────────────────
do_concat() {
  local target_dir="$1"
  local list_file="$2"
  local out_file="$3"

  >"$out_file"

  awk -v dir="$target_dir" -v date="$(date '+%Y-%m-%d %H:%M:%S')" '
  BEGIN {
    total_files = 0; total_lines = 0; total_bytes = 0;
    
    print "================================================================================"
    print "  CONCATENATED DIRECTORY OUTPUT"
    print "  Source : " dir
    print "  Date   : " date
    print "================================================================================\n"
  }
  {
    filepath = $0
    rel_path = filepath
    sub("^" dir "/", "", rel_path)

    printf "══════════════════════════════════════════════════════════════════════════════\n"
    printf "  FILE: %s\n", rel_path
    printf "══════════════════════════════════════════════════════════════════════════════\n\n"
    
    file_lines = 0
    while ((getline line < filepath) > 0) {
      print line
      file_lines++
      total_bytes += length(line) + 1
    }
    close(filepath)
    
    print "\n"
    total_lines += file_lines
    total_files++
  }
  END {
    if (total_bytes >= 1048576) size_str = sprintf("%.1f MB", total_bytes/1048576);
    else if (total_bytes >= 1024) size_str = sprintf("%.1f KB", total_bytes/1024);
    else size_str = total_bytes " B";

    print "══════════════════════════════════════════════════════════════════════════════"
    print "  SUMMARY"
    print "  Source directory : " dir
    print "  Total files      : " total_files
    print "  Total lines      : " total_lines
    print "  Total size       : " size_str
    print "  Generated at     : " date
    print "══════════════════════════════════════════════════════════════════════════════"
    
    printf "%d|%d|%s\n", total_files, total_lines, size_str > "/dev/stderr"
  }' "$list_file" >>"$out_file" 2>/tmp/concat_stats.txt

  IFS='|' read -r t_files t_lines t_size </tmp/concat_stats.txt
  rm -f /tmp/concat_stats.txt

  echo ""
  ok "Done in a flash!"
  echo ""
  echo -e "  ${BOLD}Files:${NC}      $t_files"
  echo -e "  ${BOLD}Lines:${NC}      $t_lines"
  echo -e "  ${BOLD}Size:${NC}       $t_size"
  echo -e "  ${BOLD}Output:${NC}     $out_file"
  echo ""
}

# ── Interactive Mode ────────────────────────────────────
interactive_mode() {
  print_banner
  check_deps

  echo -e "  ${BOLD}${WHITE}▸ Select a directory to scan${NC}"
  echo -e "  ${DIM}────────────────────────────────────────${NC}\n"

  local target_dir
  target_dir=$(find "$PWD" -maxdepth 1 -type d -not -path '*/\.*' 2>/dev/null | fzf --prompt="Pick a directory > " --height=40% --layout=reverse --border=rounded)

  if [[ -z "$target_dir" ]]; then die "No directory selected."; fi

  ok "Selected ${BOLD}$target_dir${NC}\n"

  echo -e "  ${BOLD}${WHITE}▸ Select files to merge${NC}"
  echo -e "  ${DIM}────────────────────────────────────────${NC}"
  echo -e "  ${DIM}Tip: TAB to multi-select, CTRL-A for all, ENTER to confirm.${NC}\n"

  local list_file="/tmp/concat_selected_files.txt"
  >"$list_file"

  # Core ripgrep command: Includes hidden files, hard-blocks .git, trusts .rgignore for the rest
  rg --files --hidden -g '!.git/' "$target_dir" |
    fzf -m \
      --prompt="Select files > " \
      --bind "ctrl-a:select-all" \
      --height=60% \
      --layout=reverse \
      --border=rounded \
      --preview "head -n 50 {}" \
      --preview-window=right:60% >"$list_file"

  local file_count
  file_count=$(wc -l <"$list_file" | tr -d ' ')

  if [[ "$file_count" -eq 0 ]]; then
    rm -f "$list_file"
    die "No files selected."
  fi

  ok "Selected ${BOLD}$file_count${NC} files.\n"

  local dir_name
  dir_name=$(basename "$target_dir")
  local default_out="$PWD/${dir_name}-concatenated.txt"

  local custom_out
  custom_out=$(ask "Output file" "$default_out")
  local out_file="${custom_out:-$default_out}"
  out_file="${out_file/#\~/$HOME}"

  info "Concatenating stream..."
  do_concat "$target_dir" "$list_file" "$out_file"
  rm -f "$list_file"
}

# ── CLI Mode ────────────────────────────────────────────
cli_mode() {
  check_deps

  local target_dir="${1:-.}"
  target_dir="${target_dir/#\~/$HOME}"
  target_dir=$(cd "$target_dir" && pwd)

  if [[ ! -d "$target_dir" ]]; then die "Directory not found: $target_dir"; fi
  shift

  local out_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -o | --output)
      out_file="$2"
      out_file="${out_file/#\~/$HOME}"
      shift 2
      ;;
    *)
      die "Unknown option: $1"
      ;;
    esac
  done

  if [[ -z "$out_file" ]]; then
    local dir_name
    dir_name=$(basename "$target_dir")
    out_file="$PWD/${dir_name}-concatenated.txt"
  fi

  local list_file="/tmp/concat_cli_files.txt"

  # Instantly grab all files respecting .rgignore
  rg --files --hidden -g '!.git/' "$target_dir" >"$list_file" || true

  if [[ ! -s "$list_file" ]]; then
    rm -f "$list_file"
    die "No text files found in $target_dir"
  fi

  do_concat "$target_dir" "$list_file" "$out_file"
  rm -f "$list_file"
}

# ── Entry point ─────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  interactive_mode
else
  cli_mode "$@"
fi
